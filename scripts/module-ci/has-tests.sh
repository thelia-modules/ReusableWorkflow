#!/usr/bin/env bash
# Prints true when the module has PHPUnit tests (a *Test.php file outside vendor), else false.
# Usage: has-tests.sh <module-dir>
set -euo pipefail
if find "$1" -path "$1/vendor" -prune -o -name '*Test.php' -print -quit | grep -q .; then
    echo true
else
    echo false
fi
