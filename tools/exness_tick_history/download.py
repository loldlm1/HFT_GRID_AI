"""Bounded downloads with validated byte-range recovery and immutable objects."""

from __future__ import annotations

import http.client
import os
import re
import time
import urllib.error
import urllib.request
from concurrent.futures import ThreadPoolExecutor, as_completed
from datetime import datetime, timezone
from email.utils import parsedate_to_datetime
from threading import Event

from .archive import ArchiveKey, SourceError, _allowed_url, _ArchiveRedirects, verify_zip
from .config import Profile
from .storage import Store, StorageError, atomic_json, file_hash, identifier, load_inventory, object_hash, read_json

CHUNK_BYTES = 1024 * 1024


class DownloadError(SourceError):
    pass


def request_identity(owner: dict) -> str:
    probe = owner["probe"]
    return object_hash({key: probe.get(key) for key in ("url", "etag", "last_modified", "content_length")})


def retry_delay(value: str | None, attempt: int, maximum: float) -> float:
    delay = min(2**attempt, maximum)
    if value:
        try:
            delay = float(value) if re.fullmatch(r"[0-9]+", value) else max(
                0, (parsedate_to_datetime(value) - datetime.now(timezone.utc)).total_seconds())
        except (ValueError, TypeError, OverflowError):
            pass
    if delay > maximum:
        raise DownloadError("RETRY_DEFERRED: Retry-After exceeds configured wait; rerun later")
    return delay


def fetch_object(store: Store, owner: dict, profile: Profile, *, resume: bool,
                 opener=None, sleep=time.sleep, cancelled: Event | None = None) -> dict:
    key = ArchiveKey(**owner["key"])
    probe = owner["probe"]
    if probe["url"] != key.url or owner["state"] != "AVAILABLE_CANDIDATE":
        raise DownloadError("Only verified adapter candidates can be downloaded")
    request_id = request_identity(owner)
    work = store.path("partial", request_id)
    work.mkdir(parents=True, exist_ok=True)
    part = store.path("partial", request_id, key.filename + ".part")
    checkpoint = store.path("partial", request_id, "checkpoint.json")
    expected = probe.get("content_length")
    if expected is not None and (type(expected) is not int or not 0 < expected <= profile.limits.max_archive_bytes):
        raise DownloadError("Archive size exceeds configured limit or is invalid")
    etag = probe.get("etag")
    validator = etag if etag and not etag.startswith("W/") else probe.get("last_modified")
    identity = {"request_id": request_id, "validator": validator, "expected_bytes": expected}
    prior = read_json(checkpoint) if checkpoint.exists() else None
    if part.exists() and (not resume or prior != identity or not validator or expected is None):
        part.unlink()  # Only this request's disposable partial object is restarted.
    atomic_json(checkpoint, identity)
    network_bytes = 0
    resumed_from = part.stat().st_size if part.exists() else 0
    opener = opener or urllib.request.build_opener(_ArchiveRedirects())
    for attempt in range(profile.network.max_retries + 1):
        if cancelled is not None and cancelled.is_set():
            raise DownloadError("CANCELLED: partial object retained")
        offset = part.stat().st_size if part.exists() else 0
        if expected is not None and offset == expected:
            break
        if expected is not None and offset > expected:
            raise DownloadError("Partial object exceeds expected length")
        if offset and (not validator or expected is None):
            part.unlink()
            offset = 0
        store.disk_check((expected or profile.limits.max_archive_bytes) - offset,
                         profile.limits.disk_reserve_bytes)
        headers = {"User-Agent": "ExnessTickHistory/0.1", "Accept-Encoding": "identity"}
        if offset:
            headers.update({"Range": f"bytes={offset}-", "If-Range": validator})
        request = urllib.request.Request(key.url, headers=headers)
        retry_after = None
        try:
            with opener.open(request, timeout=profile.network.timeout_seconds) as response:
                if not _allowed_url(response.geturl()):
                    raise DownloadError("Unexpected archive response URL")
                if response.status not in (200, 206):
                    raise DownloadError("Unexpected download HTTP status")
                if response.headers.get_content_type() not in (
                        "application/zip", "application/octet-stream", "application/x-zip-compressed"):
                    raise DownloadError("INVALID_RESPONSE: not a ZIP content type")
                if response.headers.get("Content-Encoding", "identity") != "identity":
                    raise DownloadError("Unexpected encoded HTTP object")
                for header, observed in (("ETag", etag), ("Last-Modified", probe.get("last_modified"))):
                    if observed and response.headers.get(header) != observed:
                        raise DownloadError("SOURCE_CHANGED: refresh inventory; retained archives remain immutable")
                length_text = response.headers.get("Content-Length")
                if length_text is not None and not re.fullmatch(r"[0-9]+", length_text):
                    raise DownloadError("Invalid response Content-Length")
                length = int(length_text) if length_text is not None else None
                if response.status == 206:
                    match = re.fullmatch(r"bytes (\d+)-(\d+)/(\d+)", response.headers.get("Content-Range", ""))
                    if not match or not offset:
                        raise DownloadError("Invalid or unsolicited partial response")
                    first, last, total = map(int, match.groups())
                    if first != offset or total != expected or last != total - 1 or length != total - offset:
                        raise DownloadError("Content-Range does not match the owned partial object")
                else:
                    offset = 0  # A full response replaces the partial; it is never appended.
                    if expected is not None and length != expected:
                        raise DownloadError("SOURCE_CHANGED: response length differs from inventory")
                if length is not None and offset + length > profile.limits.max_archive_bytes:
                    raise DownloadError("Response exceeds configured byte limit")
                received = 0
                with part.open("ab" if offset else "wb") as stream:
                    while chunk := response.read(CHUNK_BYTES):
                        if cancelled is not None and cancelled.is_set():
                            raise DownloadError("CANCELLED: partial object retained")
                        received += len(chunk)
                        network_bytes += len(chunk)
                        if offset + received > profile.limits.max_archive_bytes or (
                                expected is not None and offset + received > expected):
                            raise DownloadError("Response exceeds declared or configured length")
                        store.disk_check(len(chunk), profile.limits.disk_reserve_bytes)
                        stream.write(chunk)
                    stream.flush()
                    os.fsync(stream.fileno())
                if (length is not None and received != length) or (
                        expected is not None and part.stat().st_size != expected):
                    raise http.client.IncompleteRead(b"")
            break
        except urllib.error.HTTPError as exc:
            status = exc.code
            retry_after = exc.headers.get("Retry-After")
            exc.close()
            if status not in (429, 500, 502, 503, 504):
                label = "ACCESS_DENIED" if status in (401, 403) else "NOT_FOUND" if status == 404 else "HTTP_ERROR"
                raise DownloadError(f"{label}: HTTP {status}; coverage remains unknown") from None
        except (urllib.error.URLError, TimeoutError, ConnectionError, http.client.HTTPException):
            pass
        if attempt == profile.network.max_retries:
            raise DownloadError("RETRIES_EXHAUSTED: request incomplete; check network/proxy/VPN and resume")
        delay = retry_delay(retry_after, attempt, profile.network.retry_max_seconds)
        if cancelled is not None and sleep is time.sleep:
            cancelled.wait(delay)
        else:
            sleep(delay)

    verified = verify_zip(part, key, profile.limits)
    digest = file_hash(part)
    target = store.path("archives", digest, key.filename)
    target.parent.mkdir(parents=True, exist_ok=True)
    if target.exists():
        if file_hash(target) != digest:
            raise StorageError("Immutable archive content changed on disk")
        part.unlink()
    else:
        os.replace(part, target)
    return {"state": "VERIFIED", "sha256": digest, "filename": key.filename, "key": owner["key"],
            "bytes": target.stat().st_size, "request_id": request_id, **verified,
            "network_bytes": network_bytes, "resumed_from_bytes": resumed_from}


def download_inventory(profile: Profile, inventory_id: str, *, resume: bool = True,
                       opener_factory=None, sleep=time.sleep) -> dict:
    with Store(profile.data_root) as store:
        selected = load_inventory(store, inventory_id, profile)
        results, pending = [], []
        for owner in selected["owners"]:
            if owner["state"] != "AVAILABLE_CANDIDATE":
                results.append({"state": owner["state"], "start": owner["start"], "end": owner["end"]})
                continue
            request_id = request_identity(owner)
            existing = store.object(request_id)
            if existing:
                path = store.path("archives", existing["sha256"], existing["filename"])
                if not path.exists() or file_hash(path) != existing["sha256"]:
                    raise StorageError("Previously verified archive missing or changed; preserve ledger for recovery")
                results.append({**existing, "network_bytes": 0, "reused": True})
            else:
                pending.append(owner)
        # Disk reservation includes all concurrent bodies, rather than checking each in isolation.
        store.disk_check(sum(item["probe"].get("content_length") or profile.limits.max_archive_bytes
                             for item in pending), profile.limits.disk_reserve_bytes)
        cancelled = Event()
        with ThreadPoolExecutor(max_workers=profile.network.workers) as pool:
            jobs = {pool.submit(fetch_object, store, owner, profile, resume=resume,
                                opener=opener_factory() if opener_factory else None, sleep=sleep, cancelled=cancelled): owner
                    for owner in pending}
            try:
                for future in as_completed(jobs):
                    owner = jobs[future]
                    try:
                        result = future.result()
                        store.record(result["request_id"], result)
                    except (SourceError, StorageError, OSError) as exc:
                        # Avoid leaking proxy credentials or local account paths through arbitrary exceptions.
                        result = {"state": "DOWNLOAD_FAILED", "key": owner["key"],
                                  "diagnostic": str(exc) if isinstance(exc, (SourceError, StorageError)) else "Local I/O failed"}
                    results.append(result)
            except BaseException:
                cancelled.set()
                for future in jobs:
                    future.cancel()
                raise
        report = {"inventory_id": inventory_id, "status": "DOWNLOAD_COMPLETE" if all(
                  item["state"] == "VERIFIED" for item in results) else "DOWNLOAD_INCOMPLETE",
                  "objects": results, "network_bytes": sum(item.get("network_bytes", 0) for item in results),
                  "coverage_verified": False}
        atomic_json(store.path("runs", identifier(inventory_id), "download-status.json"), report)
        return report
