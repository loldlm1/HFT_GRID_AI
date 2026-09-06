"""Versioned Exness URL and CSV contracts; bounded read-only inspection."""

from __future__ import annotations

import csv
import hashlib
import io
import re
import urllib.error
import urllib.parse
import urllib.request
import zipfile
from dataclasses import asdict, dataclass
from datetime import date, datetime, timedelta, timezone
from decimal import Decimal, InvalidOperation
from pathlib import Path, PurePosixPath

from .config import ConfigError, Limits, Network, Profile, parse_date, validate_symbol

ARCHIVE_BASE_URL = "https://ticks.ex2archive.com/ticks"
SOURCE_CONTRACT_VERSION = 1
SOURCE_HEADER = ("Exness", "Symbol", "Timestamp", "Bid", "Ask")
STAMP_PATTERN = re.compile(r"\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\.\d{3}Z", re.ASCII)
PRICE_PATTERN = re.compile(r"[0-9]+(?:\.[0-9]+)?", re.ASCII)


class SourceError(ValueError):
    """The observed object does not satisfy the source contract."""


def bounded_lines(stream, maximum: int = 65536):
    while line := stream.readline(maximum + 1):
        if len(line) > maximum:
            raise SourceError("Input line exceeds the bounded source/capture contract")
        yield line


@dataclass(frozen=True)
class ArchiveKey:
    symbol: str
    year: int
    month: int | None = None
    day: int | None = None

    def __post_init__(self) -> None:
        validate_symbol(self.symbol, "archive_symbol")
        if type(self.year) is not int or not 1970 <= self.year <= 9998:
            raise ConfigError("Archive year must be an integer between 1970 and 9998")
        if self.day is not None and self.month is None:
            raise ConfigError("Archive day requires a month")
        for field in (self.month, self.day):
            if field is not None and type(field) is not int:
                raise ConfigError("Archive month/day must be integers")
        try:
            date(self.year, self.month if self.month is not None else 1,
                 self.day if self.day is not None else 1)
        except ValueError as exc:
            raise ConfigError("Invalid archive calendar date") from exc

    @property
    def granularity(self) -> str:
        return "day" if self.day is not None else "month" if self.month is not None else "year"

    @property
    def components(self) -> list[str]:
        result = [f"{self.year:04d}"]
        if self.month is not None:
            result.append(f"{self.month:02d}")
        if self.day is not None:
            result.append(f"{self.day:02d}")
        return result

    @property
    def filename(self) -> str:
        return f"Exness_{self.symbol}_{'_'.join(self.components)}.zip"

    @property
    def url(self) -> str:
        parts = [self.symbol, *self.components, self.filename]
        return ARCHIVE_BASE_URL + "/" + "/".join(urllib.parse.quote(part, safe="") for part in parts)

    @property
    def bounds(self) -> tuple[date, date]:
        start = date(self.year, self.month or 1, self.day or 1)
        if self.day is not None:
            end = start + timedelta(days=1)
        elif self.month is not None:
            end = date(self.year + int(self.month == 12), self.month % 12 + 1, 1)
        else:
            end = date(self.year + 1, 1, 1)
        return start, end


def _allowed_url(url: str) -> bool:
    parsed = urllib.parse.urlsplit(url)
    return (parsed.scheme == "https" and parsed.netloc == "ticks.ex2archive.com"
            and parsed.path.startswith("/ticks/") and not parsed.query and not parsed.fragment
            and ".." not in urllib.parse.unquote(parsed.path).split("/")
            and "\\" not in urllib.parse.unquote(parsed.path))


class _ArchiveRedirects(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        if not _allowed_url(newurl):
            raise SourceError("Archive redirect left the verified HTTPS host/path")
        return super().redirect_request(req, fp, code, msg, headers, newurl)


@dataclass(frozen=True)
class Probe:
    url: str
    state: str
    http_status: int | None
    content_length: int | None = None
    etag: str | None = None
    last_modified: str | None = None
    accepts_ranges: bool = False
    diagnostic: str | None = None

    def summary(self) -> dict:
        return {**asdict(self), "body_downloaded": False, "coverage_verified": False}


def probe_archive(key: ArchiveKey, network: Network) -> Probe:
    request = urllib.request.Request(key.url, method="HEAD", headers={"User-Agent": "ExnessTickHistory/0.1"})
    opener = urllib.request.build_opener(_ArchiveRedirects())
    try:
        with opener.open(request, timeout=network.timeout_seconds) as response:
            if not _allowed_url(response.geturl()):
                raise SourceError("Unexpected archive response URL")
            if response.status != 200:
                return Probe(key.url, "UNEXPECTED_HTTP_STATUS", response.status)
            content_type = response.headers.get_content_type()
            if content_type not in ("application/zip", "application/octet-stream", "application/x-zip-compressed"):
                return Probe(key.url, "INVALID_RESPONSE", response.status, diagnostic="Not a ZIP content type")
            length = response.headers.get("Content-Length")
            if length is not None and (not re.fullmatch(r"[0-9]+", length) or int(length) <= 0):
                return Probe(key.url, "INVALID_RESPONSE", response.status, diagnostic="Invalid Content-Length")
            if any(len(value) > 4096 or any(ord(char) < 32 or ord(char) == 127 for char in value)
                   for value in (response.headers.get("ETag", ""), response.headers.get("Last-Modified", ""))):
                return Probe(key.url, "INVALID_RESPONSE", response.status, diagnostic="Invalid object validator header")
            return Probe(key.url, "AVAILABLE_CANDIDATE", response.status,
                         int(length) if length else None, response.headers.get("ETag"),
                         response.headers.get("Last-Modified"), response.headers.get("Accept-Ranges") == "bytes")
    except urllib.error.HTTPError as exc:
        status = exc.code
        exc.close()
        if status in (401, 403):
            state = "ACCESS_DENIED"
        elif status == 404:
            state = "NOT_FOUND"
        elif status == 405:
            state = "HEAD_UNSUPPORTED"
        elif status == 429:
            state = "RATE_LIMITED"
        elif 500 <= status <= 599:
            state = "RETRYABLE_ERROR"
        else:
            state = "UNEXPECTED_HTTP_STATUS"
        return Probe(key.url, state, status)
    except (urllib.error.URLError, TimeoutError, OSError):
        return Probe(key.url, "NETWORK_ERROR", None, diagnostic="Archive host request failed; check network/proxy/VPN")


def inspect_archive(path: Path, key: ArchiveKey, limits: Limits) -> dict:
    """Read all CSV rows/CRC without producing a sanitized dataset or changing input."""
    try:
        size = path.stat().st_size
        if size > limits.max_archive_bytes:
            raise SourceError("Archive exceeds max_archive_bytes")
        digest = hashlib.sha256()
        with path.open("rb") as stream:
            while chunk := stream.read(1024 * 1024):
                digest.update(chunk)
        with zipfile.ZipFile(path) as archive:
            members = archive.infolist()
            if not members or len(members) > limits.max_members:
                raise SourceError("Invalid or excessive ZIP member count")
            expected_member = key.filename.removesuffix(".zip") + ".csv"
            if len(members) != 1 or members[0].filename != expected_member:
                raise SourceError("Source contract requires one matching CSV member")
            member = members[0]
            name = PurePosixPath(member.filename)
            if name.is_absolute() or ".." in name.parts or "\\" in member.filename:
                raise SourceError("Unsafe ZIP member path")
            if member.flag_bits & 1 or member.compress_type not in (zipfile.ZIP_STORED, zipfile.ZIP_DEFLATED):
                raise SourceError("Encrypted or unsupported ZIP member")
            if member.file_size > limits.max_uncompressed_bytes:
                raise SourceError("CSV exceeds max_uncompressed_bytes")
            if member.file_size > max(member.compress_size, 1) * limits.max_expansion_ratio:
                raise SourceError("ZIP expansion ratio exceeds configured limit")
            start, end = key.bounds
            count = ties = regressions = 0
            first = last = minimum = maximum = previous = None
            price_scale = 0
            with io.TextIOWrapper(archive.open(member), encoding="utf-8-sig", newline="") as stream:
                reader = csv.reader(bounded_lines(stream), strict=True)
                if tuple(next(reader, ())) != SOURCE_HEADER:
                    raise SourceError("Unsupported source CSV header")
                for row in reader:
                    count += 1
                    if len(row) != 5 or row[:2] != ["exness", key.symbol]:
                        raise SourceError(f"Source vendor/symbol/field mismatch at row {count}")
                    if not STAMP_PATTERN.fullmatch(row[2]):
                        raise SourceError(f"Unsupported UTC millisecond timestamp at row {count}")
                    try:
                        stamp = datetime.strptime(row[2], "%Y-%m-%d %H:%M:%S.%fZ")
                    except ValueError as exc:
                        raise SourceError(f"Invalid calendar timestamp at row {count}") from exc
                    if not start <= stamp.date() < end:
                        raise SourceError(f"Timestamp outside archive interval at row {count}")
                    if not all(PRICE_PATTERN.fullmatch(value) for value in row[3:]):
                        raise SourceError(f"Unsupported price grammar at row {count}")
                    bid, ask = (Decimal(value) for value in row[3:])
                    if bid <= 0 or ask < bid:
                        raise SourceError(f"Invalid non-positive/crossed quote at row {count}")
                    price_scale = max(price_scale, -bid.as_tuple().exponent, -ask.as_tuple().exponent)
                    first = stamp if first is None else first
                    last = stamp
                    minimum = stamp if minimum is None else min(minimum, stamp)
                    maximum = stamp if maximum is None else max(maximum, stamp)
                    if previous is not None:
                        ties += int(stamp == previous)
                        regressions += int(stamp < previous)
                    previous = stamp
            if not count:
                raise SourceError("An empty source CSV does not establish market closure or coverage")
        return {
            "status": "SOURCE_CONTRACT_VALID", "source_contract_version": SOURCE_CONTRACT_VERSION,
            "archive_symbol": key.symbol, "archive_url": key.url, "archive_sha256": digest.hexdigest(),
            "compressed_bytes": size, "csv_bytes": member.file_size, "csv_member": member.filename,
            "header": list(SOURCE_HEADER), "row_count": count, "crc_verified": True,
            "first_utc": first.isoformat(timespec="milliseconds") + "Z",
            "last_utc": last.isoformat(timespec="milliseconds") + "Z",
            "minimum_utc": minimum.isoformat(timespec="milliseconds") + "Z",
            "maximum_utc": maximum.isoformat(timespec="milliseconds") + "Z",
            "adjacent_equal_timestamp_rows": ties, "timestamp_regressions": regressions,
            "observed_max_price_scale": price_scale, "coverage_verified": False,
            "broker_feed_equivalence_verified": False, "sanitized_dataset_created": False,
        }
    except (OSError, zipfile.BadZipFile, UnicodeError, csv.Error, InvalidOperation) as exc:
        raise SourceError("Archive read, CRC, CSV encoding, or numeric parsing failed") from exc


def zip_member(archive: zipfile.ZipFile, key: ArchiveKey, limits: Limits) -> zipfile.ZipInfo:
    members = archive.infolist()
    if len(members) != 1 or len(members) > limits.max_members:
        raise SourceError("Source contract requires one matching CSV member")
    member = members[0]
    if member.filename != key.filename.removesuffix(".zip") + ".csv":
        raise SourceError("Unexpected or unsafe ZIP member name")
    if member.flag_bits & 1 or member.compress_type not in (zipfile.ZIP_STORED, zipfile.ZIP_DEFLATED):
        raise SourceError("Encrypted or unsupported ZIP member")
    if (member.file_size > limits.max_uncompressed_bytes
            or member.file_size > max(member.compress_size, 1) * limits.max_expansion_ratio):
        raise SourceError("ZIP expansion exceeds configured limits")
    return member


def verify_zip(path: Path, key: ArchiveKey, limits: Limits) -> dict:
    try:
        if path.stat().st_size > limits.max_archive_bytes:
            raise SourceError("Archive exceeds configured byte limit")
        with zipfile.ZipFile(path) as archive:
            member = zip_member(archive, key, limits)
            read_bytes = 0
            with archive.open(member) as stream:
                while chunk := stream.read(1024 * 1024):
                    read_bytes += len(chunk)
                    if read_bytes > limits.max_uncompressed_bytes:
                        raise SourceError("Expanded CSV exceeds configured byte limit")
            if read_bytes != member.file_size:
                raise SourceError("Expanded CSV length mismatch")
        return {"csv_member": member.filename, "csv_bytes": read_bytes, "crc_verified": True}
    except (OSError, zipfile.BadZipFile, RuntimeError, EOFError) as exc:
        raise SourceError("Invalid archive structure, compression or CRC") from exc


def inventory(profile: Profile, *, start=None, end=None, granularity=None,
              today: date | None = None, probe=probe_archive) -> dict:
    """Assign disjoint intervals; a 404 is availability evidence, never a holiday."""
    from .storage import feed_identity, object_hash

    today = today or datetime.now(timezone.utc).date()
    start = parse_date(start or profile.selection.start, "start")
    requested_end = end or profile.selection.end
    mode = granularity or profile.selection.granularity
    if mode not in ("auto", "year", "month", "day"):
        raise ConfigError("Invalid granularity")
    cutoff = today if requested_end == "latest-published" else parse_date(requested_end, "end")
    if not date(1970, 1, 1) <= start < cutoff <= today:
        raise ConfigError("Inventory requires 1970 <= start < end <= today's UTC boundary")
    if (cutoff - start).days > 366 * 100:
        raise ConfigError("Inventory range exceeds the 100-year probe bound")
    cache = {}

    def candidate(key):
        if key.url not in cache:
            observed = probe(key, profile.network)
            cache[key.url] = {"key": asdict(key), **observed.summary()}
        return cache[key.url]

    publication_candidate = None
    if requested_end == "latest-published":
        for offset in range(1, 32):
            day = today - timedelta(days=offset)
            if day < start:
                break
            observed = candidate(ArchiveKey(profile.instrument.archive_symbol, day.year, day.month, day.day))
            if observed["state"] == "AVAILABLE_CANDIDATE":
                publication_candidate = day
                cutoff = day + timedelta(days=1)
                break
            if observed["state"] != "NOT_FOUND":
                break

    owners = []
    cursor = start
    while cursor < cutoff:
        possible = [ArchiveKey(profile.instrument.archive_symbol, cursor.year),
                    ArchiveKey(profile.instrument.archive_symbol, cursor.year, cursor.month),
                    ArchiveKey(profile.instrument.archive_symbol, cursor.year, cursor.month, cursor.day)]
        chosen = None
        for key in possible:
            left, right = key.bounds
            if mode != "auto" and key.granularity != mode:
                continue
            if mode == "auto" and (left != cursor or right > cutoff):
                continue
            observed = candidate(key)
            chosen = (key, observed)
            if observed["state"] != "NOT_FOUND" or mode != "auto" or key.granularity == "day":
                break
        key, observed = chosen
        left, right = key.bounds
        stop = min(right, cutoff)
        owners.append({"start": cursor.isoformat(), "end": stop.isoformat(), "key": asdict(key),
                       "state": observed["state"], "probe": observed,
                       "extra_container_days": (right - left).days - (stop - cursor).days})
        cursor = stop
    result = {"schema_version": 1, "feed": feed_identity(profile), "source_contract_version": SOURCE_CONTRACT_VERSION,
              "requested_start": start.isoformat(), "requested_end": str(requested_end),
              "resolved_end_exclusive": cutoff.isoformat(), "discovery_utc_date": today.isoformat(),
              "publication_candidate_day": str(publication_candidate) if publication_candidate else None,
              "publication_verified": False, "granularity": mode, "owners": owners,
              "candidates": sorted(cache.values(), key=lambda item: item["url"]),
              "estimated_download_bytes": sum(item["probe"]["content_length"] or 0 for item in owners
                                               if item["state"] == "AVAILABLE_CANDIDATE"),
              "unknown_size_archives": sum(item["state"] == "AVAILABLE_CANDIDATE" and item["probe"]["content_length"] is None
                                           for item in owners), "coverage_verified": False}
    result["inventory_id"] = "inv-" + object_hash(result)[:24]
    return result


def network_check(key: ArchiveKey, network: Network) -> dict:
    class PageRedirects(urllib.request.HTTPRedirectHandler):
        def redirect_request(self, req, fp, code, msg, headers, newurl):
            return None

    page = {"host": "www.exness.com", "state": "NETWORK_ERROR", "http_status": None}
    request = urllib.request.Request("https://www.exness.com/tick-history/", method="HEAD")
    try:
        with urllib.request.build_opener(PageRedirects()).open(request, timeout=network.timeout_seconds) as response:
            page.update(state="REACHABLE" if response.status == 200 else "UNEXPECTED_STATUS", http_status=response.status)
    except urllib.error.HTTPError as exc:
        page.update(state="ACCESS_DENIED" if exc.code in (401, 403) else "HEAD_UNSUPPORTED" if exc.code == 405 else "HTTP_ERROR", http_status=exc.code)
        exc.close()
    except (urllib.error.URLError, OSError, TimeoutError):
        pass
    archive = probe_archive(key, network).summary()
    return {"page": page, "archive": archive, "archive_candidate_reachable": archive["state"] == "AVAILABLE_CANDIDATE",
            "note": "Checks the operator's current network only; no VPN or proxy settings were changed."}
