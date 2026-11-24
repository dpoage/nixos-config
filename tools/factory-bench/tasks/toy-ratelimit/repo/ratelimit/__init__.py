"""Token-bucket rate limiter. Not implemented yet."""


class TokenBucket:
    def __init__(self, rate, burst, clock=None):
        raise NotImplementedError


def from_env(environ=None, clock=None):
    raise NotImplementedError
