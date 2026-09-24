from .test_contract import RunFixtureCase


class CandleTests(RunFixtureCase):
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
