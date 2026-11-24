import unittest


class ImportTest(unittest.TestCase):
    def test_package_imports(self):
        import ledger

        self.assertTrue(hasattr(ledger, "Ledger"))
