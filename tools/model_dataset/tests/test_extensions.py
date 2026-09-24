import unittest

from ..schema_contract import COMMON_TABLES, EngineProfile, Field, Table


class ExtensionTests(unittest.TestCase):
    def test_third_descriptor_shares_core(self):
        table=Table('fixture_signals.tsv',(Field('run_id','text'),Field('signal_id','text'),Field('fixture_measurement','decimal',classification='CAUSAL_FEATURE')),'signal_id')
        profile=EngineProfile('FIXTURE_ONLY_V1','1','FIXTURE_OUTCOME_V1',(table,))
        self.assertEqual(profile.tables[:9],COMMON_TABLES)
        self.assertIs(profile.tables[3],COMMON_TABLES[3])

    def test_unsafe_table_names(self):
        for name in ('../escape.tsv','bad-name.tsv','trials.tsv;DROP TABLE trials'):
            with self.assertRaises(ValueError): Table(name,(Field('signal_id','text'),),'signal_id')

    def test_duplicate_column_and_wrong_grain(self):
        with self.assertRaises(ValueError): Table('fixture.tsv',(Field('signal_id','text'),Field('signal_id','text')),'signal_id')
        table=Table('fixture.tsv',(Field('run_id','text'),Field('unknown_id','text')),'unknown_id')
        with self.assertRaises(ValueError): EngineProfile('FIXTURE_V1','1','FIXTURE_POLICY',(table,))

    def test_core_replacement_rejected(self):
        with self.assertRaises(ValueError): EngineProfile('FIXTURE_V1','1','FIXTURE_POLICY',(COMMON_TABLES[3],))
