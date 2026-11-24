import unittest


class ImportTest(unittest.TestCase):
    def test_package_imports(self):
        import ratelimit

        self.assertTrue(hasattr(ratelimit, "TokenBucket"))
