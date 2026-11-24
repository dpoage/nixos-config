import math
import os
import unittest
from unittest import mock

from ratelimit import TokenBucket, from_env


class Clock:
    def __init__(self, t=100.0):
        self.t = t

    def __call__(self):
        return self.t


class Start(unittest.TestCase):
    def test_starts_full(self):
        self.assertEqual(TokenBucket(2, 4, Clock()).available(), 4)

    def test_never_exceeds_burst(self):
        c = Clock()
        b = TokenBucket(2, 4, c)
        c.t += 1000
        self.assertEqual(b.available(), 4)

    def test_clamp_then_spend_does_not_bank_excess(self):
        c = Clock()
        b = TokenBucket(2, 4, c)
        c.t += 1000
        self.assertTrue(b.try_acquire(4))
        self.assertFalse(b.try_acquire(1))


class Acquire(unittest.TestCase):
    def test_exactly_available_succeeds(self):
        b = TokenBucket(1, 4, Clock())
        self.assertTrue(b.try_acquire(4))
        self.assertEqual(b.available(), 0)

    def test_failure_consumes_nothing(self):
        b = TokenBucket(1, 4, Clock())
        self.assertTrue(b.try_acquire(3))
        self.assertFalse(b.try_acquire(2))
        self.assertEqual(b.available(), 1)
        self.assertTrue(b.try_acquire(1))

    def test_refill_is_elapsed_times_rate(self):
        c = Clock()
        b = TokenBucket(2, 8, c)
        self.assertTrue(b.try_acquire(8))
        c.t += 1.5
        self.assertEqual(b.available(), 3)

    def test_partial_tokens_accumulate_across_calls(self):
        c = Clock()
        b = TokenBucket(1, 4, c)
        self.assertTrue(b.try_acquire(4))
        for _ in range(4):
            c.t += 0.25
            b.available()
        self.assertTrue(b.try_acquire(1))

    def test_fractional_shortfall_fails(self):
        c = Clock()
        b = TokenBucket(1, 4, c)
        b.try_acquire(4)
        c.t += 0.75
        self.assertFalse(b.try_acquire(1))

    def test_n_over_burst_raises(self):
        with self.assertRaises(ValueError):
            TokenBucket(1, 4, Clock()).try_acquire(5)

    def test_n_zero_raises(self):
        with self.assertRaises(ValueError):
            TokenBucket(1, 4, Clock()).try_acquire(0)

    def test_n_negative_raises_and_adds_nothing(self):
        b = TokenBucket(1, 4, Clock())
        b.try_acquire(4)
        with self.assertRaises(ValueError):
            b.try_acquire(-2)
        self.assertEqual(b.available(), 0)


class BackwardsClock(unittest.TestCase):
    def test_backwards_adds_nothing(self):
        c = Clock()
        b = TokenBucket(1, 4, c)
        b.try_acquire(4)
        c.t -= 50
        self.assertEqual(b.available(), 0)

    def test_backwards_does_not_move_last_reading(self):
        c = Clock(100.0)
        b = TokenBucket(1, 4, c)
        b.try_acquire(4)
        c.t = 90.0
        b.available()
        c.t = 101.0
        self.assertEqual(b.available(), 1)


class WaitTime(unittest.TestCase):
    def test_zero_when_enough(self):
        self.assertEqual(TokenBucket(1, 4, Clock()).wait_time(4), 0.0)

    def test_shortfall_over_rate(self):
        c = Clock()
        b = TokenBucket(2, 4, c)
        b.try_acquire(4)
        c.t += 0.5
        self.assertEqual(b.wait_time(3), 1.0)

    def test_does_not_consume(self):
        b = TokenBucket(2, 4, Clock())
        b.wait_time(2)
        self.assertEqual(b.available(), 4)

    def test_zero_rate_is_inf_when_short(self):
        b = TokenBucket(0, 2, Clock())
        b.try_acquire(2)
        self.assertEqual(b.wait_time(1), math.inf)

    def test_zero_rate_is_zero_when_enough(self):
        self.assertEqual(TokenBucket(0, 2, Clock()).wait_time(2), 0.0)

    def test_n_over_burst_raises(self):
        with self.assertRaises(ValueError):
            TokenBucket(1, 4, Clock()).wait_time(5)


class Construct(unittest.TestCase):
    def test_negative_rate_raises(self):
        with self.assertRaises(ValueError):
            TokenBucket(-0.1, 4, Clock())

    def test_zero_rate_allowed(self):
        self.assertTrue(TokenBucket(0, 1, Clock()).try_acquire(1))

    def test_burst_below_one_raises(self):
        with self.assertRaises(ValueError):
            TokenBucket(1, 0, Clock())

    def test_default_clock_is_monotonic(self):
        c = Clock(5.0)
        with mock.patch("time.monotonic", c):
            b = TokenBucket(1, 2)
            b.try_acquire(2)
            c.t = 6.0
            self.assertEqual(b.available(), 1)


class FromEnv(unittest.TestCase):
    def test_unset_uses_defaults(self):
        b = from_env({}, Clock())
        self.assertEqual((b.rate, b.burst), (5.0, 10))

    def test_empty_uses_defaults(self):
        b = from_env({"RL_RATE": "", "RL_BURST": ""}, Clock())
        self.assertEqual((b.rate, b.burst), (5.0, 10))

    def test_values_read(self):
        b = from_env({"RL_RATE": "0.5", "RL_BURST": "3"}, Clock())
        self.assertEqual((b.rate, b.burst), (0.5, 3))

    def test_invalid_rate_names_variable(self):
        with self.assertRaisesRegex(ValueError, "RL_RATE"):
            from_env({"RL_RATE": "fast"}, Clock())

    def test_invalid_burst_names_variable(self):
        with self.assertRaisesRegex(ValueError, "RL_BURST"):
            from_env({"RL_BURST": "2.5"}, Clock())

    def test_out_of_range_burst_names_variable(self):
        with self.assertRaisesRegex(ValueError, "RL_BURST"):
            from_env({"RL_BURST": "0"}, Clock())

    def test_negative_rate_names_variable(self):
        with self.assertRaisesRegex(ValueError, "RL_RATE"):
            from_env({"RL_RATE": "-1"}, Clock())

    def test_none_reads_process_environment(self):
        with mock.patch.dict(os.environ, {"RL_RATE": "7", "RL_BURST": "2"}):
            b = from_env(clock=Clock())
        self.assertEqual((b.rate, b.burst), (7.0, 2))

    def test_process_environment_unset_uses_defaults(self):
        env = {k: v for k, v in os.environ.items() if k not in ("RL_RATE", "RL_BURST")}
        with mock.patch.dict(os.environ, env, clear=True):
            b = from_env(clock=Clock())
        self.assertEqual((b.rate, b.burst), (5.0, 10))
