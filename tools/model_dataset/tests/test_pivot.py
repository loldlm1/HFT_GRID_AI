from decimal import Decimal

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

    def test_midpoint_buy_uses_bid_trigger_and_ask_entry(self):
        for trial in self.tables['trials.tsv']:
            if trial['entry_policy'] != 'MIDPOINT_50':
                continue
            entry = Decimal('91.1')
            tp = entry + int(trial['rr']) * (entry - Decimal(trial['sl']))
            trial.update(entry_bid='90.9', entry_ask=str(entry), entry_price=str(entry), tp=str(tp))
            outcome = next(r for r in self.tables['outcomes.tsv'] if r['trial_id'] == trial['trial_id'])
            outcome.update(entry_price=str(entry), tp=str(tp), exit_price=str(tp), gross_profit=str(tp-entry))
        self.validate()

    def test_midpoint_requires_bid_touch(self):
        self.reject(lambda t: next(r for r in t['trials.tsv'] if r['entry_policy']=='MIDPOINT_50').update(entry_bid='91.01'))

    def test_opaque_broker_identity(self):
        self.tables['pivot_origins.tsv'][0]['broker_signal_id'] = 'broker_18446744073709551615'
        self.validate()

    def test_parity_cannot_change_geometry(self):
        self.reject(lambda t:next(r for r in t['trials.tsv'] if r['role']=='PARITY').update(volume='0.02'))

    def test_only_structural_one_r_can_send(self):
        self.reject(lambda t:next(r for r in t['trials.tsv'] if r['role']=='BROKER').update(entry_policy='MIDPOINT_50'))


class PivotExpiryTests(RunFixtureCase):
    engine = 'PIVOT_MACRO_V2'

    def test_new_profile_and_per_entry_deadline(self):
        self.assertEqual(self.validate()['counts']['trials.tsv'], 10)
        self.assertNotEqual(self.tables['trials.tsv'][0]['deadline_time_msc'],
                            self.tables['trials.tsv'][-1]['deadline_time_msc'])

    def test_deadline_cannot_follow_origin_for_later_midpoint(self):
        self.reject(lambda t: t['trials.tsv'][-1].update(deadline_time_msc=t['trials.tsv'][0]['deadline_time_msc']))

    def test_equal_deadline_is_time_exit(self):
        outcome = self.tables['outcomes.tsv'][0]
        outcome.update(status='TIME_EXIT', exit_time_msc=outcome['deadline_time_msc'],
                       observed_time_msc=outcome['deadline_time_msc'], duration_ms='3600000',
                       binary_label=None, binary_eligible='0', exclusion_reason='TIME_EXIT')
        self.validate()
        self.reject(lambda t: t['outcomes.tsv'][0].update(status='TP_FIRST', binary_label='1', binary_eligible='1'))

    def test_legacy_tuple_cannot_claim_new_expiry(self):
        self.reject(lambda t: next(r for r in t['run_manifest.tsv'] if r['key']=='outcome_policy').update(value='PIVOT_MACRO_OUTCOME_V1'))

    def test_timeout_requires_observed_executable_price(self):
        self.reject(lambda t: t['outcomes.tsv'][0].update(status='TIME_EXIT', exit_price=None))
