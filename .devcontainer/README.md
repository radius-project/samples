# Summary

This folder containers the sources used to **pre-build** our devcontainer base image. We pack as much as we
can into the base image so that the initialization done by each user is limited.

## Contents

- `devcontainer.json`: This will be used by VS Code and Codespaces to load the actual devcontainer. This refers to a pre-built image and does the minimum needed to augment it.
- `Dockerfile`: This is the dockerfile for our **base image**. This is used by the CI pipeline and not directly by users.
- `library-scripts/`: These are copied from the official devcontainer repo. Each script contains a link (at the top) to its documentation and official location. Yes this is the recommended way to handle these depenendencies :-/.