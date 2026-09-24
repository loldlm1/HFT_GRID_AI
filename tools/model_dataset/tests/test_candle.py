from .test_contract import RunFixtureCase


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
