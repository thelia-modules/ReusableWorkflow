#!/usr/bin/env bash
# A pull request that changes what the module ships must move <version> in Config/module.xml past
# the version on the base branch, to a version that has no tag yet: the push to the base branch
# tags that version, and a version already tagged is never released again.
# The base branch is read live from origin, so a re-run sees a pull request merged meanwhile.
# Usage: version-check.sh <module-checkout-at-pr-head> <base-branch>
set -euo pipefail
cd "$1"
base_branch=$2
# shellcheck source=lib.sh
source "$(dirname "$(realpath "$0")")/lib.sh"

# Paths that do not change the installed module: documentation, CI, tests, repository metadata.
not_shipped='^(.*\.md|docs/.*|\.github/.*|Tests/.*|tests/.*|phpunit[^/]*\.xml(\.dist)?|\.gitignore|\.gitattributes|\.editorconfig|\.scrutinizer\.yml|LICENSE.*|COPYING.*)$'

git fetch --no-tags --quiet origin "+refs/heads/$base_branch:refs/remotes/origin/$base_branch"
merge_base=$(git merge-base "origin/$base_branch" HEAD)
mapfile -t shipped < <(git diff --name-only "$merge_base" HEAD | grep -Ev "$not_shipped" || true)

summary=${GITHUB_STEP_SUMMARY:-/dev/stdout}
if [ ${#shipped[@]} -eq 0 ]; then
    echo "Only documentation, CI or tests change: no version bump needed." | tee -a "$summary"
    exit 0
fi
printf 'shipped file changed: %s\n' "${shipped[@]}"

head_version=$(module_version .)
base_version=$(git show "origin/$base_branch:Config/module.xml" | xml_version)
echo "version on $base_branch: $base_version, in this pull request: $head_version"

status=0
if ! php -r 'exit(version_compare($argv[1], $argv[2], ">") ? 0 : 1);' "$head_version" "$base_version"; then
    echo "::error file=Config/module.xml::<version> $head_version does not move past $base_version on $base_branch: merged as is, this change is never released. Bump Config/module.xml in this pull request."
    status=1
fi
if git ls-remote --exit-code --tags origin "refs/tags/$head_version" > /dev/null; then
    echo "::error file=Config/module.xml::tag $head_version already exists: the auto release skips a version already tagged. Take the next version."
    status=1
fi
[ $status -eq 0 ] && echo "Version $head_version is new and moves past $base_version." | tee -a "$summary"
exit $status
