import unittest
from decimal import Decimal as D

from ledger import Ledger


def make():
    led = Ledger({"USD": 2, "JPY": 0, "BHD": 3})
    for name, cur in (("cash", "USD"), ("sales", "USD"), ("fees", "USD"), ("yen", "JPY"), ("yen2", "JPY"), ("dinar", "BHD"), ("dinar2", "BHD")):
        led.open(name, cur)
    return led


class Setup(unittest.TestCase):
    def test_negative_exponent_raises(self):
        with self.assertRaises(ValueError):
            Ledger({"USD": -1})

    def test_open_unknown_currency_is_keyerror(self):
        with self.assertRaises(KeyError):
            Ledger({"USD": 2}).open("cash", "EUR")

    def test_open_twice_raises(self):
        led = Ledger({"USD": 2})
        led.open("cash", "USD")
        with self.assertRaises(ValueError):
            led.open("cash", "USD")

    def test_new_account_balance_is_quantized_zero(self):
        led = make()
        self.assertEqual(str(led.balance("cash")), "0.00")
        self.assertEqual(str(led.balance("yen")), "0")
        self.assertEqual(str(led.balance("dinar")), "0.000")


class Post(unittest.TestCase):
    def test_ids_count_from_one(self):
        led = make()
        self.assertEqual(led.post([("cash", "5"), ("sales", "-5")], when=10), 1)
        self.assertEqual(led.post([("cash", "1"), ("sales", "-1")], when=10), 2)

    def test_balance_is_quantized(self):
        led = make()
        led.post([("cash", "5"), ("sales", "-5")], when=10)
        self.assertEqual(str(led.balance("cash")), "5.00")
        self.assertEqual(str(led.balance("sales")), "-5.00")

    def test_unbalanced_raises_and_posts_nothing(self):
        led = make()
        with self.assertRaises(ValueError):
            led.post([("cash", "5"), ("sales", "-4.99")], when=10)
        self.assertEqual(led.balances(), {})

    def test_failed_post_consumes_no_id(self):
        led = make()
        with self.assertRaises(ValueError):
            led.post([("cash", "5"), ("sales", "-4")], when=10)
        self.assertEqual(led.post([("cash", "5"), ("sales", "-5")], when=10), 1)

    def test_each_currency_balances_alone(self):
        led = make()
        with self.assertRaises(ValueError):
            led.post([("cash", "5"), ("yen", "-5")], when=10)

    def test_two_currencies_each_balanced(self):
        led = make()
        led.post([("cash", "5"), ("sales", "-5"), ("yen", "700"), ("yen2", "-700")], when=10)
        self.assertEqual(led.balance("yen2"), D("-700"))

    def test_single_entry_raises(self):
        with self.assertRaises(ValueError):
            make().post([("cash", "5")], when=10)

    def test_too_many_decimals_raises(self):
        with self.assertRaises(ValueError):
            make().post([("cash", "5.001"), ("sales", "-5.001")], when=10)

    def test_trailing_zero_beyond_exponent_raises(self):
        with self.assertRaises(ValueError):
            make().post([("cash", "5.000"), ("sales", "-5.000")], when=10)

    def test_jpy_takes_no_decimals(self):
        with self.assertRaises(ValueError):
            make().post([("yen", "5.0"), ("yen2", "-5.0")], when=10)

    def test_three_decimals_for_bhd(self):
        led = make()
        led.post([("dinar", "1.005"), ("dinar2", "-1.005")], when=10)
        self.assertEqual(str(led.balance("dinar")), "1.005")

    def test_exponent_form_raises(self):
        with self.assertRaises(ValueError):
            make().post([("cash", "1e2"), ("sales", "-1e2")], when=10)

    def test_plus_sign_raises(self):
        with self.assertRaises(ValueError):
            make().post([("cash", "+5"), ("sales", "-5")], when=10)

    def test_zero_entry_raises(self):
        with self.assertRaises(ValueError):
            make().post([("cash", "5"), ("sales", "-5"), ("fees", "0")], when=10)

    def test_number_amount_raises(self):
        with self.assertRaises(ValueError):
            make().post([("cash", 5), ("sales", -5)], when=10)

    def test_unknown_account_is_keyerror_and_posts_nothing(self):
        led = make()
        with self.assertRaises(KeyError):
            led.post([("cash", "5"), ("nope", "-5")], when=10)
        self.assertEqual(led.balances(), {})

    def test_same_account_twice_nets(self):
        led = make()
        led.post([("cash", "5"), ("cash", "2"), ("sales", "-7")], when=10)
        self.assertEqual(led.balance("cash"), D("7"))
        self.assertEqual(len(led.statement("cash", 0, 100)), 1)


class Keys(unittest.TestCase):
    def test_replay_returns_original_and_posts_nothing(self):
        led = make()
        a = led.post([("cash", "5"), ("sales", "-5")], when=10, key="k")
        b = led.post([("cash", "5"), ("sales", "-5")], when=10, key="k")
        self.assertEqual(a, b)
        self.assertEqual(led.balance("cash"), D("5"))

    def test_replay_ignores_order_and_spelling(self):
        led = make()
        a = led.post([("cash", "5.0"), ("sales", "-5")], when=10, key="k")
        b = led.post([("sales", "-5.00"), ("cash", "5")], when=10, key="k")
        self.assertEqual(a, b)

    def test_key_with_other_amount_raises(self):
        led = make()
        led.post([("cash", "5"), ("sales", "-5")], when=10, key="k")
        with self.assertRaises(ValueError):
            led.post([("cash", "6"), ("sales", "-6")], when=10, key="k")

    def test_key_with_other_when_raises(self):
        led = make()
        led.post([("cash", "5"), ("sales", "-5")], when=10, key="k")
        with self.assertRaises(ValueError):
            led.post([("cash", "5"), ("sales", "-5")], when=11, key="k")

    def test_split_entries_are_a_different_request(self):
        led = make()
        led.post([("cash", "5"), ("sales", "-5")], when=10, key="k")
        with self.assertRaises(ValueError):
            led.post([("cash", "2"), ("cash", "3"), ("sales", "-5")], when=10, key="k")

    def test_failed_post_does_not_claim_key(self):
        led = make()
        with self.assertRaises(ValueError):
            led.post([("cash", "5"), ("sales", "-4")], when=10, key="k")
        self.assertEqual(led.post([("cash", "5"), ("sales", "-5")], when=10, key="k"), 1)

    def test_replay_does_not_consume_id(self):
        led = make()
        led.post([("cash", "5"), ("sales", "-5")], when=10, key="k")
        led.post([("cash", "5"), ("sales", "-5")], when=10, key="k")
        self.assertEqual(led.post([("cash", "1"), ("sales", "-1")], when=10), 2)

    def test_replay_after_close_still_answers(self):
        led = make()
        a = led.post([("cash", "5"), ("sales", "-5")], when=10, key="k")
        led.post([("cash", "-5"), ("sales", "5")], when=11)
        led.close("cash")
        self.assertEqual(led.post([("cash", "5"), ("sales", "-5")], when=10, key="k"), a)

    def test_post_and_reverse_share_the_key_space(self):
        led = make()
        a = led.post([("cash", "5"), ("sales", "-5")], when=10, key="k")
        with self.assertRaises(ValueError):
            led.reverse(a, when=12, key="k")


class Time(unittest.TestCase):
    def test_balance_at_includes_the_instant(self):
        led = make()
        led.post([("cash", "5"), ("sales", "-5")], when=10)
        self.assertEqual(led.balance("cash", at=9), D("0"))
        self.assertEqual(led.balance("cash", at=10), D("5"))

    def test_late_arrival_counts_at_its_own_time(self):
        led = make()
        led.post([("cash", "5"), ("sales", "-5")], when=20)
        led.post([("cash", "1"), ("sales", "-1")], when=10)
        self.assertEqual(led.balance("cash", at=15), D("1"))

    def test_statement_orders_by_when_then_id(self):
        led = make()
        led.post([("cash", "5"), ("sales", "-5")], when=20)
        led.post([("cash", "1"), ("sales", "-1")], when=10)
        led.post([("cash", "2"), ("sales", "-2")], when=20)
        self.assertEqual(
            led.statement("cash", 0, 100),
            [(10, 2, D("1"), D("1")), (20, 1, D("5"), D("6")), (20, 3, D("2"), D("8"))],
        )

    def test_statement_window_is_half_open(self):
        led = make()
        led.post([("cash", "5"), ("sales", "-5")], when=10)
        led.post([("cash", "1"), ("sales", "-1")], when=20)
        self.assertEqual([r[0] for r in led.statement("cash", 10, 20)], [10])

    def test_statement_running_balance_carries_history(self):
        led = make()
        led.post([("cash", "5"), ("sales", "-5")], when=10)
        led.post([("cash", "1"), ("sales", "-1")], when=20)
        self.assertEqual(led.statement("cash", 15, 30), [(20, 2, D("1"), D("6"))])

    def test_statement_skips_zero_net_lines(self):
        led = make()
        led.post([("cash", "5"), ("cash", "-5"), ("fees", "1"), ("sales", "-1")], when=10)
        self.assertEqual(led.statement("cash", 0, 100), [])

    def test_statement_reversed_window_raises(self):
        with self.assertRaises(ValueError):
            make().statement("cash", 5, 4)

    def test_balances_lists_nonzero_sorted(self):
        led = make()
        led.post([("sales", "-5"), ("cash", "5")], when=10)
        led.post([("fees", "1"), ("fees", "-1"), ("yen", "3"), ("yen2", "-3")], when=10)
        self.assertEqual(list(led.balances().items()), [("cash", D("5")), ("sales", D("-5")), ("yen", D("3")), ("yen2", D("-3"))])

    def test_balances_at(self):
        led = make()
        led.post([("cash", "5"), ("sales", "-5")], when=10)
        self.assertEqual(led.balances(at=9), {})


class Reverse(unittest.TestCase):
    def test_reverse_negates(self):
        led = make()
        a = led.post([("cash", "5"), ("sales", "-5")], when=10)
        b = led.reverse(a, when=12)
        self.assertEqual(b, 2)
        self.assertEqual(led.balances(), {})
        self.assertEqual(led.balance("cash", at=11), D("5"))

    def test_reverse_twice_raises(self):
        led = make()
        a = led.post([("cash", "5"), ("sales", "-5")], when=10)
        led.reverse(a, when=12)
        with self.assertRaises(ValueError):
            led.reverse(a, when=13)

    def test_reversal_cannot_be_reversed(self):
        led = make()
        a = led.post([("cash", "5"), ("sales", "-5")], when=10)
        b = led.reverse(a, when=12)
        with self.assertRaises(ValueError):
            led.reverse(b, when=13)

    def test_reverse_before_original_raises(self):
        led = make()
        a = led.post([("cash", "5"), ("sales", "-5")], when=10)
        with self.assertRaises(ValueError):
            led.reverse(a, when=9)

    def test_reverse_at_same_instant_allowed(self):
        led = make()
        a = led.post([("cash", "5"), ("sales", "-5")], when=10)
        led.reverse(a, when=10)
        self.assertEqual(led.balance("cash", at=10), D("0"))

    def test_reverse_unknown_is_keyerror(self):
        with self.assertRaises(KeyError):
            make().reverse(7, when=10)

    def test_reverse_replay_returns_same_id(self):
        led = make()
        a = led.post([("cash", "5"), ("sales", "-5")], when=10)
        b = led.reverse(a, when=12, key="r")
        self.assertEqual(led.reverse(a, when=12, key="r"), b)
        self.assertEqual(led.balances(), {})

    def test_failed_reverse_leaves_original_reversible(self):
        led = make()
        a = led.post([("cash", "5"), ("sales", "-5")], when=10)
        with self.assertRaises(ValueError):
            led.reverse(a, when=9)
        led.reverse(a, when=10)
        self.assertEqual(led.balances(), {})


class Close(unittest.TestCase):
    def test_close_with_balance_raises(self):
        led = make()
        led.post([("cash", "5"), ("sales", "-5")], when=10)
        with self.assertRaises(ValueError):
            led.close("cash")

    def test_post_to_closed_raises_and_posts_nothing(self):
        led = make()
        led.close("fees")
        with self.assertRaises(ValueError):
            led.post([("fees", "5"), ("sales", "-5")], when=10)
        self.assertEqual(led.balances(), {})

    def test_reverse_touching_closed_raises(self):
        led = make()
        a = led.post([("cash", "5"), ("sales", "-5")], when=10)
        led.post([("cash", "-5"), ("fees", "5")], when=11)
        led.close("cash")
        with self.assertRaises(ValueError):
            led.reverse(a, when=12)

    def test_closed_account_keeps_history(self):
        led = make()
        led.post([("cash", "5"), ("sales", "-5")], when=10)
        led.post([("cash", "-5"), ("sales", "5")], when=11)
        led.close("cash")
        self.assertEqual(led.balance("cash", at=10), D("5"))
        self.assertEqual(len(led.statement("cash", 0, 100)), 2)

    def test_close_twice_raises(self):
        led = make()
        led.close("fees")
        with self.assertRaises(ValueError):
            led.close("fees")

    def test_close_unknown_is_keyerror(self):
        with self.assertRaises(KeyError):
            make().close("nope")


class Unknown(unittest.TestCase):
    def test_balance_unknown_is_keyerror(self):
        with self.assertRaises(KeyError):
            make().balance("nope")

    def test_statement_unknown_is_keyerror(self):
        with self.assertRaises(KeyError):
            make().statement("nope", 0, 10)

    def test_unknown_account_wins_over_invalid_amount(self):
        with self.assertRaises(KeyError):
            make().post([("cash", "5.001"), ("nope", "-5.001")], when=10)

    def test_unknown_account_wins_over_single_entry(self):
        with self.assertRaises(KeyError):
            make().post([("nope", "5")], when=10)
