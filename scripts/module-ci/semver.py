#!/usr/bin/env python3
"""Checks that a version is a semantic version strictly above the greatest reference.

Usage: semver.py <version> <references-file> <label>

<references-file> holds versions or tags, whitespace separated; those that are not semantic
versions are ignored. Exits 1 with a GitHub error annotation when <version> is malformed or is not
strictly greater (semver precedence, build metadata ignored) than the greatest reference.

Same rule as the "semver" step of .github/workflows/auto_release.yml, which carries its own copy
because it does not check this repository out: change both together.
"""
import re
import sys

SEMVER = re.compile(r'^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)(?:-((?:0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*)(?:\.(?:0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*))*))?(?:\+[0-9a-zA-Z-]+(?:\.[0-9a-zA-Z-]+)*)?$')


def key(version):
    major, minor, patch, pre = SEMVER.match(version).groups()
    core = (int(major), int(minor), int(patch))
    if pre is None:
        return core, (1,)
    parts = tuple((0, int(p), '') if p.isdigit() else (1, 0, p) for p in pre.split('.'))
    return core, (0, parts)


def fail(message):
    print(f'::error file=Config/module.xml::{message}')
    sys.exit(1)


version, references_file, label = sys.argv[1:4]
if not SEMVER.match(version):
    fail(f'<version> "{version}" is not a valid semantic version (expected MAJOR.MINOR.PATCH, optionally -prerelease, no leading v): nothing can be tagged')
references = [r for r in open(references_file).read().split() if SEMVER.match(r)]
if references:
    greatest = max(references, key=key)
    print(f'greatest {label}: {greatest}')
    if not key(version) > key(greatest):
        fail(f'<version> {version} is not strictly greater than the {label} {greatest}: merged as is, this change is never released. Take a version above {greatest}')
else:
    print(f'no semantic-version {label} yet')
print(f'version {version} is valid and above every {label}')
