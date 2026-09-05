import unittest
from decimal import Decimal

from tools.exness_tick_history.archive import ArchiveKey, SourceError
from tools.exness_tick_history.sanitize import exact_price, iso_milliseconds, parse_row, quote_line, utc_milliseconds


class SanitizeTests(unittest.TestCase):
    def test_integer_utc_and_millisecond_precision(self):
        for text in ("1970-01-01 00:00:00.000Z", "2024-02-29 23:59:59.999Z", "2026-03-08 02:00:00.001Z"):
            self.assertEqual(iso_milliseconds(utc_milliseconds(text)).replace("T", " "), text)
        self.assertEqual(utc_milliseconds("1970-01-01 00:00:01.001Z"), 1001)
        for text in ("2026-02-29 00:00:00.001Z", "2026-09-01 00:00:00.0001Z", "2026-09-01 00:00:00.001"):
            with self.assertRaises(SourceError):
                utc_milliseconds(text)

    def test_exact_decimal_registry_rejects_loss(self):
        for value in ("1.1234567890123", "100000000000000000000000000", "NaN", "inf", "-1", "1e3", "0"):
            with self.subTest(value=value), self.assertRaises(SourceError):
                exact_price(value)
        large = "99999999999999999999999999.123456789012"
        self.assertEqual(str(exact_price(large)), large)
        self.assertEqual(quote_line(1, Decimal("10.000"), Decimal("10.010")), b"1\t10\t10.01\n")

    def test_vendor_symbol_quote_and_interval(self):
        row = ["exness", "XAUUSD", "2026-09-01 00:00:00.001Z", "1", "1"]
        key = ArchiveKey("XAUUSD", 2026, 9, 1)
        self.assertEqual(parse_row(row, key)[1:], (Decimal(1), Decimal(1)))
        for index, value in ((0, "other"), (1, "XAUUSDm"), (2, "2026-08-31 23:59:59.999Z"), (4, "0.9")):
            changed = row.copy()
            changed[index] = value
            with self.assertRaises(SourceError):
                parse_row(changed, key)
