from .test_contract import RunFixtureCase
from decimal import Decimal


class CandleTests(RunFixtureCase):
    def test_fresh_request_can_follow_frozen_decision(self):
        for trial in self.tables['trials.tsv']:
            for key in ('declared_time_msc', 'entry_time_msc', 'deadline_time_msc'):
                trial[key] = str(int(trial[key]) + 1)
        for outcome in self.tables['outcomes.tsv']:
            for key in ('entry_time_msc', 'deadline_time_msc', 'exit_time_msc', 'observed_time_msc'):
                outcome[key] = str(int(outcome[key]) + 1)
        for check in self.tables['execution_checks.tsv']:
            check['time_msc'] = str(int(check['time_msc']) + 1)
        self.validate()

    def test_request_cannot_precede_decision(self):
        self.reject(lambda t: t['execution_checks.tsv'][0].update(time_msc=str(int(t['entry_attempts.tsv'][0]['decision_time_msc']) - 1)))

    def test_wrong_pattern(self):
        self.reject(lambda t:t['candle_signals.tsv'][0].update(pattern='HARAMI'))

    def test_missing_original_direction(self):
        self.reject(lambda t:t['entry_attempts.tsv'][1].update(direction='BUY'))

    def test_reentry_without_confirmed_stop(self):
        def change(t):
            t['entry_attempts.tsv'][1].update(entry_type='REENTRY',parent_attempt_id='A0')
            t['candle_attempts.tsv'][1].update(generation='1',reentry_cause='BROKER_SL')
        self.reject(change)

    def test_changed_atr_risk(self):
        self.reject(lambda t:t['candle_attempts.tsv'][0].update(atr_1='5'))

    def test_changed_protection(self):
        self.reject(lambda t:t['outcomes.tsv'][0].update(sl='80'))

    def test_mislabeled_expiry(self):
        self.reject(lambda t:t['outcomes.tsv'][0].update(status='TIME_EXIT'))

    def test_censored_is_not_loss(self):
        self.reject(lambda t:t['outcomes.tsv'][0].update(status='CENSORED_RUN_END',binary_label='0'))

    def test_virtual_costs_not_invented(self):
        self.reject(lambda t:next(r for r in t['outcomes.tsv'] if r['role']=='VIRTUAL').update(costs='0',net_profit='2'))


class CandleAdmissionTests(RunFixtureCase):
    engine = 'CANDLE_PATTERN_ATR_V3'

    def test_new_profile_both_directions(self):
        self.validate()

    def test_equality_is_admitted_and_one_point_below_is_rejected(self):
        # Risk is 1.00, spread 0.10, tick 0.01: broker distance 69 points
        # makes the independently calculated minimum exactly 1.00.
        for trial in self.tables['trials.tsv']:
            trial.update(stops_level_points='10', freeze_level_points='69', minimum_risk_distance_points='100')
        for check in self.tables['execution_checks.tsv']:
            check.update(stops_distance_points='10', freeze_distance_points='69')
        self.validate()
        for trial in self.tables['trials.tsv']:
            trial.update(freeze_level_points='70', minimum_risk_distance_points='101')
        from ..reader import ContractError
        with self.assertRaisesRegex(ContractError, 'False distance eligibility'):
            self.validate()

    def test_wrong_multiplier_or_partial_proof_fails(self):
        self.reject(lambda t: t['trials.tsv'][0].update(minimum_risk_distance_points='11'))

    def test_missing_admission_fact_fails(self):
        self.reject(lambda t: t['trials.tsv'][0].update(freeze_level_points=None))

    def test_request_cannot_recapture_other_spread(self):
        self.reject(lambda t: t['execution_checks.tsv'][0].update(ask='101.11'))

    def test_tick_size_is_not_assumed_to_be_point(self):
        for record in self.tables['run_manifest.tsv']:
            if record['key']=='tick_size': record['value']='0.1'
        for snapshot in self.tables['feature_snapshots.tsv']: snapshot['tick_size']='0.1'
        for trial in self.tables['trials.tsv']:trial.update(trade_tick_size='0.1', minimum_risk_distance_points='40')
        for check in self.tables['execution_checks.tsv']:check['trade_tick_size']='0.1'
        self.validate()

    def test_zero_spread_still_needs_one_tick(self):
        for trial in self.tables['trials.tsv']:
            trial.update(entry_bid=trial['entry_price'], entry_ask=trial['entry_price'], spread_points='0', minimum_risk_distance_points='1')
        for check in self.tables['execution_checks.tsv']:
            check.update(bid=check['entry_price'], ask=check['entry_price'], spread_points='0')
        self.validate()

    def test_distance_rejections_have_no_entry_or_binary_target(self):
        self.tables['trials.tsv']=[t for t in self.tables['trials.tsv'] if t['role']!='PARITY']
        self.tables['outcomes.tsv']=[o for o in self.tables['outcomes.tsv'] if o['role']!='PARITY']
        for t in self.tables['trials.tsv']:
            t.update(stops_level_points='100', minimum_risk_distance_points='131', distance_eligible='0',
                     eligibility='REJECTED' if t['role']=='BROKER' else 'INELIGIBLE_DISTANCE', entry_time_msc=None)
        for o in self.tables['outcomes.tsv']:
            o.update(status='REJECTED' if o['role']=='BROKER' else 'INELIGIBLE_DISTANCE',
                     entry_time_msc=None, deadline_time_msc=None, exit_time_msc=None, duration_ms=None,
                     entry_price=None, exit_price=None, binary_eligible='0', binary_label=None,
                     gross_profit=None, costs=None, net_profit=None, gross_r=None, position_id=None, fill_deviation_points=None)
        for c in self.tables['execution_checks.tsv']:
            c.update(allowed='0', reason='ENTRY_RISK_TOO_SMALL', stops_distance_points='100', send_retcode='0', order_ticket=None, deal_ticket=None)
        self.validate()
        self.reject(lambda t: t['outcomes.tsv'][0].update(binary_eligible='1', binary_label='0'))

    def test_no_retroactive_fill_gate(self):
        outcome = self.tables['outcomes.tsv'][0]
        # The fill differs from the submitted quote; proof remains tied to request.
        entry = Decimal(outcome['entry_price']) + Decimal('0.01')
        gross = Decimal(outcome['exit_price']) - entry
        outcome.update(entry_price=str(entry), fill_deviation_points='1', gross_profit=str(gross),
                       net_profit=str(gross-Decimal('0.1')), gross_r=str(gross/(entry-Decimal(outcome['sl']))))
        self.validate()
