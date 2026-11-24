import unittest


class ImportTest(unittest.TestCase):
    def test_package_imports(self):
        import intervals

        self.assertTrue(hasattr(intervals, "IntervalSet"))
