import io
import tempfile
import unittest
import urllib.error
import zipfile
from dataclasses import replace
from email.message import Message
from pathlib import Path
from unittest.mock import MagicMock, patch

from tools.exness_tick_history.archive import ArchiveKey, SourceError, _allowed_url, inspect_archive, probe_archive
from tools.exness_tick_history.cli import DEFAULT_PROFILE
from tools.exness_tick_history.config import ConfigError, load_profile

HEADER = '"Exness","Symbol","Timestamp","Bid","Ask"\n'
ROW = '"exness","XAUUSD","2026-09-01 00:00:00.064Z","4452.259","4452.441"\n'


class ArchiveTests(unittest.TestCase):
    def setUp(self):
        self.profile = load_profile(DEFAULT_PROFILE)
        self.key = ArchiveKey("XAUUSD", 2026, 9, 1)

    def inspect(self, content, *, member=None, limits=None):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "source.zip"
            with zipfile.ZipFile(path, "w", zipfile.ZIP_DEFLATED) as archive:
                archive.writestr(member or self.key.filename.replace(".zip", ".csv"), content)
            return inspect_archive(path, self.key, limits or self.profile.limits)

    def test_templates_and_leap_bounds(self):
        self.assertEqual(self.key.url, "https://ticks.ex2archive.com/ticks/XAUUSD/2026/09/01/Exness_XAUUSD_2026_09_01.zip")
        self.assertEqual(str(ArchiveKey("XAUUSD", 2024, 2).bounds[1]), "2024-03-01")
        self.assertEqual(str(ArchiveKey("XAUUSD", 2024, 12).bounds[1]), "2025-01-01")
        self.assertIn("XAUUSD%23", ArchiveKey("XAUUSD#", 2024).url)
        for values in [(2026, None, 1), (2026, 2, 29), (True, 1, 1)]:
            with self.assertRaises(ConfigError):
                ArchiveKey("XAUUSD", *values)

    def test_duplicates_are_preserved_and_regressions_reported(self):
        result = self.inspect(HEADER + ROW + ROW + ROW.replace(".064Z", ".063Z"))
        self.assertEqual(result["row_count"], 3)
        self.assertEqual(result["adjacent_equal_timestamp_rows"], 1)
        self.assertEqual(result["timestamp_regressions"], 1)
        self.assertFalse(result["coverage_verified"])
        self.assertTrue(result["crc_verified"])

    def test_contract_defects_and_limits(self):
        for content in [HEADER, HEADER.replace("Bid", "bid") + ROW, HEADER + ROW.replace("XAUUSD", "EURUSD"),
                        HEADER + ROW.replace(".064Z", "Z"), HEADER + ROW.replace("09-01", "08-31"),
                        HEADER + ROW.replace("4452.259", "NaN"), HEADER + ROW.replace("4452.259", "4453"),
                        HEADER + ROW.replace("4452.259", "0")]:
            with self.subTest(content=content), self.assertRaises(SourceError):
                self.inspect(content)
        with self.assertRaises(SourceError):
            self.inspect(HEADER + ROW, member="../unsafe.csv")
        with self.assertRaises(SourceError):
            self.inspect(HEADER + ROW, limits=replace(self.profile.limits, max_uncompressed_bytes=1))
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "bad.zip"
            path.write_bytes(b"<html>denied</html>")
            with self.assertRaises(SourceError):
                inspect_archive(path, self.key, self.profile.limits)

    def test_bom_and_zero_spread(self):
        self.assertEqual(self.inspect("\ufeff" + HEADER + ROW.replace("4452.441", "4452.259"))["row_count"], 1)

    def test_http_classification(self):
        for code, expected in [(403, "ACCESS_DENIED"), (404, "NOT_FOUND"), (429, "RATE_LIMITED"), (503, "RETRYABLE_ERROR")]:
            with self.subTest(code=code), patch("urllib.request.build_opener") as factory:
                factory.return_value.open.side_effect = urllib.error.HTTPError(self.key.url, code, "", Message(), io.BytesIO())
                self.assertEqual(probe_archive(self.key, self.profile.network).state, expected)
        with patch("urllib.request.build_opener") as factory:
            response = MagicMock()
            response.status = 200
            response.geturl.return_value = self.key.url
            response.headers = Message()
            response.headers["Content-Type"] = "text/html"
            factory.return_value.open.return_value.__enter__.return_value = response
            self.assertEqual(probe_archive(self.key, self.profile.network).state, "INVALID_RESPONSE")

    def test_redirects_stay_on_archive_host(self):
        for url in ["http://ticks.ex2archive.com/ticks/a", "https://other.test/ticks/a",
                    "https://ticks.ex2archive.com/ticks/../private", "https://ticks.ex2archive.com/ticks/a?token=secret"]:
            self.assertFalse(_allowed_url(url))
        self.assertTrue(_allowed_url(self.key.url))
