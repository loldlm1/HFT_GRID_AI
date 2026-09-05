"""Single-writer ledger and atomic, confined artifact publication."""

from __future__ import annotations

import hashlib
import json
import os
import shutil
import sqlite3
import uuid
from dataclasses import asdict
from pathlib import Path

from .config import ID_PATTERN, Profile


class StorageError(ValueError):
    pass


def identifier(value: str) -> str:
    if not isinstance(value, str) or not ID_PATTERN.fullmatch(value):
        raise StorageError("Unsafe artifact identifier")
    return value


def canonical_json(value: object) -> bytes:
    return (json.dumps(value, sort_keys=True, separators=(",", ":"), allow_nan=False) + "\n").encode("utf-8")


def object_hash(value: object) -> str:
    return hashlib.sha256(canonical_json(value)).hexdigest()


def file_hash(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        while chunk := stream.read(1024 * 1024):
            digest.update(chunk)
    return digest.hexdigest()


def feed_identity(profile: Profile) -> dict:
    fields = asdict(profile.instrument)
    # The opaque local alias is still private; reports expose only its digest.
    fields["server_alias_sha256"] = object_hash(fields.pop("server_alias"))
    return {"profile_id": profile.profile_id, **fields}


def read_json(path: Path) -> dict:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
        if not isinstance(value, dict):
            raise ValueError()
        return value
    except (OSError, ValueError) as exc:
        raise StorageError("Cannot read a valid artifact manifest") from exc


def atomic_json(path: Path, value: dict, *, immutable: bool = False) -> None:
    data = canonical_json(value)
    if path.is_symlink():
        raise StorageError("Symlink artifact destination refused")
    if immutable and path.exists():
        if path.read_bytes() != data:
            raise StorageError("Artifact ID already exists with different content; use a new ID")
        return
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name(path.name + "." + uuid.uuid4().hex + ".tmp")
    try:
        with temporary.open("xb") as stream:
            stream.write(data)
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(temporary, path)
    finally:
        temporary.unlink(missing_ok=True)


class Store:
    def __init__(self, root: Path):
        self.root = root.resolve()
        self.connection = None
        self.lock = None

    def path(self, *parts: str) -> Path:
        path = self.root
        for part in parts:
            if not part or Path(part).name != part or part in (".", "..") or "\\" in part:
                raise StorageError("Artifact paths require confined path components")
            path = path / part
            if path.is_symlink():
                raise StorageError("Symlink artifact path refused")
        if not path.resolve().is_relative_to(self.root):
            raise StorageError("Artifact path escapes data root")
        return path

    def __enter__(self):
        self.root.mkdir(parents=True, exist_ok=True)
        self.lock = self.path("writer.lock").open("a+b")
        try:
            if os.name == "nt":
                import msvcrt
                self.lock.seek(0)
                msvcrt.locking(self.lock.fileno(), msvcrt.LK_NBLCK, 1)
            else:
                import fcntl
                fcntl.flock(self.lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except OSError as exc:
            self.lock.close()
            self.lock = None
            raise StorageError("Another process owns this data root; its lock was not removed") from exc
        try:
            self.connection = sqlite3.connect(self.path("ledger.sqlite"))
            version = self.connection.execute("PRAGMA user_version").fetchone()[0]
            if version not in (0, 1):
                raise StorageError("Unsupported ledger version; preserve it for explicit migration")
            self.connection.execute("CREATE TABLE IF NOT EXISTS objects (request_id TEXT PRIMARY KEY, metadata TEXT NOT NULL)")
            self.connection.execute("PRAGMA user_version=1")
            self.connection.commit()
            return self
        except BaseException:
            self.__exit__(None, None, None)
            raise

    def __exit__(self, *args):
        if self.connection is not None:
            self.connection.close()
        if self.lock is not None:
            self.lock.close()

    def object(self, request_id: str) -> dict | None:
        row = self.connection.execute("SELECT metadata FROM objects WHERE request_id=?", [request_id]).fetchone()
        return json.loads(row[0]) if row else None

    def record(self, request_id: str, metadata: dict) -> None:
        with self.connection:
            self.connection.execute("INSERT OR REPLACE INTO objects VALUES (?, ?)",
                                    [request_id, canonical_json(metadata).decode()])

    def disk_check(self, required: int, reserve: int) -> None:
        if shutil.disk_usage(self.root).free < required + reserve:
            raise StorageError("Insufficient disk space for this operation and configured reserve")


def load_inventory(store: Store, inventory_id: str, profile: Profile) -> dict:
    value = read_json(store.path("runs", identifier(inventory_id), "inventory.json"))
    if value.get("schema_version") != 1 or value.get("feed") != feed_identity(profile):
        raise StorageError("Inventory schema or feed differs from the selected profile")
    content = {key: item for key, item in value.items() if key != "inventory_id"}
    if value.get("inventory_id") != "inv-" + object_hash(content)[:24]:
        raise StorageError("Inventory content hash mismatch")
    return value
