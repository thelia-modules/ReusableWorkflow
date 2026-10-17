# shellcheck shell=bash
# Helpers shared by the module CI scripts. Source this file, do not run it.

# Version declared in Config/module.xml (the version the auto release tags).
module_version() {
    xml_version < "$1/Config/module.xml"
}

# First <version> element of a module.xml read on stdin (the module version, which precedes any other).
xml_version() {
    local version
    version=$(tr -d '\r' | sed -n 's:.*<version>[[:space:]]*\([^<[:space:]]*\)[[:space:]]*</version>.*:\1:p' | head -n 1)
    if [ -z "$version" ]; then
        echo "no <version> in module.xml" >&2
        return 1
    fi
    echo "$version"
}

# Composer package name of the module.
module_package() {
    php -r '$composer = json_decode(file_get_contents($argv[1]), true, 512, JSON_THROW_ON_ERROR); echo $composer["name"] ?? "";' "$1/composer.json"
}

# Module code: the directory Thelia loads it from (extra.installer-name, else the directory name).
module_code() {
    php -r '$composer = json_decode(file_get_contents($argv[1]), true, 512, JSON_THROW_ON_ERROR); echo $composer["extra"]["installer-name"] ?? basename(dirname(realpath($argv[1])));' "$1/composer.json"
}

# Requirements of the module that a host project must add itself, one per line as package:constraint.
# Skips PHP, extensions, the core and the installer, which the host already provides.
module_requirements() {
    php -r '
        $require = json_decode(file_get_contents($argv[1]), true, 512, JSON_THROW_ON_ERROR)["require"] ?? [];
        foreach ($require as $package => $constraint) {
            if ("php" === $package || str_starts_with($package, "ext-") || in_array($package, ["thelia/core", "thelia/installer"], true)) {
                continue;
            }
            echo $package.":".$constraint, PHP_EOL;
        }
    ' "$1/composer.json"
}

# Activates the module and checks the database says so. A module the install already activated is fine.
activate_module() {
    local code=$1 output status
    php bin/console module:refresh
    set +e
    output=$(php bin/console module:activate "$code" 2>&1)
    status=$?
    set -e
    echo "$output"
    if [ "$status" -ne 0 ] && ! grep -q 'already activated' <<< "$output"; then
        echo "::error::module:activate $code failed"
        return 1
    fi
    local active
    active=$(mysql -h"$DATABASE_HOST" -P"$DATABASE_PORT" -u"$DATABASE_USER" -p"$DATABASE_PASSWORD" -N -e "SELECT activate FROM \`$DATABASE_NAME\`.module WHERE code = '$code'")
    echo "$code active in the database: ${active:-missing}"
    if [ "$active" != "1" ]; then
        echo "::error::module $code is not active after module:activate"
        return 1
    fi
}

# Boots the container with the module active, then serves the storefront and the back-office login.
check_shop() {
    local status=0 code path log page
    php bin/console cache:clear
    php bin/console lint:container
    php bin/console cache:warmup
    log="$RUNNER_TEMP/server.log"
    page="$RUNNER_TEMP/page.html"
    php -S 127.0.0.1:8000 -t public > "$log" 2>&1 &
    local server=$!
    for _ in $(seq 1 30); do curl -s -o /dev/null http://127.0.0.1:8000/ && break; sleep 1; done
    for path in / /admin/login; do
        code=$(curl -s -o "$page" -w '%{http_code}' "http://127.0.0.1:8000$path")
        echo "$path -> $code"
        if [ "$code" != "200" ]; then
            echo "::error::GET $path answered $code with the module active"
            head -c 2000 "$page"; echo
            status=1
        fi
    done
    kill "$server" || true
    if grep -E 'PHP (Fatal|Warning|Deprecated)' "$log"; then
        echo "::error::the server logged PHP errors"
        status=1
    fi
    return $status
}
