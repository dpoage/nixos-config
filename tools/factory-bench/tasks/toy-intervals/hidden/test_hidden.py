import unittest

from intervals import IntervalSet


class Add(unittest.TestCase):
    def test_empty(self):
        self.assertEqual(IntervalSet().spans(), [])

    def test_single(self):
        s = IntervalSet()
        s.add(1, 4)
        self.assertEqual(s.spans(), [(1, 4)])

    def test_adjacent_merge(self):
        s = IntervalSet([(1, 2), (2, 3)])
        self.assertEqual(s.spans(), [(1, 3)])

    def test_gap_of_one_stays_apart(self):
        s = IntervalSet([(1, 2), (3, 4)])
        self.assertEqual(s.spans(), [(1, 2), (3, 4)])

    def test_bridge_merges_three(self):
        s = IntervalSet([(1, 2), (5, 6), (9, 10)])
        s.add(2, 9)
        self.assertEqual(s.spans(), [(1, 10)])

    def test_sorted_regardless_of_insert_order(self):
        s = IntervalSet([(7, 9), (-5, -2), (0, 1)])
        self.assertEqual(s.spans(), [(-5, -2), (0, 1), (7, 9)])

    def test_contained_add_changes_nothing(self):
        s = IntervalSet([(0, 10)])
        s.add(3, 4)
        self.assertEqual(s.spans(), [(0, 10)])

    def test_empty_span_is_noop(self):
        s = IntervalSet([(1, 2), (3, 4)])
        s.add(2, 2)
        self.assertEqual(s.spans(), [(1, 2), (3, 4)])

    def test_reversed_raises_and_changes_nothing(self):
        s = IntervalSet([(1, 2)])
        with self.assertRaises(ValueError):
            s.add(5, 4)
        self.assertEqual(s.spans(), [(1, 2)])

    def test_constructor_reversed_raises(self):
        with self.assertRaises(ValueError):
            IntervalSet([(3, 1)])

    def test_spans_returns_tuples(self):
        s = IntervalSet([[1, 3]])
        self.assertEqual(s.spans(), [(1, 3)])
        self.assertIsInstance(s.spans()[0], tuple)

    def test_spans_is_a_copy(self):
        s = IntervalSet([(1, 3)])
        s.spans().append((8, 9))
        self.assertEqual(s.spans(), [(1, 3)])


class Remove(unittest.TestCase):
    def test_split(self):
        s = IntervalSet([(0, 10)])
        s.remove(3, 5)
        self.assertEqual(s.spans(), [(0, 3), (5, 10)])

    def test_trim_edges(self):
        s = IntervalSet([(0, 10)])
        s.remove(-5, 2)
        s.remove(8, 20)
        self.assertEqual(s.spans(), [(2, 8)])

    def test_exact_removes_span(self):
        s = IntervalSet([(0, 3), (5, 8)])
        s.remove(5, 8)
        self.assertEqual(s.spans(), [(0, 3)])

    def test_touching_does_not_trim(self):
        s = IntervalSet([(0, 3)])
        s.remove(3, 9)
        s.remove(-4, 0)
        self.assertEqual(s.spans(), [(0, 3)])

    def test_across_several(self):
        s = IntervalSet([(0, 2), (4, 6), (8, 10)])
        s.remove(1, 9)
        self.assertEqual(s.spans(), [(0, 1), (9, 10)])

    def test_empty_span_is_noop(self):
        s = IntervalSet([(0, 10)])
        s.remove(5, 5)
        self.assertEqual(s.spans(), [(0, 10)])

    def test_reversed_raises(self):
        with self.assertRaises(ValueError):
            IntervalSet([(0, 10)]).remove(6, 5)

    def test_missing_is_noop(self):
        s = IntervalSet([(0, 2)])
        s.remove(50, 60)
        self.assertEqual(s.spans(), [(0, 2)])


class Query(unittest.TestCase):
    def test_contains_is_half_open(self):
        s = IntervalSet([(1, 3)])
        self.assertEqual([x in s for x in (0, 1, 2, 3)], [False, True, True, False])

    def test_total(self):
        self.assertEqual(IntervalSet([(0, 2), (5, 9)]).total(), 6)

    def test_total_after_merge_counts_once(self):
        self.assertEqual(IntervalSet([(0, 5), (3, 8)]).total(), 8)

    def test_gaps_inside(self):
        self.assertEqual(IntervalSet([(2, 4), (6, 8)]).gaps(0, 10), [(0, 2), (4, 6), (8, 10)])

    def test_gaps_clipped_to_window(self):
        self.assertEqual(IntervalSet([(0, 4), (6, 20)]).gaps(3, 7), [(4, 6)])

    def test_gaps_fully_covered(self):
        self.assertEqual(IntervalSet([(0, 10)]).gaps(2, 5), [])

    def test_gaps_of_empty_set(self):
        self.assertEqual(IntervalSet().gaps(2, 5), [(2, 5)])

    def test_gaps_empty_window(self):
        self.assertEqual(IntervalSet().gaps(4, 4), [])

    def test_gaps_reversed_raises(self):
        with self.assertRaises(ValueError):
            IntervalSet().gaps(5, 4)

    def test_equality_is_by_content(self):
        a = IntervalSet([(0, 2), (2, 5)])
        b = IntervalSet([(3, 5), (0, 3)])
        self.assertEqual(a, b)
        self.assertNotEqual(a, IntervalSet([(0, 4)]))
