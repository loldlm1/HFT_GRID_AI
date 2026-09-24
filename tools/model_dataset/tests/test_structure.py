from decimal import Decimal as D
import unittest

from ..feature_contract import structure_class
from .fixtures import NOW, project, structure_prefix
from .test_contract import RunFixtureCase


class StructureTests(unittest.TestCase):
    observations=[(60,10,90,120),(120,12,85,180),(180,9,10,240),(240,11,90,300),(300,13,85,360),(360,8,10,420)]

    def test_initial_and_confirming_candle(self):
        events,forming=structure_prefix(self.observations[:3])
        self.assertEqual(events,[(1,'HIGH',D(12),120,240)])
        self.assertEqual(forming,(-1,'LOW',D(9),180))

    def test_classification_sequence(self):
        events,forming=structure_prefix(self.observations)
        self.assertEqual([e[1] for e in events],['HIGH','LOW','HH'])
        self.assertEqual(forming[1],'LL')

    def test_equal_and_all_direction_classes(self):
        for kind,price,old,expected in ((1,'10.004','10.003','EQ'),(1,'11','10','HH'),(1,'9','10','LH'),(-1,'11','10','HL'),(-1,'9','10','LL')):
            self.assertEqual(structure_class(kind,D(price),D(old),D('.01')),expected)

    def test_shift_zero_reversal_never_commits(self):
        prefix=self.observations[:2]
        first=project(prefix,180,9,10)
        self.assertEqual(first[0],[])
        self.assertEqual(first[1],(-1,'LOW',D(9),180))
        recovered=project(prefix,180,13,90)
        self.assertEqual(recovered[0],[])
        self.assertEqual(recovered[1],(1,'HIGH',D(13),180))
        self.assertEqual(first[1],(-1,'LOW',D(9),180))
        self.assertEqual(structure_prefix(prefix)[1],(1,'HIGH',D(12),120))

    def test_batch_duplicate_and_prefix_invariance(self):
        full=structure_prefix(self.observations)[0]
        for n in range(1,len(self.observations)+1):
            prefix=self.observations[:n]
            self.assertEqual(structure_prefix(prefix)[0],[e for e in full if e[4]<=prefix[-1][3]])
            self.assertEqual(structure_prefix([item for item in prefix for _ in (0,1)]),structure_prefix(prefix))

    def test_strict_thresholds_and_missing_comparator(self):
        self.assertEqual(structure_prefix([(60,10,80,120),(120,9,20,180)]),([],None))
        self.assertEqual(structure_prefix(self.observations[3:])[0][0][1],'HIGH')


class StructureWireTests(RunFixtureCase):
    def test_future_confirmed_state_rejected(self):
        self.reject(lambda t: t['feature_snapshots.tsv'][0].update(confirmed_high_kind='HIGH',confirmed_high_class='HH',confirmed_high_price='102',confirmed_high_pivot_time_msc=str(NOW-60000),confirmed_high_confirmation_time_msc=str(NOW+60000)))
