from __future__ import annotations

import json
import sys
import unittest
from pathlib import Path

MODULE_ROOT = Path(__file__).resolve().parents[1]
if str(MODULE_ROOT) not in sys.path:
    sys.path.insert(0, str(MODULE_ROOT))

from schema_contract import (
    COLUMN_TYPE_REGISTRY_SHA256,
    DEEP_PIVOT_EVENTS_FILE,
    DEEP_PIVOT_PARENT_LINKS_FILE,
    DEEP_VIRTUAL_OUTCOMES_FILE,
    DEEP_VIRTUAL_TRIALS_FILE,
    RUN_FILES,
    SUPPORTED_FEATURE_SET_ID,
    SUPPORTED_SCHEMA_VERSION,
    validate_run,
)

FIXTURES = Path(__file__).parent / "fixtures"
FIXTURE = FIXTURES / "schema_v13_hft_deep_pivot_features"


class PivotFractalV13EvidenceAuditTests(unittest.TestCase):
    def test_fixture_provenance_pins_contract_and_hashes(self) -> None:
        provenance = json.loads(
            (FIXTURE / "fixture_provenance.json").read_text(encoding="ascii")
        )
        self.assertEqual(provenance["schema_version"], SUPPORTED_SCHEMA_VERSION)
        self.assertEqual(provenance["feature_set_id"], SUPPORTED_FEATURE_SET_ID)
        self.assertEqual(provenance["registry_sha256"], COLUMN_TYPE_REGISTRY_SHA256)
        self.assertEqual(set(provenance["files"]), set(RUN_FILES))
        self.assertTrue(all(len(value) == 64 for value in provenance["files"].values()))

    def test_fixture_reconciles_native_evidence_grains(self) -> None:
        validation = validate_run(FIXTURES, FIXTURE.name)
        self.assertEqual(validation.row_counts[DEEP_PIVOT_EVENTS_FILE], 1)
        self.assertEqual(validation.row_counts[DEEP_PIVOT_PARENT_LINKS_FILE], 2)
        self.assertEqual(validation.row_counts[DEEP_VIRTUAL_TRIALS_FILE], 3)
        self.assertEqual(validation.row_counts[DEEP_VIRTUAL_OUTCOMES_FILE], 6)
        self.assertEqual(validation.warnings, ())


if __name__ == "__main__":
    unittest.main()
