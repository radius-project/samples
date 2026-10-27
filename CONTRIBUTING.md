# Contributing

Radius is in an early phase of development right now. We welcome feedback in the form of issues that comes from usage and is aligned with the current scope and goals of the project. We also welcome contributions and PRs for bug fixes or security fixes. For new functionality or new samples please open an issue first to discuss the scope and goals of the feature. We will not accept new functionality or samples without an issue first.

## How to contribute

1. Fork the repository
2. Create a branch for your changes
3. Make your changes
4. Open a PR
5. Wait for a maintainer to review your PR

## Sample CI environments

The **Test Samples (K3D)** workflow creates a separate cluster for each sample.
Its `resourceProvider` matrix entry must match the sample's application and
environment resource types.

The demo uses `Radius.Core` and the default container recipe pack, matching the
current CLI's default resource model.

Dapr and volumes still use `Applications.Core`. CI deploys
[a legacy environment template](.github/test/legacy-environment.bicep) and passes
its full resource ID to `rad deploy`, rather than using `rad env create` or
`rad env switch`, which now target `Radius.Core`. These samples do not need
recipe registration: Dapr provisions Redis and its state-store component
manually, and volumes uses an ephemeral volume. Cleanup deletes their isolated
test resource group because current `rad app delete` only targets `Radius.Core`.

## Release branch upmerges

Run **Upmerge to edge** from the active release branch.
`.github/workflows/upmerge.yaml` is a synced thin caller of the shared
[`__upmerge.yml`](https://github.com/radius-project/.github/blob/main/.github/workflows/__upmerge.yml)
workflow in `radius-project/.github`. Merge preparation, App-backed signing, and
verification are maintained centrally, not copied here.
The caller follows the organization's existing `@main` reusable-workflow pattern.

The samples caller lists `bicepconfig.json` in its `preserve-paths` input.
See the [shared upmerge guidance](https://github.com/radius-project/.github/blob/main/eng/SYNC.md#signed-release-upmerge)
for signing, preserved-file handling, conflict resolution, no-change behavior,
and required App permissions.

Update the shared workflow and native caller in `radius-project/.github`.
[`workflow-templates/upmerge-samples.yml`](https://github.com/radius-project/.github/blob/main/workflow-templates/upmerge-samples.yml)
declares the literal `preserve-paths` input for samples. `.github/sync.yml` selects
that static file and its `samples@edge` destination; it does not supply workflow
inputs. Do not edit the synced file or maintain local merge code.
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
