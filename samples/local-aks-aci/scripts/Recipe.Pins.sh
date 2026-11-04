#!/usr/bin/env bash
kubernetes_recipe_commit() {
    local root=$1 radius_version=$2
    jq -er --arg version "$radius_version" '
        if type == "object" and .radiusVersion == $version and
            (.sourceCommit | type == "string" and test("^[a-f0-9]{40}$"))
        then .sourceCommit
        else error("kubernetes-recipes.lock.json must bind the Radius release to a full upstream source commit")
        end
    ' "$root/kubernetes-recipes.lock.json"
}
