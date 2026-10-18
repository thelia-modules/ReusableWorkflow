#!/usr/bin/env bash
# Runs the tests of the module inside a prepared checkout of thelia/thelia, from its root: the
# module test bootstraps expect that place (../../../vendor/autoload.php, getcwd()).
# The module's own phpunit configuration wins; without one, the Thelia configuration runs the
# module test directory, with the module bootstrap when it has one.
# Usage: phpunit.sh <thelia-checkout> <module-code>
set -euo pipefail
cd "$1"
code=$2
module="local/modules/$code"

# Module test bootstraps written for a Thelia project require <project root>/bootstrap.php, which
# thelia/thelia does not have: there the Composer autoload loads core/bootstrap.php, which defines
# the same constants. An empty stand-in lets those bootstraps run unchanged.
if [ ! -e bootstrap.php ]; then
    printf '<?php\n\n// Stand-in for the bootstrap.php of a Thelia project: core/bootstrap.php, loaded by the autoload, defines the constants.\n' > bootstrap.php
fi

configs=()
for file in phpunit.xml.dist phpunit.xml phpunit.integration.xml.dist; do
    [ -f "$module/$file" ] && configs+=("$module/$file")
done

status=0
if [ ${#configs[@]} -gt 0 ]; then
    for config in "${configs[@]}"; do
        echo "::group::phpunit -c $config"
        vendor/bin/phpunit -c "$config" || status=1
        echo "::endgroup::"
    done
    exit $status
fi

for directory in Tests tests; do
    [ -d "$module/$directory" ] || continue
    bootstrap=()
    [ -f "$module/$directory/bootstrap.php" ] && bootstrap=(--bootstrap "$module/$directory/bootstrap.php")
    echo "::group::phpunit $module/$directory"
    vendor/bin/phpunit -c phpunit.xml.dist "${bootstrap[@]}" "$module/$directory" || status=1
    echo "::endgroup::"
done
exit $status
