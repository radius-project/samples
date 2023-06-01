# ------------------------------------------------------------
# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.
# ------------------------------------------------------------

# This script parses docs version from PR and set the parsed version to
# environment variables, DOCS_CHANNEL.

# We set the environment variable REL_CHANNEL based on the kind of build. This is used for
# versioning of our assets.
#
# DOCS_CHANNEL is used to upload assets to different paths
# 'edge' when targeting edge branch
# '1.0' when targeting a release branch
#
# RELEASE_BRANCH is used when referencing the full release version
# 'main' when targeting edge branch
# '1.0' when targeting a release branch

import os
import sys

gitRefName = os.getenv("GITHUB_BASE_REF")
print("GITHUB_BASE_REF: {}".format(gitRefName))

with open(os.getenv("GITHUB_ENV"), "a") as githubEnv:
    channel = "DOCS_CHANNEL=edge"
    release_branch = "RELEASE_BRANCH=main"

    if gitRefName is None:
        print("This is not running in github, GITHUB_REF_NAME is null. Assuming a local build. Setting DOCS_CHANNEL to 'edge' and RELEASE_BRANCH to 'main'")
    elif gitRefName.lower() == 'edge':
        print("This is an edge build, setting DOCS_CHANNEL to 'edge' and RELEASE_BRANCH to 'main'")
    elif gitRefName.startswith('v'):
        print("This is a release build, setting DOCS_CHANNEL and RELEASE_BRANCH to version")
        channel = "DOCS_CHANNEL=" + gitRefName.split('v')[1]
        release_branch = "RELEASE_BRANCH=" + gitRefName + '.0'
    else:
        print("This is a non-standard build, setting DOCS_CHANNEL to 'edge' and RELEASE_BRANCH to 'main'")

    print("Setting DOCS_CHANNEL: {}".format(channel))
    githubEnv.write(channel + "\n")

    print("Setting RELEASE_BRANCH: {}".format(release_branch))
    githubEnv.write(release_branch + "\n")

    sys.exit(0)
