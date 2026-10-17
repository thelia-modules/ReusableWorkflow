#!/usr/bin/env bash
# A pull request that changes what the module ships must move <version> in Config/module.xml past
# the version on the base branch and past the greatest tag, to a valid semantic version that has no
# tag yet: the push to the base branch tags that version (the auto release refuses it otherwise),
# and a version already tagged is never released again.
# The base branch is read live from origin, so a re-run sees a pull request merged meanwhile.
# Usage: version-check.sh <module-checkout-at-pr-head> <base-branch>
set -euo pipefail
cd "$1"
base_branch=$2
# shellcheck source=lib.sh
source "$(dirname "$(realpath "$0")")/lib.sh"

# Paths that do not change the installed module: documentation, CI, tests, repository metadata.
not_shipped='^(.*\.md|docs/.*|\.github/.*|Tests/.*|tests/.*|phpunit[^/]*\.xml(\.dist)?|\.gitignore|\.gitattributes|\.editorconfig|\.scrutinizer\.yml|LICENSE.*|COPYING.*|phpstan[^/]*\.neon(\.dist)?|rector\.php|\.php-cs-fixer[^/]*)$'

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
references=$(mktemp)
semver="$(dirname "$(realpath "$0")")/semver.py"
if git ls-remote --exit-code --tags origin "refs/tags/$head_version" > /dev/null; then
    echo "::error file=Config/module.xml::tag $head_version already exists: the auto release skips a version already tagged. Take the next version."
    status=1
fi
# Semantic version, strictly above every tag of the repository (read live) and the version on the base branch.
git ls-remote --tags origin 'refs/tags/*' | sed -n 's:^[0-9a-f]*[[:space:]]*refs/tags/\(.*[^}]\)$:\1:p' > "$references"
python3 "$semver" "$head_version" "$references" "existing tag" || status=1
echo "$base_version" > "$references"
python3 "$semver" "$head_version" "$references" "version on $base_branch" || status=1
[ $status -eq 0 ] && echo "Version $head_version is valid, new and moves past $base_version." | tee -a "$summary"
exit $status
