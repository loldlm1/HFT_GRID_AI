import json
import tempfile
import unittest
from pathlib import Path

from tools.exness_tick_history.config import ConfigError, load_profile
from tools.exness_tick_history.config import COMPARISON_DEFAULTS


class ConfigTests(unittest.TestCase):
    def load(self, extra=""):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "profile.toml"
            path.write_text('schema_version = 1\n' + extra, encoding="utf-8")
            return load_profile(path, workspace=Path(directory))

    def test_defaults_are_explicitly_unverified(self):
        profile = self.load()
        self.assertEqual(profile.instrument.broker_symbol, "XAUUSD")
        self.assertEqual(profile.selection.end, "latest-published")
        self.assertEqual(profile.comparison_status, "PROPOSED")
        self.assertIn("archive_to_broker_feed_mapping", profile.summary()["unresolved_operational_requirements"])

    def test_suffix_and_exact_override(self):
        self.assertEqual(self.load('[instrument]\nbroker_suffix = "m"').instrument.broker_symbol, "XAUUSDm")
        self.assertEqual(self.load('[instrument]\nbroker_symbol = "GOLD"').instrument.broker_symbol, "GOLD")
        with self.assertRaises(ConfigError):
            self.load('[instrument]\nbroker_suffix = "m"\nbroker_symbol = "GOLD"')

    def test_invalid_profiles(self):
        cases = ['unknown = 1', '[network]\nworkers = true', '[network]\nworkers = 999999999999999999999999999999999',
                 '[network]\ntimeout_seconds = nan', '[instrument]\narchive_symbol = "../XAUUSD"',
                 '[instrument]\nbroker_suffix = "/m"', '[instrument]\naccount_type = "guess"',
                 '[selection]\nstart = "2026-09-02"\nend = "2026-09-01"',
                 '[selection]\nstart = "2026-02-29"', '[comparison]\nstatus = "PINNED"',
                 '[comparison]\nmax_unexplained_clock_offset_seconds = 3600',
                 '[storage]\ndata_root = "."', '[storage]\ndata_root = "tools/raw"',
                 '[storage]\ndata_root = ".."',
                 '[terminal]\nhost_root = "/tmp"', '[terminal]\nwine_prefix = "relative"']
        for case in cases:
            with self.subTest(case=case), self.assertRaises(ConfigError):
                self.load(case)

    def test_redaction_and_unknown_secret_key(self):
        result = self.load('[instrument]\nserver_alias = "private-server-123"').summary()
        self.assertNotIn("private-server-123", json.dumps(result))
        with self.assertRaises(ConfigError) as raised:
            self.load('[network]\npassword = "private-password"')
        self.assertNotIn("private-password", str(raised.exception))

    def test_wine_mapping_is_confined(self):
        profile = self.load('[terminal]\nhost_root = "/tmp/mt5"\nwindows_root = \'Z:\\tmp\\mt5\'')
        self.assertEqual(str(profile.terminal.windows_path(Path("/tmp/mt5/Files/a.tsv"))), r"Z:\tmp\mt5\Files\a.tsv")
        with self.assertRaises(ConfigError):
            profile.terminal.windows_path(Path("/tmp/mt5/../private"))

    def test_symlink_cannot_escape_host_mapping(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "link").symlink_to("/etc", target_is_directory=True)
            profile = self.load(f'[terminal]\nhost_root = "{root}"\nwindows_root = \'Z:\\mt5\'')
            with self.assertRaises(ConfigError):
                profile.terminal.windows_path(root / "link/passwd")

    def test_pinning_requires_numerical_limits_and_independent_pilot_provenance(self):
        text = '[comparison]\nstatus = "PINNED"\n' + "\n".join(f"{key} = {value}" for key, value in COMPARISON_DEFAULTS.items())
        with self.assertRaises(ConfigError):
            self.load(text)
        text += '\nname = "modern-pilot"\npinned_at_utc = "2026-09-01T00:00:00.000Z"\npilot_dates = ["2026-08-25"]\nrationale = "Separate pilot"'
        self.assertEqual(self.load(text).comparison_provenance["pilot_dates"], ["2026-08-25"])
