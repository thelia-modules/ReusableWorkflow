#!/usr/bin/env bash
# Puts the module under test into a checkout of thelia/thelia (the development tip of Thelia),
# in local/modules, with the themes on their development branch and the module's own
# requirements, then installs the dependencies.
# Usage: main-shop.sh <module-dir> <thelia-checkout>
set -euo pipefail
module_dir=$(realpath "$1")
thelia_dir=$2
# shellcheck source=lib.sh
source "$(dirname "$0")/lib.sh"

package=$(module_package "$module_dir")
code=$(module_code "$module_dir")
cd "$thelia_dir"

mkdir -p local/modules
cp -a "$module_dir" "local/modules/$code"
rm -rf "local/modules/$code/.git"

# thelia/thelia may require the module itself: the copy under test is the one in local/modules,
# a second one from Packagist in vendor would load the module twice.
php -r '
    $package = $argv[1];
    $composer = json_decode(file_get_contents("composer.json"), false, 512, JSON_THROW_ON_ERROR);
    foreach (["require", "require-dev"] as $section) {
        if (isset($composer->{$section}->{$package})) {
            unset($composer->{$section}->{$package});
            echo "$package removed from $section of thelia/thelia", PHP_EOL;
        }
    }
    file_put_contents("composer.json", json_encode($composer, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE | JSON_THROW_ON_ERROR).PHP_EOL);
' "$package"

mapfile -t deps < <(module_requirements "$module_dir")
printf 'module requirement: %s\n' "${deps[@]}"
composer require --no-update --no-scripts --no-audit \
    "thelia/flexy:dev-main as 1.99.0" \
    "thelia/backoffice-default-twig-template:dev-main as 1.99.0" \
    "thelia/email-default-template:dev-main as 1.99.0" \
    "thelia/pdf-default-template:dev-main as 1.99.0" \
    "${deps[@]}"
composer update --no-progress --prefer-dist --optimize-autoloader
