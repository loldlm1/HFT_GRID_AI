import io
import tempfile
import unittest
import urllib.error
import zipfile
from dataclasses import replace
from datetime import date
from email.message import Message
from pathlib import Path
from unittest.mock import Mock, patch

from tools.exness_tick_history.archive import ArchiveKey, Probe, inventory
from tools.exness_tick_history.cli import DEFAULT_PROFILE
from tools.exness_tick_history.config import load_profile
from tools.exness_tick_history.download import DownloadError, download_inventory, fetch_object, request_identity, retry_delay
from tools.exness_tick_history.storage import Store, StorageError, atomic_json, file_hash


def zip_bytes():
    data = io.BytesIO()
    with zipfile.ZipFile(data, "w", zipfile.ZIP_DEFLATED) as archive:
        archive.writestr("Exness_XAUUSD_2026_09_01.csv", "Exness,Symbol,Timestamp,Bid,Ask\nexness,XAUUSD,2026-09-01 00:00:00.001Z,1,2\n")
    return data.getvalue()


class Response(io.BytesIO):
    def __init__(self, body, key, *, status=200, length=None, content_range=None, etag='"one"'):
        super().__init__(body)
        self.status = status
        self.url = key.url
        self.headers = Message()
        self.headers["Content-Type"] = "application/zip"
        self.headers["Content-Length"] = str(len(body) if length is None else length)
        self.headers["ETag"] = etag
        if content_range:
            self.headers["Content-Range"] = content_range

    def geturl(self):
        return self.url


class DownloadTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.profile = replace(load_profile(DEFAULT_PROFILE), data_root=Path(self.temp.name))
        self.key = ArchiveKey("XAUUSD", 2026, 9, 1)
        self.body = zip_bytes()
        self.inv = inventory(self.profile, start="2026-09-01", end="2026-09-02", today=date(2026, 9, 5),
                             probe=lambda key, network: Probe(key.url, "AVAILABLE_CANDIDATE", 200, len(self.body), '"one"'))
        self.owner = self.inv["owners"][0]

    def partial(self, store, size):
        request_id = request_identity(self.owner)
        path = store.path("partial", request_id, self.key.filename + ".part")
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(self.body[:size])
        atomic_json(store.path("partial", request_id, "checkpoint.json"),
                    {"request_id": request_id, "validator": '"one"', "expected_bytes": len(self.body)})

    def test_resume_and_ignored_range(self):
        for status in (200, 206):
            with self.subTest(status=status), Store(self.profile.data_root) as store:
                self.partial(store, 20)
                response = Response(self.body[20:] if status == 206 else self.body, self.key, status=status,
                                    content_range=f"bytes 20-{len(self.body)-1}/{len(self.body)}" if status == 206 else None)
                opener = Mock()
                opener.open.return_value = response
                result = fetch_object(store, self.owner, self.profile, resume=True, opener=opener)
                self.assertEqual(result["bytes"], len(self.body))
                self.assertEqual(result["resumed_from_bytes"], 20)
                self.assertEqual(opener.open.call_args.args[0].headers["Range"], "bytes=20-")
                self.assertEqual(file_hash(store.path("archives", result["sha256"], result["filename"])), result["sha256"])

    def test_invalid_range_stale_source_and_html(self):
        for defect in ("range", "etag", "html"):
            with self.subTest(defect=defect), Store(self.profile.data_root) as store:
                self.partial(store, 20)
                response = Response(self.body[20:], self.key, status=206,
                                    content_range=f"bytes {21 if defect == 'range' else 20}-{len(self.body)-1}/{len(self.body)}",
                                    etag='"changed"' if defect == "etag" else '"one"')
                if defect == "html":
                    response.headers.replace_header("Content-Type", "text/html")
                with self.assertRaises(DownloadError):
                    fetch_object(store, self.owner, self.profile, resume=True, opener=Mock(open=Mock(return_value=response)))

    def test_truncated_transfer_retries_from_partial(self):
        with Store(self.profile.data_root) as store:
            responses = [Response(self.body[:20], self.key, length=len(self.body)),
                         Response(self.body[20:], self.key, status=206,
                                  content_range=f"bytes 20-{len(self.body)-1}/{len(self.body)}")]
            result = fetch_object(store, self.owner, self.profile, resume=True,
                                  opener=Mock(open=Mock(side_effect=responses)), sleep=lambda seconds: None)
            self.assertEqual(result["network_bytes"], len(self.body))

    def test_retry_after_and_denial(self):
        headers = Message()
        headers["Retry-After"] = "2"
        for status in (403, 404, 429, 503):
            with self.subTest(status=status), Store(self.profile.data_root) as store:
                opener = Mock()
                opener.open.side_effect = [urllib.error.HTTPError(self.key.url, status, "", headers, io.BytesIO()),
                                           Response(self.body, self.key)]
                sleeper = Mock()
                if status in (403, 404):
                    with self.assertRaises(DownloadError):
                        fetch_object(store, self.owner, self.profile, resume=False, opener=opener, sleep=sleeper)
                    sleeper.assert_not_called()
                else:
                    fetch_object(store, self.owner, self.profile, resume=False, opener=opener, sleep=sleeper)
                    sleeper.assert_called_once_with(2)
        with self.assertRaises(DownloadError):
            retry_delay("3600", 0, 60)

    def test_low_disk_and_lock_conflict(self):
        with Store(self.profile.data_root) as store:
            with self.assertRaises(StorageError):
                with Store(self.profile.data_root):
                    pass
            with patch("shutil.disk_usage", return_value=Mock(free=1)), self.assertRaises(StorageError):
                fetch_object(store, self.owner, self.profile, resume=True)
            (store.root / "escape").symlink_to("/etc", target_is_directory=True)
            with self.assertRaises(StorageError):
                store.path("escape", "passwd")
            with self.assertRaises(StorageError):
                store.path("../outside")

    def test_interruption_before_publish_and_reuse(self):
        with Store(self.profile.data_root) as store:
            atomic_json(store.path("runs", self.inv["inventory_id"], "inventory.json"), self.inv, immutable=True)
            self.partial(store, len(self.body))
        # Completed partial objects survive restart without another HTTP body.
        factory = Mock(side_effect=AssertionError("unexpected network"))
        # Factory is created before reading a completed partial, so use a refusing opener.
        opener = Mock(open=Mock(side_effect=AssertionError("unexpected HTTP request")))
        report = download_inventory(self.profile, self.inv["inventory_id"], opener_factory=lambda: opener)
        self.assertEqual(report["status"], "DOWNLOAD_COMPLETE")
        self.assertEqual(report["network_bytes"], 0)
        repeated = download_inventory(self.profile, self.inv["inventory_id"], opener_factory=factory)
        factory.assert_not_called()
        self.assertEqual(repeated["network_bytes"], 0)

    def test_corrupt_zip_never_published(self):
        with Store(self.profile.data_root) as store:
            body = b"x" * len(self.body)
            with self.assertRaises(ValueError):
                fetch_object(store, self.owner, self.profile, resume=False,
                             opener=Mock(open=Mock(return_value=Response(body, self.key))))
            self.assertFalse(store.path("archives").exists())
