import unittest

from pool.steps import Steps


class StepsTest(unittest.TestCase):
    def test_value_is_half_open(self):
        s = Steps()
        s.add(0, 5, 2)
        self.assertEqual((s.value(0), s.value(4), s.value(5)), (2, 2, 0))

    def test_max_includes_end(self):
        s = Steps()
        s.add(5, 9, 3)
        self.assertEqual(s.max(0, 5), 3)
        self.assertEqual(s.max(0, 4), 0)

    def test_points(self):
        s = Steps()
        s.add(0, 5, 2)
        s.add(5, 9, 2)
        self.assertEqual(s.points(), [0, 9])
