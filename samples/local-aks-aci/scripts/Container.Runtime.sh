#!/usr/bin/env bash
# Only defines helpers; the caller controls error handling and always invokes docker.
container_provider_from_help() {
    case "$1" in
        *[Pp][Oo][Dd][Mm][Aa][Nn]' version information'*) printf 'Podman\n' ;;
        *[Dd][Oo][Cc][Kk][Ee][Rr]' version information'*) printf 'Docker\n' ;;
        *) printf '%s\n' 'Cannot identify the Docker-compatible CLI. Inspect: docker version --help' >&2; return 1 ;;
    esac
}

container_minimum_version() {
    case "$1" in
        Podman) printf '3.0.0\n' ;;
        Docker) printf '20.10.5\n' ;;
        *) printf 'Unsupported container provider: %s\n' "$1" >&2; return 1 ;;
    esac
}

container_info_format() {
    case "$1" in
        Podman) printf 'json\n' ;;
        Docker) printf '{{json .}}\n' ;;
        *) printf 'Unsupported container provider: %s\n' "$1" >&2; return 1 ;;
    esac
}

container_engine_from_info() {
    jq -ce --arg provider "$1" '
        if $provider == "Podman" then
            {provider:$provider,version:.version.Version,os:.host.os,architecture:.host.arch}
        elif $provider == "Docker" then
            {provider:$provider,version:.ServerVersion,os:.OSType,architecture:.Architecture}
        else error("Unsupported container provider") end |
        if all(.version,.os,.architecture; type == "string" and length > 0) then .
        else error("Missing container server version, OS, or architecture metadata") end |
        if (.version | test("^[0-9]+\\.[0-9]+(\\.[0-9]+)?")) then .
        else error("Unrecognized container server version") end |
        .os |= ascii_downcase |
        .architecture |= ascii_downcase |
        if .architecture == "x86_64" then .architecture = "amd64"
        elif .architecture == "aarch64" then .architecture = "arm64" else . end
    ' <<< "$2"
}

read_container_engine() {
    local help_text provider info_format engine_info
    help_text="$(docker version --help)" || return
    provider="$(container_provider_from_help "$help_text")" || return
    info_format="$(container_info_format "$provider")" || return
    engine_info="$(docker info --format "$info_format")" || return
    container_engine_from_info "$provider" "$engine_info"
}
