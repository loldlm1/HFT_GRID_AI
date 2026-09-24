from .test_contract import RunFixtureCase


class PivotTests(RunFixtureCase):
    engine='PIVOT_MACRO_V1'

    def test_valid_macro_lanes(self):
        self.assertEqual(self.validate()['counts']['trials.tsv'],10)

    def test_first_consumption_is_final(self):
        self.reject(lambda t:t['pivot_origins.tsv'][0].update(identity_consumed='0'))

    def test_wrong_pivot_side(self):
        self.reject(lambda t:t['signal_events.tsv'][0].update(direction='SELL'))

    def test_midpoint_without_executable_touch(self):
        self.reject(lambda t:next(r for r in t['trials.tsv'] if r['entry_policy']=='MIDPOINT_50').update(entry_price='95'))

    def test_parity_cannot_change_geometry(self):
        self.reject(lambda t:next(r for r in t['trials.tsv'] if r['role']=='PARITY').update(volume='0.02'))

    def test_only_structural_one_r_can_send(self):
        self.reject(lambda t:next(r for r in t['trials.tsv'] if r['role']=='BROKER').update(entry_policy='MIDPOINT_50'))
