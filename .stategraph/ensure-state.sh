#!/usr/bin/env bash
# Make sure the directory this step runs in has a Stategraph state, so that a
# pull request adding a new directory needs nothing but its Terraform.
#
# Runs as a `run` step before `init`, in the directory of the operation, with
# STATEGRAPH_API_BASE / STATEGRAPH_API_KEY / STATEGRAPH_TENANT_ID from the
# repository secrets and TERRATEAM_DIR / TERRATEAM_WORKSPACE from the runner.
# The state is named after the repository, directory and workspace, and names
# are unique per tenant, so the name is the idempotency key: a second run (the
# apply, a new PR on an existing directory) finds the state instead of
# creating one. stategraph.json is never committed; this regenerates it.
set -euo pipefail

# The CLI release to use: its state schema must match the server's. The
# runner image ships a CLI frozen at image-build time and ignores the engine's
# `version` pin while that binary exists, so install the pinned one over it.
SG_CLI_VERSION="${STATEGRAPH_VERSION:-3.2.8}"
if ! stategraph version 2>/dev/null | grep -q "$SG_CLI_VERSION"; then
    arch="$(uname -m | sed 's/x86_64/amd64/; s/aarch64/arm64/')"
    tmp="$(mktemp -d)"
    curl -fsSL -o "$tmp/cli.tar.gz" \
        "https://github.com/stategraph/releases/releases/download/${SG_CLI_VERSION}/stategraph-${SG_CLI_VERSION}-linux-${arch}.tar.gz"
    tar -xzf "$tmp/cli.tar.gz" -C "$tmp"
    install -m 0755 "$tmp/stategraph" /usr/local/bin/stategraph
    echo "ensure-state: installed stategraph CLI $SG_CLI_VERSION"
fi

# Print the mapping so that a developer can commit it from the PR comment,
# after which this step has nothing left to do for the directory.
show() {
    echo
    echo "ensure-state: ${TERRATEAM_DIR}/stategraph.json (commit it to pin the directory to its state):"
    cat stategraph.json
}

if [ -f stategraph.json ]; then
    echo "ensure-state: stategraph.json present, nothing to do"
    exit 0
fi

name="${GITHUB_REPOSITORY}:${TERRATEAM_DIR}:${TERRATEAM_WORKSPACE}"

if stategraph states create --name "$name" --workspace "$TERRATEAM_WORKSPACE" --silent >/dev/null 2>/tmp/ensure-state.err; then
    echo "ensure-state: created state '$name'"
    show
    exit 0
fi

# Creation failed: most likely the state exists (409). Look it up by name.
group_id="$(stategraph states resolve --name "$name" --group 2>/dev/null | tr -d '[:space:]')"
if [ -z "$group_id" ]; then
    echo "ensure-state: could not create or find state '$name':" >&2
    cat /tmp/ensure-state.err >&2
    exit 1
fi
printf '{"group_id":"%s"}\n' "$group_id" > stategraph.json
echo "ensure-state: using existing state '$name' (group $group_id)"
show
