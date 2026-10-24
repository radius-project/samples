# Contributing

Radius is in an early phase of development right now. We welcome feedback in the form of issues that comes from usage and is aligned with the current scope and goals of the project. We also welcome contributions and PRs for bug fixes or security fixes. For new functionality or new samples please open an issue first to discuss the scope and goals of the feature. We will not accept new functionality or samples without an issue first.

## How to contribute

1. Fork the repository
2. Create a branch for your changes
3. Make your changes
4. Open a PR
5. Wait for a maintainer to review your PR

## Release branch upmerges

Run **Upmerge samples to edge** from the active release branch. The workflow
prepares a squash merge on `edge` and delegates the uncommitted net diff to
`peter-evans/create-pull-request`. With `sign-commits: true` and the short-lived
`RADIUS_RELEASE_BOT` App token, GitHub creates a signed, single-parent commit
without importing release-branch ancestry. The explicit App `Signed-off-by`
trailer supplies DCO signoff; a signoff or authenticated push alone is not a
cryptographic signature. The workflow fails unless the action reports its
GitHub-verified commit and PR outputs.

`bicepconfig.json` always retains its `edge` state, including absence or deletion.
An unchanged tree skips PR creation. Genuine content conflicts produce a draft
containing a **provisional source snapshot**, not a resolved merge: other
edge-only changes may be absent and must be restored during manual resolution.
Fetch, Git, and I/O errors fail rather than masquerading as conflicts or no-ops.
Normal review and branch protections still apply.

The App installation must grant **Contents**, **Pull requests**, and
**Workflows: Read & Write** in this repository; workflow-file propagation needs
the last permission. No signing key or branch-rule bypass is required.
`repo-files-sync` is not a substitute here: copying source files would overwrite
edge edits rather than perform the required three-way merge.

For rollout, merge the code PR into the active `v0.61` branch. The next signed
upmerge propagates the workflow and tests to `edge` before the next release cut;
the preparation code is inline, so it does not depend on tools already existing
on `edge`. Re-running an already-recorded failed run still uses its old workflow
revision. Existing [PR #2704](https://github.com/radius-project/samples/pull/2704)
requires a separately authorized repair; this workflow change does not repair it.

Run the dependency-free workflow fixtures with
`node --test .github/scripts/upmerge.test.mjs`. They execute the actual YAML shell
steps against temporary native Git repositories. On Windows, set
`UPMERGE_TEST_BASH` to Git for Windows' `bin\bash.exe`; do not run these fixtures
with WSL Git against Windows worktree metadata.

## Code of Conduct

Please refer to our [Radius Community Code of Conduct](https://github.com/project-radius/radius/blob/main/CODE_OF_CONDUCT.md)
