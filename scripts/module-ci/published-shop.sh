#!/usr/bin/env bash
# Builds a shop the way a new user does (composer create-project thelia/thelia-project, the
# latest published core and modules), with the module under test replacing its published copy,
# installs it and activates the module.
# Usage: published-shop.sh <module-dir> <shop-dir>
set -euo pipefail
module_dir=$(realpath "$1")
shop_dir=$2
# shellcheck source=lib.sh
source "$(dirname "$0")/lib.sh"

package=$(module_package "$module_dir")
version=$(module_version "$module_dir")
code=$(module_code "$module_dir")
echo "module $code, package $package, version $version"

composer create-project thelia/thelia-project "$shop_dir" --no-progress
cd "$shop_dir"

# The checkout comes first among the repositories, under the version of its module.xml: Composer
# takes it over the Packagist release of the same version and resolves its composer.json against
# the published core, as a real install of that version would.
php -r '
    [, $url, $package, $version] = $argv;
    $composer = json_decode(file_get_contents("composer.json"), true, 512, JSON_THROW_ON_ERROR);
    $repositories = array_values($composer["repositories"] ?? []);
    array_unshift($repositories, ["type" => "path", "url" => $url, "options" => ["symlink" => false, "versions" => [$package => $version]]]);
    $composer["repositories"] = $repositories;
    file_put_contents("composer.json", json_encode($composer, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES | JSON_THROW_ON_ERROR).PHP_EOL);
' "$module_dir" "$package" "$version"

composer require "$package:$version" --with-all-dependencies --no-progress
composer show 'thelia/*'

installed="vendor/thelia/modules/$code"
if ! cmp -s "$module_dir/Config/module.xml" "$installed/Config/module.xml"; then
    echo "::error::$installed is not the checkout under test"
    exit 1
fi

php bin/install \
    --frontoffice_theme=flexy --backoffice_theme=default-twig \
    --pdf_theme=default --email_theme=default \
    --with-demo --with-admin \
    --admin_login=thelia --admin_password=thelia \
    --admin_first_name=Admin --admin_last_name=User \
    --admin_email=admin@example.com

activate_module "$code"
