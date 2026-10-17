#!/usr/bin/env bash
# PHPStan level 0 on the module, against the classes of the shop it sits in (the published core
# for module_ci.yml). Level 0 reports unknown classes, functions and methods: a module calling a
# core class that is not released yet fails here. No database and no install needed: the shop
# only needs its packages, so the analysis runs even when the module breaks the install.
# Usage: phpstan.sh <shop-dir> <module-code>   (phpstan on the PATH)
set -euo pipefail
shop_dir=$(realpath "$1")
code=$2
module="$shop_dir/vendor/thelia/modules/$code"
cd "$shop_dir"

bootstrap="$RUNNER_TEMP/phpstan-bootstrap.php"
# The Base and Map classes the Propel models extend are generated, normally at the first boot.
# Generated here from the schemas of the core and of every module on disk, without a database,
# the way the PHPStan bootstrap of thelia/thelia does.
cat > "$bootstrap" <<'PHP'
<?php
$root = getcwd().DIRECTORY_SEPARATOR;
if (!defined('THELIA_ROOT')) {
    define('THELIA_ROOT', $root);
}
$loader = require $root.'vendor/autoload.php';
$models = $root.'var/propel/test/model';
if (!is_dir($models.'/Thelia/Model/Base')) {
    $propel = new Thelia\Core\Propel\PropelInitService(
        'test',
        false,
        [
            'thelia.database_host' => '',
            'thelia.database_port' => '3306',
            'thelia.database_name' => '',
            'thelia.database_user' => '',
            'thelia.database_password' => '',
        ],
        new Thelia\Core\Propel\Schema\SchemaLocator(THELIA_CONF_DIR, THELIA_MODULE_DIR, THELIA_LOCAL_MODULE_DIR),
    );
    $propel->buildPropelConfig();
    $propel->buildPropelInitFile();
    $propel->buildPropelGlobalSchema();
    $propel->buildPropelModels();
}
$loader->addPsr4('', $models);
$loader->addPsr4('TheliaMain\\', $root.'var/propel/test/database/TheliaMain');
PHP
# Once before the analysis: the parallel workers of PHPStan then find the models in place.
php "$bootstrap"
ls "var/propel/test/model/Thelia/Model/Base" > /dev/null

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
