"""Resumable one-file source-UTC preparation, separate from native acceptance."""
from __future__ import annotations

import hashlib
import json
import os
import shutil
import subprocess
import time
import zipfile
from pathlib import Path

from .archive import ArchiveKey, SourceError, zip_member
from .config import PROJECT_ROOT, Profile
from .download import fetch_object, request_identity
from .mt5_export import TICK_HEADER
from .storage import Store, StorageError, atomic_json, file_hash, identifier, load_inventory, object_hash, read_json

FORMAT_VERSION = 1
NATIVE_SOURCE = Path(__file__).with_name("native_stream.cpp")
POLICIES = ("strict", "eurusd-5dp-artifacts")
BLOCK_BYTES = 8 * 1024 * 1024


def ensure_helper(store: Store) -> tuple[Path, dict]:
    source_hash = file_hash(NATIVE_SOURCE)
    root = store.path("native_tools", source_hash)
    root.mkdir(parents=True, exist_ok=True)
    binary, receipt = root / "tick-stream", root / "build.json"
    if receipt.exists():
        build = read_json(receipt)
        if build["source_sha256"] != source_hash or file_hash(binary) != build["binary_sha256"]:
            raise StorageError("Native helper changed; preserve the cache and use a fresh data root")
        return binary, build
    compiler = shutil.which("g++") or shutil.which("c++")
    if compiler is None:
        raise SourceError("Single-file preparation needs a C++17 compiler (g++ or c++); see the service README")
    partial = root / "tick-stream.partial"
    result = subprocess.run([compiler, "-std=c++17", "-O3", "-Wall", "-Wextra", "-Werror",
                             str(NATIVE_SOURCE), "-o", str(partial)],
                            capture_output=True, text=True, check=False)
    if result.returncode:
        (root / "compile.log").write_text(result.stdout[:20000] + result.stderr[:20000], encoding="utf-8")
        raise SourceError("Native helper compilation failed; see native_tools/<source-hash>/compile.log")
    os.replace(partial, binary)
    build = {"source_sha256": source_hash, "binary_sha256": file_hash(binary), "compiler": Path(compiler).name}
    atomic_json(receipt, build, immutable=True)
    return binary, build


def run_helper(binary: Path, arguments: list[str], *, allow_regressions: bool = False) -> dict:
    result = subprocess.run([str(binary), *arguments], capture_output=True, text=True, check=False)
    if result.returncode not in ((0, 4) if allow_regressions else (0,)):
        raise SourceError("Tick validation failed: " + result.stderr.strip()[:1000])
    try:
        report = json.loads(result.stdout)
    except ValueError as exc:
        raise SourceError("Invalid native helper report") from exc
    if report["source_rows"] != report["rows"] + report["outside_selection_rows"] or report["invalid_rows"]:
        raise SourceError("Source row conservation failed")
    return report


def stable_sort(path: Path, profile: Profile, work: Path) -> str:
    """Sort only a validated stream; retain original ordering inside timestamp ties."""
    sorted_path = work / "sorted.tsv"
    spill = work / "sort-spill"
    spill.mkdir(exist_ok=True)
    sorter = shutil.which("sort")
    version = subprocess.run([sorter, "--version"], capture_output=True, check=False) if sorter else None
    if version is not None and version.returncode == 0 and b"GNU coreutils" in version.stdout:
        if path.stat().st_size * 2 > profile.limits.temp_limit_mb * 1024**2:
            raise StorageError("Stable-sort working estimate exceeds temp_limit_mb; increase the explicit limit")
        # No buffered read-ahead: the child's inherited stdin must start just after the header.
        with path.open("rb", buffering=0) as source, sorted_path.open("wb", buffering=0) as target:
            header = source.readline()
            if header != TICK_HEADER.encode("ascii"):
                raise SourceError("Unexpected header before stable sorting")
            target.write(header)
            result = subprocess.run([sorter, "--stable", "--field-separator=\t", "--key=1,1", "--key=2,2",
                                     f"--buffer-size={profile.limits.memory_limit_mb}M", "--parallel=1",
                                     "--temporary-directory=" + str(spill)],
                                    stdin=source, stdout=target, stderr=subprocess.PIPE,
                                    env={**os.environ, "LC_ALL": "C"}, check=False)
            if result.returncode:
                raise SourceError("Stable sort failed: " + result.stderr.decode("utf-8", "replace")[:1000])
            os.fsync(target.fileno())
        engine = "gnu_stable_sort"
    else:
        from .sanitize import connection
        con = connection(profile, spill)
        try:
            con.execute("SET preserve_insertion_order=true")
            con.execute('''COPY (SELECT d AS "<DATE>", t AS "<TIME>", b AS "<BID>", a AS "<ASK>",
                last AS "<LAST>", vol AS "<VOLUME>" FROM (SELECT row_number() OVER () AS ordinal,*
                FROM read_csv($input_file,columns={'d':'VARCHAR','t':'VARCHAR','b':'VARCHAR','a':'VARCHAR',
                    'last':'VARCHAR','vol':'VARCHAR'},auto_detect=false,header=true,delim='\t',parallel=false))
                ORDER BY d,t,ordinal) TO $output_file (FORMAT CSV, HEADER true, DELIMITER '\t', NEW_LINE '\n')''',
                        {"input_file": str(path), "output_file": str(sorted_path)})
        finally:
            con.close()
        engine = "duckdb_stable_sort"
    os.replace(sorted_path, path)
    return engine


def _partial_digest(path: Path, completed: list[dict]):
    digest = hashlib.sha256()
    expected = len(TICK_HEADER.encode("ascii"))
    with path.open("rb") as stream:
        header = stream.readline()
        if header != TICK_HEADER.encode("ascii"):
            raise StorageError("Preparation partial header changed")
        digest.update(header)
        for part in completed:
            if (type(part["output_start"]) is not int or type(part["output_end"]) is not int
                    or part["output_start"] != expected or part["output_end"] < expected
                    or part["output_end"] > path.stat().st_size):
                raise StorageError("Preparation checkpoint offsets changed")
            remaining = part["output_end"] - expected
            body = hashlib.sha256()
            while remaining:
                chunk = stream.read(min(BLOCK_BYTES, remaining))
                if not chunk:
                    raise StorageError("Completed preparation bytes are missing")
                remaining -= len(chunk)
                body.update(chunk)
                digest.update(chunk)
            if body.hexdigest() != part["body_sha256"]:
                raise StorageError("Completed preparation bytes changed")
            expected = part["output_end"]
    if path.stat().st_size != expected:
        # A crash may leave uncommitted bytes after the verified committed prefix.
        with path.open("r+b") as stream:
            stream.truncate(expected)
            stream.flush()
            os.fsync(stream.fileno())
    return digest


def _append(part: Path, partial: Path, digest) -> dict:
    start = partial.stat().st_size
    body = hashlib.sha256()
    with part.open("rb") as source, partial.open("ab") as target:
        if source.readline() != TICK_HEADER.encode("ascii"):
            raise SourceError("Prepared source header changed")
        while chunk := source.read(BLOCK_BYTES):
            target.write(chunk)
            body.update(chunk)
            digest.update(chunk)
        target.flush()
        os.fsync(target.fileno())
    return {"output_start": start, "output_end": partial.stat().st_size, "body_sha256": body.hexdigest()}


def _output_paths(profile: Profile, output_dir: Path, preparation_id: str) -> tuple[Path, Path, Path]:
    output_dir = output_dir.expanduser().resolve()
    source_root = profile.data_root.resolve()
    project = PROJECT_ROOT.resolve()
    if output_dir.is_relative_to(project) and not output_dir.is_relative_to(project / "artifacts/exness_tick_history"):
        raise StorageError("In-project tick outputs must use the ignored artifacts/exness_tick_history directory")
    if output_dir == source_root or output_dir.is_relative_to(source_root):
        raise StorageError("Choose a persistent output directory outside the service's working data root")
    output_dir.mkdir(parents=True, exist_ok=True)
    name = profile.instrument.archive_symbol
    final = output_dir / (name + "_ticks.tsv")
    manifest = output_dir / (name + "_manifest.json")
    token = object_hash([str(source_root), preparation_id])[:16]
    partial = output_dir / ("." + name + "-" + token + ".partial")
    if any(path.is_symlink() for path in (final, manifest, partial)):
        raise StorageError("Symlink preparation outputs are refused")
    return final, manifest, partial


def _publish(partial: Path, final: Path, manifest_path: Path, result: dict) -> None:
    if final.exists():
        if file_hash(final) != result["sha256"]:
            raise StorageError("Existing final file differs from the verified preparation")
    else:
        # The partial is on the output filesystem. link() atomically refuses an existing destination.
        os.link(partial, final)
    atomic_json(manifest_path, result, immutable=True)
    if os.name != "nt":
        directory = os.open(final.parent, os.O_RDONLY)
        try:
            os.fsync(directory)
        finally:
            os.close(directory)
    partial.unlink(missing_ok=True)


def prepare_mt5_file(profile: Profile, inventory_id: str, preparation_id: str, output_dir: Path,
                     *, price_policy: str = "strict", keep_work_files: bool = False, progress=None) -> dict:
    identifier(preparation_id)
    if preparation_id.endswith("-partial") or price_policy not in POLICIES:
        raise SourceError("Invalid preparation ID or price policy")
    if price_policy != "strict" and profile.instrument.archive_symbol != "EURUSD":
        raise SourceError("The EURUSD artifact policy cannot be applied to another symbol")
    started = time.monotonic()
    with Store(profile.data_root) as store:
        selected = load_inventory(store, inventory_id, profile)
        final, manifest_path, partial = _output_paths(profile, output_dir, preparation_id)
        binary, build = ensure_helper(store)
        contract = {"format_version": FORMAT_VERSION, "inventory_id": inventory_id,
                    "symbol": profile.instrument.archive_symbol, "output": str(final),
                    "price_policy": price_policy, "native_source_sha256": build["source_sha256"],
                    "preparation_source_sha256": file_hash(Path(__file__)), "keep_work_files": keep_work_files}
        contract_hash = object_hash(contract)
        stage = store.path("preparations", preparation_id)
        stage.mkdir(parents=True, exist_ok=True)
        atomic_json(stage / "input.json", contract, immutable=True)
        candidate_path = stage / "prepared-manifest.json"
        if candidate_path.exists():
            result = read_json(candidate_path)
            checksum = object_hash({key: value for key, value in result.items() if key != "manifest_sha256"})
            if result["input_sha256"] != contract_hash or result.get("manifest_sha256") != checksum:
                raise StorageError("Preparation ID belongs to other inputs")
            verified = final if final.exists() else partial
            if file_hash(verified) != result["sha256"]:
                raise StorageError("Prepared output changed before publication/reuse")
            _publish(partial, final, manifest_path, result)
            return result
        if final.exists() or manifest_path.exists():
            raise StorageError("Output already exists; use another output directory or the original preparation ID")
        journal = stage / "progress.json"
        completed = read_json(journal)["completed"] if journal.exists() else []
        if partial.exists() and not journal.exists():
            raise StorageError("Unregistered partial output exists; it was not overwritten")
        if not partial.exists():
            if completed:
                raise StorageError("Committed partial output is missing")
            atomic_json(journal, {"completed": []})
            with partial.open("xb") as stream:
                stream.write(TICK_HEADER.encode("ascii"))
                stream.flush()
                os.fsync(stream.fileno())
        digest = _partial_digest(partial, completed)
        cursor = selected["requested_start"]
        missing = []
        owners = []
        for owner in selected["owners"]:
            if owner["start"] != cursor or owner["end"] <= cursor:
                raise StorageError("Inventory intervals overlap or leave unowned gaps")
            cursor = owner["end"]
            if owner["state"] == "NOT_FOUND":
                missing.append({key: owner[key] for key in ("start", "end", "state")})
            elif owner["state"] == "AVAILABLE_CANDIDATE":
                owners.append(owner)
            else:
                raise SourceError("Unresolved access/network inventory state cannot be treated as missing history")
        if cursor != selected["resolved_end_exclusive"] or len(completed) > len(owners):
            raise StorageError("Inventory/checkpoint interval mismatch")
        with Store(stage / "download-cache") as cache:
            for index, owner in enumerate(owners):
                request_id = request_identity(owner)
                if index < len(completed):
                    if completed[index]["request_id"] != request_id:
                        raise StorageError("Completed source differs from frozen inventory")
                    if not keep_work_files and not completed[index]["shared_source_retained"]:
                        cache.path("archives", completed[index]["archive_sha256"],
                                   ArchiveKey(**owner["key"]).filename).unlink(missing_ok=True)
                    continue
                work = stage / (f"work-{index:06d}" if keep_work_files else "work")
                if work.exists():
                    shutil.rmtree(work)
                work.mkdir()
                shared = store.object(request_id)
                if shared:
                    source = shared
                    archive_path = store.path("archives", source["sha256"], source["filename"])
                    if not archive_path.exists() or file_hash(archive_path) != source["sha256"]:
                        raise StorageError("Shared source archive is missing/changed; it was not replaced")
                else:
                    source = fetch_object(cache, owner, profile, resume=True)
                    archive_path = cache.path("archives", source["sha256"], source["filename"])
                key = ArchiveKey(**owner["key"])
                store.disk_check(source["csv_bytes"] * 4, profile.limits.disk_reserve_bytes)
                if shutil.disk_usage(final.parent).free < source["csv_bytes"] * 2 + profile.limits.disk_reserve_bytes:
                    raise StorageError("Insufficient free space on the persistent output filesystem")
                csv_path, part = work / "source.csv", work / "ticks.tsv"
                with zipfile.ZipFile(archive_path) as archive:
                    member = zip_member(archive, key, profile.limits)
                    with archive.open(member) as raw, csv_path.open("xb") as target:
                        shutil.copyfileobj(raw, target, BLOCK_BYTES)
                if csv_path.stat().st_size != source["csv_bytes"]:
                    raise SourceError("Expanded source size differs from the verified archive")
                bounds = [value.isoformat() for value in key.bounds]
                stats = run_helper(binary, ["convert", str(csv_path), str(part), key.symbol,
                                            *bounds, owner["start"], owner["end"], price_policy], allow_regressions=True)
                stats["source_timestamp_regressions"] = stats["timestamp_regressions"]
                stats["sort_engine"] = "unnecessary"
                if stats["timestamp_regressions"]:
                    stats["sort_engine"] = stable_sort(part, profile, work)
                    audit = run_helper(binary, ["audit", str(part), str(stats["rows"])])
                    stats["timestamp_regressions"] = audit["timestamp_regressions"]
                    stats["adjacent_equal_time_rows"] = audit["adjacent_equal_time_rows"]
                if completed and stats["rows"]:
                    last = next((p["last_utc"] for p in reversed(completed) if p["rows"]), "")
                    if last and last >= stats["first_utc"]:
                        raise SourceError("Prepared source intervals overlap or regress")
                placement = _append(part, partial, digest)
                completed.append({**stats, **placement, "request_id": request_id,
                    "source_url": key.url, "archive_sha256": source["sha256"], "archive_bytes": source["bytes"],
                    "csv_bytes": source["csv_bytes"], "source_member": source["csv_member"],
                    "source_crc_verified": True, "shared_source_retained": bool(shared),
                    "start": owner["start"], "end": owner["end"]})
                atomic_json(journal, {"completed": completed})
                if not keep_work_files:
                    shutil.rmtree(work)
                    if not shared:
                        archive_path.unlink()
                if progress:
                    progress({"symbol": key.symbol, "completed_archives": len(completed),
                              "total_archives": len(owners), "rows": sum(p["rows"] for p in completed)})
        total = sum(p["rows"] for p in completed)
        if not keep_work_files and (stage / "work").exists():
            shutil.rmtree(stage / "work")
        if not total:
            raise SourceError("No selected ticks; no final file published")
        audit = run_helper(binary, ["audit", str(partial), str(total)])
        if file_hash(partial) != digest.hexdigest():
            raise StorageError("Final readback checksum differs from the prepared source bytes")
        nonempty = [part for part in completed if part["rows"]]
        result = {"schema_version": 1, "purpose": "SOURCE_UTC_PREPARATION", "preparation_id": preparation_id,
                  **contract, "input_sha256": contract_hash, "native_helper": build,
                  "file": final.name, "rows": total, "bytes": partial.stat().st_size, "sha256": digest.hexdigest(),
                  "source_first_utc": nonempty[0]["first_utc"], "source_last_utc": nonempty[-1]["last_utc"],
                  "requested_start": selected["requested_start"], "end_exclusive_utc": selected["resolved_end_exclusive"],
                  "source_unavailable_intervals": missing, "sources": completed,
                  "adjusted_rows": sum(p["adjusted_rows"] for p in completed),
                  "adjusted_quotes": sum(p["adjusted_quotes"] for p in completed),
                  "file_audit": {"status": "PASS", **audit}, "coverage": "PUBLISHED_SOURCES_ONLY",
                  "format": {"encoding": "ASCII", "separator": "TAB", "skip_header_rows": 1, "skip_columns": 0,
                             "shift_hours": 0, "columns": TICK_HEADER.strip().split("\t"), "last_volume": "UNSUPPLIED_ZERO"},
                  "native_import": "NOT_PERFORMED", "broker_equivalence": "NOT_VERIFIED",
                  "work_file_policy": "KEEP" if keep_work_files else "REMOVE_OWNED_TEMPORARY_FILES"}
        result["manifest_sha256"] = object_hash(result)
        atomic_json(candidate_path, result, immutable=True)
        _publish(partial, final, manifest_path, result)
        atomic_json(stage / "performance.json", {"elapsed_seconds": round(time.monotonic() - started, 3),
                    "rows": total, "output_bytes": result["bytes"], "source_archives": len(completed),
                    "archives_requiring_sort": sum(p["sort_engine"] != "unnecessary" for p in completed),
                    "shared_archives_reused": sum(p["shared_source_retained"] for p in completed)})
        return result
