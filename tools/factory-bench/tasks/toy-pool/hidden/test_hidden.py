import pathlib
import unittest

from pool import NoCapacity, Pool

TREE = {"root": None, "a": "root", "b": "root", "a1": "a", "a2": "a"}
QUOTAS = {"root": 10, "a": 6, "b": 6, "a1": 4, "a2": 4}


def make(**over):
    return Pool(dict(TREE), dict(QUOTAS) | over)


class Setup(unittest.TestCase):
    def bad(self, tree, quotas):
        with self.assertRaises(ValueError):
            Pool(tree, quotas)

    def test_empty_tree(self):
        self.bad({}, {})

    def test_two_roots(self):
        self.bad({"r": None, "s": None}, {"r": 1, "s": 1})

    def test_no_root(self):
        self.bad({"a": "b", "b": "a"}, {"a": 1, "b": 1})

    def test_unknown_parent(self):
        self.bad({"r": None, "a": "x"}, {"r": 1, "a": 1})

    def test_cycle_beside_root(self):
        self.bad({"r": None, "a": "b", "b": "a"}, {"r": 1, "a": 1, "b": 1})

    def test_self_parent(self):
        self.bad({"r": None, "a": "a"}, {"r": 1, "a": 1})

    def test_missing_quota(self):
        self.bad({"r": None, "a": "r"}, {"r": 1})

    def test_extra_quota(self):
        self.bad({"r": None}, {"r": 1, "x": 1})

    def test_negative_quota(self):
        self.bad({"r": None}, {"r": -1})

    def test_bool_quota(self):
        self.bad({"r": None}, {"r": True})

    def test_float_quota(self):
        self.bad({"r": None}, {"r": 1.0})

    def test_zero_quota_is_valid(self):
        p = Pool({"r": None}, {"r": 0})
        with self.assertRaises(NoCapacity):
            p.reserve("r", 1, 0, 1)

    def test_new_pool_is_empty(self):
        p = make()
        self.assertEqual((p.events(), p.waiting(), p.timeline("root")), ([], [], []))


class Validation(unittest.TestCase):
    def bad(self, *a, **k):
        p = make()
        with self.assertRaises(ValueError):
            p.reserve(*a, **k)
        self.assertEqual(p.events(), [])
        self.assertEqual(p.reserve("a1", 1, 0, 1), 1)

    def test_unknown_node(self):
        with self.assertRaises(KeyError):
            make().reserve("zz", 1, 0, 1)

    def test_units_zero(self):
        self.bad("a1", 0, 0, 1)

    def test_units_bool(self):
        self.bad("a1", True, 0, 1)

    def test_units_float(self):
        self.bad("a1", 1.0, 0, 1)

    def test_units_string(self):
        self.bad("a1", "1", 0, 1)

    def test_start_equals_end(self):
        self.bad("a1", 1, 3, 3)

    def test_start_above_end(self):
        self.bad("a1", 1, 4, 3)

    def test_start_bool(self):
        self.bad("a1", 1, False, 3)

    def test_end_float(self):
        self.bad("a1", 1, 0, 3.0)

    def test_priority_ten(self):
        self.bad("a1", 1, 0, 1, priority=10)

    def test_priority_negative(self):
        self.bad("a1", 1, 0, 1, priority=-1)

    def test_priority_bool(self):
        self.bad("a1", 1, 0, 1, priority=True)

    def test_priority_nine_is_valid(self):
        self.assertEqual(make().reserve("a1", 1, 0, 1, priority=9), 1)

    def test_unknown_node_wins(self):
        with self.assertRaises(KeyError):
            make().reserve("zz", 0, 5, 5, priority=99)

    def test_negative_instants_are_valid(self):
        p = make()
        p.reserve("a1", 2, -5, -1)
        self.assertEqual((p.usage("a1", -5), p.usage("a1", -1)), (2, 0))


class Capacity(unittest.TestCase):
    def test_usage_may_equal_quota(self):
        p = make()
        self.assertEqual(p.reserve("a1", 4, 0, 5), 1)
        self.assertEqual(p.events(), [("active", 1)])
        self.assertEqual(p.status(1), "active")

    def test_above_quota_raises(self):
        p = make()
        with self.assertRaises(NoCapacity):
            p.reserve("a1", 5, 0, 5)
        self.assertEqual(p.events(), [])

    def test_no_capacity_is_not_value_error(self):
        self.assertFalse(issubclass(NoCapacity, ValueError))
        self.assertTrue(issubclass(NoCapacity, Exception))

    def test_adjacent_intervals_share_nothing(self):
        p = make()
        p.reserve("a1", 4, 0, 5)
        p.reserve("a1", 4, 5, 9)
        p.reserve("a1", 4, -3, 0)
        self.assertEqual(p.peak("a1", -3, 9), 4)

    def test_overlap_of_one_instant_fails(self):
        p = make()
        p.reserve("a1", 4, 0, 5)
        with self.assertRaises(NoCapacity) as c:
            p.reserve("a1", 1, 4, 9)
        self.assertEqual((c.exception.node, c.exception.at), ("a1", 4))

    def test_parent_limits_children(self):
        p = make()
        p.reserve("a1", 4, 0, 5)
        with self.assertRaises(NoCapacity) as c:
            p.reserve("a2", 3, 0, 5)
        self.assertEqual((c.exception.node, c.exception.at), ("a", 0))
        self.assertEqual(p.reserve("a2", 2, 0, 5), 2)

    def test_root_limits_branches(self):
        p = make()
        p.reserve("a", 6, 0, 5)
        with self.assertRaises(NoCapacity) as c:
            p.reserve("b", 5, 0, 5)
        self.assertEqual(c.exception.node, "root")

    def test_reservation_at_inner_node_counts_for_it(self):
        p = make()
        p.reserve("a", 5, 0, 5)
        with self.assertRaises(NoCapacity) as c:
            p.reserve("a1", 2, 0, 5)
        self.assertEqual(c.exception.node, "a")
        self.assertEqual(p.usage("a1", 0), 0)

    def test_failed_reserve_uses_no_id(self):
        p = make()
        with self.assertRaises(NoCapacity):
            p.reserve("a1", 5, 0, 5)
        self.assertEqual(p.reserve("a1", 1, 0, 5), 1)

    def test_first_violation_is_lowest_instant(self):
        p = make()
        p.reserve("a1", 4, 3, 5)
        p.reserve("a1", 4, 7, 9)
        with self.assertRaises(NoCapacity) as c:
            p.reserve("a1", 1, 0, 10)
        self.assertEqual((c.exception.node, c.exception.at), ("a1", 3))

    def test_first_violation_at_start_inside_existing(self):
        p = make()
        p.reserve("a1", 4, 0, 5)
        with self.assertRaises(NoCapacity) as c:
            p.reserve("a1", 1, 2, 8)
        self.assertEqual(c.exception.at, 2)

    def test_nearest_node_beats_lower_instant(self):
        p = make()
        p.reserve("a2", 4, 1, 3)   # a is at 4 on [1,3)
        p.reserve("a1", 3, 5, 7)   # a1 is at 3 on [5,7)
        with self.assertRaises(NoCapacity) as c:
            p.reserve("a1", 3, 0, 9)  # a over at 1; a1 over at 5
        self.assertEqual((c.exception.node, c.exception.at), ("a1", 5))

    def test_message_names_node_and_instant(self):
        p = make()
        p.reserve("a2", 4, 17, 20)
        with self.assertRaises(NoCapacity) as c:
            p.reserve("a2", 1, 10, 30)
        self.assertIn("a2", str(c.exception))
        self.assertIn("17", str(c.exception))


class Queries(unittest.TestCase):
    def test_usage_rolls_up(self):
        p = make()
        p.reserve("a1", 2, 0, 5)
        p.reserve("a2", 3, 0, 5)
        p.reserve("b", 1, 0, 5)
        self.assertEqual([p.usage(n, 0) for n in ("a1", "a2", "a", "b", "root")], [2, 3, 5, 1, 6])

    def test_usage_is_half_open(self):
        p = make()
        p.reserve("a1", 2, 0, 5)
        self.assertEqual([p.usage("a1", t) for t in (-1, 0, 4, 5)], [0, 2, 2, 0])

    def test_usage_unknown_node(self):
        with self.assertRaises(KeyError):
            make().usage("zz", 0)

    def test_peak_excludes_end(self):
        p = make()
        p.reserve("a1", 3, 5, 9)
        self.assertEqual(p.peak("a1", 0, 5), 0)
        self.assertEqual(p.peak("a1", 0, 6), 3)

    def test_peak_inside_and_before(self):
        p = make()
        p.reserve("a1", 3, 0, 9)
        p.reserve("a1", 1, 4, 6)
        self.assertEqual(p.peak("a1", 6, 8), 3)
        self.assertEqual(p.peak("a1", 2, 5), 4)
        self.assertEqual(p.peak("a", 5, 6), 4)

    def test_peak_bad_range(self):
        p = make()
        for s, e in ((3, 3), (4, 3)):
            with self.assertRaises(ValueError):
                p.peak("a1", s, e)

    def test_peak_unknown_node(self):
        with self.assertRaises(KeyError):
            make().peak("zz", 0, 1)

    def test_timeline_simple(self):
        p = make()
        p.reserve("a1", 2, 0, 5)
        self.assertEqual(p.timeline("a1"), [(0, 2), (5, 0)])
        self.assertEqual(p.timeline("b"), [])

    def test_timeline_merges_adjacent_equal(self):
        p = make()
        p.reserve("a1", 2, 0, 5)
        p.reserve("a1", 2, 5, 9)
        self.assertEqual(p.timeline("a1"), [(0, 2), (9, 0)])

    def test_timeline_merges_across_children(self):
        p = make()
        p.reserve("a1", 2, 0, 5)
        p.reserve("a2", 2, 5, 9)
        self.assertEqual(p.timeline("a"), [(0, 2), (9, 0)])
        self.assertEqual(p.timeline("a2"), [(5, 2), (9, 0)])

    def test_timeline_steps(self):
        p = make()
        p.reserve("a1", 2, 0, 6)
        p.reserve("a2", 3, 4, 8)
        p.reserve("b", 1, 20, 21)
        self.assertEqual(p.timeline("a"), [(0, 2), (4, 5), (6, 3), (8, 0)])
        self.assertEqual(p.timeline("root"), [(0, 2), (4, 5), (6, 3), (8, 0), (20, 1), (21, 0)])

    def test_timeline_ignores_waiting_and_cancelled(self):
        p = make()
        p.reserve("a1", 4, 0, 5)
        p.reserve("a1", 4, 2, 7, wait=True)
        p.reserve("a2", 1, 0, 5)
        p.cancel(3)
        self.assertEqual(p.timeline("a"), [(0, 4), (5, 0)])

    def test_timeline_unknown_node(self):
        with self.assertRaises(KeyError):
            make().timeline("zz")


class Waiting(unittest.TestCase):
    def test_wait_returns_waiting_id(self):
        p = make()
        p.reserve("a1", 4, 0, 5)
        self.assertEqual(p.reserve("a1", 1, 0, 5, wait=True), 2)
        self.assertEqual(p.status(2), "waiting")
        self.assertEqual(p.events(), [("active", 1), ("waiting", 2)])
        self.assertEqual(p.usage("a1", 0), 4)

    def test_wait_that_fits_is_active(self):
        p = make()
        p.reserve("a1", 1, 0, 5, wait=True)
        self.assertEqual((p.status(1), p.waiting()), ("active", []))

    def test_waiting_order(self):
        p = make()
        p.reserve("a1", 4, 0, 5)
        p.reserve("a1", 1, 0, 5, wait=True, priority=1)
        p.reserve("a1", 1, 0, 5, wait=True, priority=3)
        p.reserve("a1", 1, 0, 5, wait=True, priority=1)
        p.reserve("a1", 1, 0, 5, wait=True, priority=3)
        self.assertEqual(p.waiting(), [3, 5, 2, 4])

    def test_waiting_uses_an_id(self):
        p = make()
        p.reserve("a1", 4, 0, 5)
        p.reserve("a1", 1, 0, 5, wait=True)
        self.assertEqual(p.reserve("a2", 1, 0, 5), 3)

    def test_cancel_promotes(self):
        p = make()
        p.reserve("a1", 4, 0, 5)
        p.reserve("a1", 3, 2, 7, wait=True)
        p.cancel(1)
        self.assertEqual(p.status(2), "active")
        self.assertEqual(p.events()[2:], [("cancelled", 1), ("promoted", 2)])
        self.assertEqual(p.waiting(), [])

    def test_promotion_follows_waiting_order(self):
        p = make()
        p.reserve("a1", 4, 0, 5)
        p.reserve("a1", 3, 0, 5, wait=True, priority=1)
        p.reserve("a1", 3, 0, 5, wait=True, priority=2)
        p.cancel(1)
        self.assertEqual((p.status(2), p.status(3)), ("waiting", "active"))

    def test_promotion_skips_what_does_not_fit(self):
        p = make()
        p.reserve("a1", 3, 0, 5)
        p.reserve("a1", 4, 0, 5, wait=True, priority=5)
        p.reserve("a1", 2, 0, 5, wait=True, priority=1)
        p.reserve("a1", 1, 0, 5)
        p.cancel(4)
        self.assertEqual(p.waiting(), [2, 3])
        p.set_quota("a1", 5)
        self.assertEqual((p.status(2), p.status(3)), ("waiting", "active"))

    def test_two_promotions_in_order(self):
        p = make()
        p.reserve("a1", 4, 0, 5)
        p.reserve("a1", 2, 0, 5, wait=True)
        p.reserve("a1", 2, 0, 5, wait=True, priority=4)
        p.reserve("a1", 1, 0, 5, wait=True, priority=9)
        p.cancel(1)
        self.assertEqual(p.events()[-3:], [("cancelled", 1), ("promoted", 4), ("promoted", 3)])
        self.assertEqual(p.waiting(), [2])

    def test_cancel_waiting(self):
        p = make()
        p.reserve("a1", 4, 0, 5)
        p.reserve("a1", 1, 0, 5, wait=True)
        p.cancel(2)
        self.assertEqual((p.status(2), p.waiting()), ("cancelled", []))
        self.assertEqual(p.events()[-1], ("cancelled", 2))
        p.cancel(1)
        self.assertEqual(p.status(2), "cancelled")

    def test_cancel_twice(self):
        p = make()
        p.reserve("a1", 4, 0, 5)
        p.cancel(1)
        with self.assertRaises(ValueError):
            p.cancel(1)
        self.assertEqual(len(p.events()), 2)

    def test_cancel_unknown(self):
        p = make()
        for rid in (0, 1, 99):
            with self.assertRaises(KeyError):
                p.cancel(rid)

    def test_waiter_blocked_by_ancestor_is_promoted_by_sibling_cancel(self):
        p = make()
        p.reserve("a2", 4, 0, 5)
        p.reserve("a1", 4, 0, 5, wait=True)
        self.assertEqual(p.status(2), "waiting")
        p.cancel(1)
        self.assertEqual(p.status(2), "active")


class Preempt(unittest.TestCase):
    def test_preempts_lower_priority(self):
        p = make()
        p.reserve("a1", 4, 0, 5)
        self.assertEqual(p.reserve("a1", 2, 0, 5, priority=1, preempt=True), 2)
        self.assertEqual((p.status(1), p.status(2)), ("preempted", "active"))
        self.assertEqual(p.events(), [("active", 1), ("preempted", 1), ("active", 2)])

    def test_equal_priority_is_safe(self):
        p = make()
        p.reserve("a1", 4, 0, 5, priority=3)
        with self.assertRaises(NoCapacity) as c:
            p.reserve("a1", 2, 0, 5, priority=3, preempt=True)
        self.assertEqual((c.exception.node, c.exception.at), ("a1", 0))
        self.assertEqual(p.status(1), "active")

    def test_preempt_flag_unused_when_it_fits(self):
        p = make()
        p.reserve("a1", 2, 0, 5)
        p.reserve("a1", 2, 0, 5, priority=9, preempt=True)
        self.assertEqual(p.status(1), "active")

    def test_lowest_priority_goes_first(self):
        p = make()
        p.reserve("a1", 2, 0, 5, priority=2)
        p.reserve("a1", 2, 0, 5, priority=1)
        p.reserve("a1", 2, 0, 5, priority=5, preempt=True)
        self.assertEqual((p.status(1), p.status(2)), ("active", "preempted"))

    def test_later_start_goes_first(self):
        p = make()
        p.reserve("a1", 2, 0, 5)
        p.reserve("a1", 2, 2, 5)
        p.reserve("a1", 2, 3, 5, priority=5, preempt=True)
        self.assertEqual((p.status(1), p.status(2)), ("active", "preempted"))

    def test_higher_id_goes_first(self):
        p = make()
        p.reserve("a1", 2, 0, 5)
        p.reserve("a1", 2, 0, 5)
        p.reserve("a1", 2, 0, 5, priority=5, preempt=True)
        self.assertEqual((p.status(1), p.status(2)), ("active", "preempted"))

    def test_takes_as_many_as_needed(self):
        p = make()
        p.reserve("a1", 1, 0, 5)
        p.reserve("a1", 1, 0, 5)
        p.reserve("a1", 2, 0, 5)
        p.reserve("a1", 3, 0, 5, priority=1, preempt=True)
        self.assertEqual([p.status(i) for i in (1, 2, 3)], ["active", "preempted", "preempted"])
        self.assertEqual(p.events()[3:], [("preempted", 3), ("preempted", 2), ("active", 4)])

    def test_skips_candidate_outside_the_violated_subtree(self):
        p = make()
        p.reserve("a1", 4, 0, 5, priority=1)
        p.reserve("b", 2, 0, 5)          # lower priority, same instants, other branch
        p.reserve("a1", 1, 0, 5, priority=2, preempt=True)
        self.assertEqual((p.status(1), p.status(2)), ("preempted", "active"))

    def test_skips_candidate_at_instants_without_violation(self):
        p = make()
        p.reserve("a1", 4, 0, 3, priority=1)
        p.reserve("a1", 2, 6, 9)         # lower priority, shares instants, no violation there
        p.reserve("a1", 2, 0, 9, priority=2, preempt=True)
        self.assertEqual((p.status(1), p.status(2)), ("preempted", "active"))

    def test_candidate_must_share_an_instant(self):
        p = make()
        p.reserve("a1", 4, 0, 5)
        p.reserve("a1", 4, 5, 9, priority=5, preempt=True)
        self.assertEqual(p.status(1), "active")

    def test_preempts_in_sibling_for_parent_quota(self):
        p = make()
        p.reserve("a2", 4, 0, 5)
        p.reserve("a1", 3, 0, 5, priority=1, preempt=True)
        self.assertEqual((p.status(1), p.status(2)), ("preempted", "active"))

    def test_preempts_across_root(self):
        p = make()
        p.reserve("a", 6, 0, 5)
        p.reserve("b", 6, 0, 5, priority=1, preempt=True)
        self.assertEqual((p.status(1), p.usage("root", 0)), ("preempted", 6))

    def test_not_enough_victims_changes_nothing(self):
        p = make()
        p.reserve("a1", 2, 0, 5)
        p.reserve("a1", 2, 0, 5, priority=7)
        before = p.events()
        with self.assertRaises(NoCapacity) as c:
            p.reserve("a1", 3, 0, 5, priority=5, preempt=True)
        self.assertEqual((c.exception.node, c.exception.at), ("a1", 0))
        self.assertEqual(p.events(), before)
        self.assertEqual((p.status(1), p.usage("a1", 0)), ("active", 4))
        self.assertEqual(p.reserve("a2", 1, 0, 5), 3)

    def test_not_enough_victims_then_waits(self):
        p = make()
        p.reserve("a1", 2, 0, 5)
        p.reserve("a1", 2, 0, 5, priority=7)
        self.assertEqual(p.reserve("a1", 3, 0, 5, priority=5, preempt=True, wait=True), 3)
        self.assertEqual([p.status(i) for i in (1, 2, 3)], ["active", "active", "waiting"])
        self.assertEqual(p.events()[2:], [("waiting", 3)])

    def test_victim_with_wait_rejoins_the_waitlist(self):
        p = make()
        p.reserve("a1", 4, 0, 5, wait=True)
        p.reserve("a1", 4, 0, 5, priority=1, preempt=True)
        self.assertEqual((p.status(1), p.waiting()), ("waiting", [1]))
        self.assertEqual(p.events(), [("active", 1), ("preempted", 1), ("waiting", 1), ("active", 2)])
        p.cancel(2)
        self.assertEqual(p.status(1), "active")
        self.assertEqual(p.events()[-2:], [("cancelled", 2), ("promoted", 1)])

    def test_settle_runs_after_preemption(self):
        p = make()
        p.reserve("a1", 4, 0, 10)                 # 1: will be preempted
        p.reserve("a1", 4, 5, 8, wait=True)       # 2: waits
        p.reserve("a1", 4, 0, 2, priority=5, preempt=True)  # 3
        self.assertEqual([p.status(i) for i in (1, 2, 3)], ["preempted", "active", "active"])
        self.assertEqual(p.events()[2:], [("preempted", 1), ("active", 3), ("promoted", 2)])

    def test_needless_victim_is_promoted_back(self):
        p = make()
        p.reserve("a1", 2, 4, 6, priority=9)            # 1: keeps [4,6) at 2
        p.reserve("a1", 2, 0, 6, priority=1)            # 2: covers both violations
        p.reserve("a1", 2, 0, 2, priority=0, wait=True)  # 3: first in victim order
        p.reserve("a1", 2, 0, 6, priority=5, preempt=True)  # 4
        self.assertEqual([p.status(i) for i in (1, 2, 3, 4)], ["active", "preempted", "active", "active"])
        self.assertEqual(
            p.events()[3:],
            [("preempted", 3), ("waiting", 3), ("preempted", 2), ("active", 4), ("promoted", 3)],
        )

    def test_waiting_reservations_are_not_candidates(self):
        p = make()
        p.reserve("a1", 4, 0, 5, priority=8)
        p.reserve("a1", 4, 0, 5, wait=True)
        with self.assertRaises(NoCapacity):
            p.reserve("a1", 1, 0, 5, priority=5, preempt=True)
        self.assertEqual(p.status(2), "waiting")


class Quota(unittest.TestCase):
    def test_unknown_node(self):
        with self.assertRaises(KeyError):
            make().set_quota("zz", 1)

    def test_bad_quota(self):
        p = make()
        for q in (-1, True, 1.5, "3"):
            with self.assertRaises(ValueError):
                p.set_quota("a1", q)
        self.assertEqual(p.events(), [])

    def test_unknown_node_wins(self):
        with self.assertRaises(KeyError):
            make().set_quota("zz", -1)

    def test_event(self):
        p = make()
        p.set_quota("a1", 2)
        self.assertEqual(p.events(), [("quota", "a1", 4, 2)])
        with self.assertRaises(NoCapacity):
            p.reserve("a1", 3, 0, 1)

    def test_same_value_is_silent(self):
        p = make()
        p.set_quota("a1", 4)
        p.set_quota("a1", 4, evict=True)
        self.assertEqual(p.events(), [])

    def test_lower_to_usage_is_fine(self):
        p = make()
        p.reserve("a1", 3, 0, 5)
        p.set_quota("a1", 3)
        self.assertEqual(p.status(1), "active")

    def test_lower_below_usage_raises(self):
        p = make()
        p.reserve("a1", 3, 0, 5)
        with self.assertRaises(ValueError):
            p.set_quota("a1", 2)
        self.assertEqual(p.events(), [("active", 1)])
        self.assertEqual(p.reserve("a1", 1, 0, 5), 2)

    def test_evict_flag_unused_when_it_fits(self):
        p = make()
        p.reserve("a1", 3, 0, 5)
        p.set_quota("a1", 3, evict=True)
        self.assertEqual(p.events()[1:], [("quota", "a1", 4, 3)])

    def test_evicts_in_victim_order(self):
        p = make()
        p.reserve("a1", 1, 0, 5, priority=1)
        p.reserve("a1", 1, 0, 5)
        p.reserve("a1", 1, 2, 5)
        p.reserve("a1", 1, 2, 5)
        p.set_quota("a1", 1, evict=True)
        self.assertEqual([p.status(i) for i in (1, 2, 3, 4)], ["active", "evicted", "evicted", "evicted"])
        self.assertEqual(p.events()[4:], [("quota", "a1", 4, 1), ("evicted", 4), ("evicted", 3), ("evicted", 2)])

    def test_evict_stops_when_under(self):
        p = make()
        p.reserve("a1", 2, 0, 5)
        p.reserve("a1", 2, 0, 5)
        p.set_quota("a1", 3, evict=True)
        self.assertEqual((p.status(1), p.status(2)), ("active", "evicted"))

    def test_evict_skips_instants_without_excess(self):
        p = make()
        p.reserve("a1", 3, 0, 3, priority=1)
        p.reserve("a1", 2, 6, 9)
        p.set_quota("a1", 2, evict=True)
        self.assertEqual((p.status(1), p.status(2)), ("evicted", "active"))

    def test_evict_reaches_the_subtree(self):
        p = make()
        p.reserve("a1", 3, 0, 5)
        p.reserve("a2", 3, 0, 5)
        p.reserve("b", 3, 0, 5)
        p.set_quota("a", 3, evict=True)
        self.assertEqual([p.status(i) for i in (1, 2, 3)], ["active", "evicted", "active"])

    def test_evicted_with_wait_rejoins(self):
        p = make()
        p.reserve("a1", 3, 0, 5, wait=True)
        p.set_quota("a1", 2, evict=True)
        self.assertEqual((p.status(1), p.waiting()), ("waiting", [1]))
        self.assertEqual(p.events()[1:], [("quota", "a1", 4, 2), ("evicted", 1), ("waiting", 1)])
        p.set_quota("a1", 3)
        self.assertEqual(p.events()[-2:], [("quota", "a1", 2, 3), ("promoted", 1)])

    def test_raise_promotes(self):
        p = make()
        p.reserve("a1", 4, 0, 5)
        p.reserve("a1", 2, 0, 5, wait=True)
        p.set_quota("a1", 5)
        self.assertEqual(p.status(2), "waiting")
        p.set_quota("a1", 6)
        self.assertEqual(p.status(2), "active")

    def test_eviction_settles_other_branch(self):
        p = make()
        p.reserve("a1", 4, 0, 5)
        p.reserve("a2", 2, 0, 5)
        p.reserve("b", 5, 0, 5, wait=True)    # root would be at 11
        p.set_quota("a1", 3, evict=True)
        self.assertEqual([p.status(i) for i in (1, 2, 3)], ["evicted", "active", "active"])
        self.assertEqual(p.events()[3:], [("quota", "a1", 4, 3), ("evicted", 1), ("promoted", 3)])

    def test_needless_eviction_is_promoted_back(self):
        p = make()
        p.reserve("a1", 2, 4, 6, priority=9)             # 1
        p.reserve("a1", 2, 0, 6, priority=1)             # 2
        p.reserve("a1", 1, 0, 2, priority=0, wait=True)  # 3
        p.set_quota("a1", 2, evict=True)
        self.assertEqual([p.status(i) for i in (1, 2, 3)], ["active", "evicted", "active"])
        self.assertEqual(
            p.events()[3:],
            [("quota", "a1", 4, 2), ("evicted", 3), ("waiting", 3), ("evicted", 2), ("promoted", 3)],
        )

    def test_quota_zero_evicts_all(self):
        p = make()
        p.reserve("a1", 1, 0, 5)
        p.reserve("a1", 1, 7, 9)
        p.set_quota("a1", 0, evict=True)
        self.assertEqual(p.timeline("a1"), [])


class Keys(unittest.TestCase):
    def test_replay_returns_same_id(self):
        p = make()
        self.assertEqual(p.reserve("a1", 2, 0, 5, key="k"), 1)
        self.assertEqual(p.reserve("a1", 2, 0, 5, key="k"), 1)
        self.assertEqual(p.events(), [("active", 1)])
        self.assertEqual(p.usage("a1", 0), 2)
        self.assertEqual(p.reserve("a1", 2, 0, 5), 2)

    def test_other_request_raises(self):
        p = make()
        p.reserve("a1", 2, 0, 5, key="k")
        for args, kw in ((("a1", 3, 0, 5), {}), (("a2", 2, 0, 5), {}), (("a1", 2, 0, 6), {}), (("a1", 2, 0, 5), {"priority": 1})):
            with self.assertRaises(ValueError):
                p.reserve(*args, key="k", **kw)

    def test_flags_belong_to_the_request(self):
        p = make()
        p.reserve("a1", 2, 0, 5, key="k")
        with self.assertRaises(ValueError):
            p.reserve("a1", 2, 0, 5, key="k", wait=True)
        with self.assertRaises(ValueError):
            p.reserve("a1", 2, 0, 5, key="k", preempt=True)

    def test_no_capacity_claims_nothing(self):
        p = make()
        with self.assertRaises(NoCapacity):
            p.reserve("a1", 5, 0, 5, key="k")
        self.assertEqual(p.reserve("a1", 1, 0, 5, key="k"), 1)

    def test_invalid_call_claims_nothing(self):
        p = make()
        with self.assertRaises(ValueError):
            p.reserve("a1", 0, 0, 5, key="k")
        self.assertEqual(p.reserve("a1", 1, 0, 5, key="k"), 1)

    def test_replay_after_cancel(self):
        p = make()
        p.reserve("a1", 2, 0, 5, key="k")
        p.cancel(1)
        self.assertEqual(p.reserve("a1", 2, 0, 5, key="k"), 1)
        self.assertEqual((p.status(1), p.usage("a1", 0)), ("cancelled", 0))

    def test_waiting_claims_key(self):
        p = make()
        p.reserve("a1", 4, 0, 5)
        self.assertEqual(p.reserve("a1", 1, 0, 5, key="k", wait=True), 2)
        self.assertEqual(p.reserve("a1", 1, 0, 5, key="k", wait=True), 2)
        self.assertEqual(p.waiting(), [2])
        self.assertEqual(len(p.events()), 2)

    def test_replay_of_full_pool_does_not_raise(self):
        p = make()
        p.reserve("a1", 4, 0, 5, key="k")
        self.assertEqual(p.reserve("a1", 4, 0, 5, key="k"), 1)

    def test_replay_of_preempting_call_displaces_nothing(self):
        p = make()
        p.reserve("a1", 4, 0, 5)
        p.reserve("a1", 4, 0, 5, priority=1, preempt=True, key="k")
        p.cancel(2)
        p.reserve("a1", 4, 0, 5)
        self.assertEqual(p.reserve("a1", 4, 0, 5, priority=1, preempt=True, key="k"), 2)
        self.assertEqual((p.status(2), p.status(3)), ("cancelled", "active"))

    def test_invalid_arguments_beat_key_mismatch_kind(self):
        p = make()
        p.reserve("a1", 2, 0, 5, key="k")
        with self.assertRaises(KeyError):
            p.reserve("zz", 2, 0, 5, key="k")


class StatusEvents(unittest.TestCase):
    def test_status_unknown(self):
        p = make()
        for rid in (0, 1, -1):
            with self.assertRaises(KeyError):
                p.status(rid)

    def test_events_is_a_copy(self):
        p = make()
        p.reserve("a1", 1, 0, 5)
        p.events().clear()
        self.assertEqual(p.events(), [("active", 1)])

    def test_events_are_tuples(self):
        p = make()
        p.reserve("a1", 1, 0, 5)
        p.set_quota("b", 1)
        self.assertTrue(all(type(e) is tuple for e in p.events()))



class Helper(unittest.TestCase):
    def same(self, shipped, base):
        here = pathlib.Path(__file__).resolve().parent
        self.assertEqual((here.parent / shipped).read_bytes(), (here / base).read_bytes())

    def test_steps_module_is_unchanged(self):
        self.same("pool/steps.py", "steps.py.base")

    def test_steps_test_is_unchanged(self):
        self.same("tests/test_steps.py", "test_steps.py.base")
