class PackageNotFound(Exception):
    pass

class NoMatchingVersionFound(Exception):
    pass

class IntegrityError(Exception):
    pass

class NixBuildError(Exception):
    pass