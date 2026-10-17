#!/usr/bin/env bash
# PHPStan level 0 on the module, against the classes of the shop it is installed in (the
# published core for module_ci.yml). Level 0 reports unknown classes, functions and methods:
# a module calling a core class that is not released yet fails here.
# Usage: phpstan.sh <shop-dir> <module-code>   (phpstan on the PATH)
set -euo pipefail
shop_dir=$(realpath "$1")
code=$2
module="$shop_dir/vendor/thelia/modules/$code"
cd "$shop_dir"

bootstrap="$RUNNER_TEMP/phpstan-bootstrap.php"
# The Propel models (Base and Map classes of the core and of every module) are generated under
# var/propel/<environment>/ when the shop is installed; Composer does not know that directory.
cat > "$bootstrap" <<'PHP'
<?php
$root = getcwd();
$loader = require $root.'/vendor/autoload.php';
foreach (glob($root.'/var/propel/*/model', GLOB_ONLYDIR) as $directory) {
    $loader->addPsr4('', $directory);
}
foreach (glob($root.'/var/propel/*/database/TheliaMain', GLOB_ONLYDIR) as $directory) {
    $loader->addPsr4('TheliaMain\\', $directory);
}
PHP

config="$RUNNER_TEMP/phpstan.neon"
cat > "$config" <<NEON
parameters:
    level: 0
    tmpDir: $RUNNER_TEMP/phpstan
    paths:
        - $module
    excludePaths:
        analyseAndScan:
            - $module/Tests (?)
            - $module/tests (?)
            - $module/vendor (?)
            - $module/node_modules (?)
    bootstrapFiles:
        - $bootstrap
NEON

phpstan --version
phpstan analyse --configuration="$config" --no-progress --memory-limit=1G --error-format=github
