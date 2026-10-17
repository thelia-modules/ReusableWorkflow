# ReusableWorkflow

Workflows shared by the Thelia modules of the `thelia-modules` organization.

## Auto release (`auto_release.yml`)

Called by the `release.yml` of a module on every push to `main`. It reads `<version>` from
`Config/module.xml` and, when that version has no tag yet, tags the pushed commit and creates the
GitHub release. Packagist picks the tag up.

Rules for a module pull request:

- A pull request that changes what the module ships bumps `<version>` in `Config/module.xml`
  itself. The version must be new: a version already tagged is skipped, and the merged change is
  released nowhere.
- Two pull requests open at the same time cannot aim at the same version. When the first one is
  merged, the second takes the next version before it is merged.
- A fix that leaves the module broken can be merged without a bump on purpose: nothing is
  released until the bump.

Checks of the workflow:

- When the version is already tagged and something that ships changed since that tag, the run
  fails: the changes are on `main` and in no release.
- A version is tagged only on the tip of the branch, and the run fails if the tag ends up on any
  other commit than the pushed one or if the branch moved meanwhile.

Files that do not ship: Markdown, `docs/`, `.github/`, `Tests/`, `tests/`, the PHPUnit
configurations, the Git and editor configuration, the licence.

## Module CI (`module_ci.yml`)

```yaml
name: CI

on:
  pull_request:
    branches: [ main ]
  push:
    branches: [ main ]

permissions:
  contents: read

jobs:
  ci:
    uses: thelia-modules/ReusableWorkflow/.github/workflows/module_ci.yml@main
```

| Job | What it checks |
|---|---|
| Version bump | pull requests only: a change to what ships moves `<version>` past the base branch, to a version without a tag |
| Install on published Thelia | `composer create-project thelia/thelia-project` with the checkout in place of the released module, `bin/install`, `module:activate`, `lint:container`, `cache:warmup`, `/` and `/admin/login` answer 200 |
| PHPStan level 0 on published Thelia | every class, function and method the module calls exists in the published core |
| Module tests | the PHPUnit tests of the module inside `thelia/thelia` `main` (its own `phpunit.xml.dist` first) |
| Signal: install on Thelia main | the install job on the development tip of Thelia; information only, never fails the workflow |

Inputs: `php-version` (default `8.3`), `ci-ref` (ref the CI scripts are read from, default `main`).
The scripts live in `scripts/module-ci/`.
