def all_equal(iterable):
    it = iter(iterable)
    try:
        ref = next(it)
        while True:
            other = next(it)
            if ref != other:
                return False
    except StopIteration:
        return True
