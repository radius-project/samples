# Contributing

Radius is in an early phase of development right now. We welcome feedback in the form of issues that comes from usage and is aligned with the current scope and goals of the project. We also welcome contributions and PRs for bug fixes or security fixes. For new functionality or new samples please open an issue first to discuss the scope and goals of the feature. We will not accept new functionality or samples without an issue first.

## How to contribute

1. Fork the repository
2. Create a branch for your changes
3. Make your changes
4. Open a PR
5. Wait for a maintainer to review your PR

## Release branch upmerges

Run **Upmerge to edge** from the active release branch.
`.github/workflows/upmerge.yaml` is a generated thin caller of the shared
[`__upmerge.yml`](https://github.com/radius-project/.github/blob/main/.github/workflows/__upmerge.yml)
workflow in `radius-project/.github`. Merge preparation, App-backed signing,
verification, and regression fixtures are maintained centrally, not copied here.
The caller follows the organization's existing `@main` reusable-workflow pattern.

`bicepconfig.json` always retains its `edge` state, including absence or deletion.
The shared workflow prepares a squash on `edge` and delegates its uncommitted
net diff to `peter-evans/create-pull-request` for one App-signed commit without
release-branch ancestry. The explicit App `Signed-off-by` trailer is DCO signoff,
not a cryptographic signature. No-change runs skip PR creation; genuine conflicts
produce a provisional draft source snapshot that may omit edge-only changes and
requires manual reconciliation, not a safely merged snapshot. Normal review and
branch protections still apply.

The App installation must grant **Contents**, **Pull requests**, and
**Workflows: Read & Write** in this repository; workflow-file propagation needs
the last permission. No bot commit-signing key or branch-rule bypass is required.

Update the shared workflow, caller template, and sync configuration in
`radius-project/.github`: `sync-templates/.github/workflows/upmerge.yaml.njk` and
the samples `template.preserve_paths` entry in `.github/sync.yml` configure this
caller. Do not edit the generated file or maintain local merge code or fixtures.
Follow [the central sync guide](https://github.com/radius-project/.github/blob/main/eng/SYNC.md#signed-release-upmerge)
for rendering callers and running the shared
[merge fixtures](https://github.com/radius-project/.github/blob/main/.github/tests/upmerge.test.mjs)
and [caller contract checks](https://github.com/radius-project/.github/blob/main/.github/tests/upmerge-callers.test.cjs).
File sync distributes only the caller to `samples@edge`, not release/source
content; it does not replace the three-way upmerge.

For rollout, merge the central reusable workflow and sync changes **first**, then
merge this caller into the active `v0.61` branch. Syncing only `edge` does not
bootstrap `v0.61`. Review the normal Sync PR delivering the caller to `edge`
before the next release cut; future release branches inherit it from there.
Do not dispatch the caller until the shared workflow exists on `main`.
Already-recorded pre-migration failures still use their old workflow revision. Existing
[PR #2704](https://github.com/radius-project/samples/pull/2704) requires a separately
authorized repair; this rollout does not repair it.

## Code of Conduct

Please refer to our [Radius Community Code of Conduct](https://github.com/project-radius/radius/blob/main/CODE_OF_CONDUCT.md)
