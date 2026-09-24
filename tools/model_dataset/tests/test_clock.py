from datetime import datetime, timezone
import unittest

from ..clock import analysis_clock
from ..reader import ContractError, ModelRun
from .fixtures import make_run
from .test_contract import RunFixtureCase


def msc(value):
    return int(datetime.fromisoformat(value).replace(tzinfo=timezone.utc).timestamp()) * 1000


class ClockTests(unittest.TestCase):
    def test_exact_transition_milliseconds(self):
        for instant, before, after in (("2016-03-13T07:00:00", -60, 0), ("2016-11-06T06:00:00", 0, -60)):
            raw = msc(instant)
            self.assertEqual(analysis_clock(raw-1, "EXNESS_SESSION"), (raw-1+before*60000, before))
            self.assertEqual(analysis_clock(raw, "EXNESS_SESSION"), (raw+after*60000, after))

    def test_us_uk_mismatch_weeks_and_year_boundary(self):
        for value, offset in (("2016-03-16T12:00:00",0), ("2016-10-31T12:00:00",0), ("2016-01-01T00:00:00",-60)):
            raw=msc(value)
            self.assertEqual(analysis_clock(raw,"EXNESS_SESSION"),(raw+offset*60000,offset))
            self.assertEqual(analysis_clock(raw,"FIXED_TIME_SESSIONS"),(raw,0))

    def test_coverage_and_unknown_policy(self):
        for instant,policy in ((msc("2006-12-31T12:00:00"),"EXNESS_SESSION"),(msc("2100-01-01T00:00:00"),"EXNESS_SESSION"),(1,"UNKNOWN"),(0,"FIXED_TIME_SESSIONS")):
            with self.assertRaises(ValueError): analysis_clock(instant,policy)


class ClockWireTests(RunFixtureCase):
    def test_exness_fixture(self):
        make_run(self.path,session="EXNESS_SESSION")
        with ModelRun(self.path) as run: self.assertEqual(run.manifest['broker_time_basis'],'UTC_SHIFT_0')

    def test_partial_null_triplet_rejected(self):
        path=self.path/'entry_attempts.tsv'
        columns, *rows=path.read_text().splitlines()
        keys=columns.split('\t'); values=rows[0].split('\t')
        values[keys.index('decision_analysis_time_msc')]='\\N'
        path.write_text(columns+'\n'+'\t'.join(values)+'\n'+'\n'.join(rows[1:])+'\n')
        with self.assertRaises(ContractError):
            with ModelRun(self.path): pass
