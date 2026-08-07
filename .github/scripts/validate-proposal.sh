#!/usr/bin/env bash
#
# Validate proposal YAML files against schemas/proposal.schema.json and
# emit a Markdown summary predicting what number each proposal will be
# assigned on merge.
#
# Inputs (env):
#   FILES  Newline-separated list of proposal file paths (may be empty).
#
# Outputs (via $GITHUB_OUTPUT):
#   summary  Markdown block for the PR comment (empty if nothing to say).

set -euo pipefail

SCHEMA="schemas/proposal.schema.json"

if [[ -z "${FILES//[[:space:]]/}" ]]; then
    echo "No proposal files changed; nothing to validate."
    {
        echo 'summary<<EOF'
        echo 'EOF'
    } >> "${GITHUB_OUTPUT:-/dev/null}"
    exit 0
fi

# Read the current highest-assigned number so we can predict.
last_assigned=$(python -c '
import sys, yaml
with open("index.yml") as f:
    doc = yaml.safe_load(f) or {}
print(int(doc.get("last_assigned", 0)))
')

summary_lines=()
next=$((last_assigned + 1))
had_error=0

while IFS= read -r file; do
    [[ -z "${file}" ]] && continue
    if [[ ! -f "${file}" ]]; then
        # file was deleted in this PR (shouldn't happen given diff-filter=AM)
        continue
    fi

    echo "Validating ${file}"
    if ! check-jsonschema --schemafile "${SCHEMA}" "${file}"; then
        summary_lines+=("- ❌ \`${file}\` failed schema validation (see workflow log).")
        had_error=1
        continue
    fi

    title=$(python -c '
import sys, yaml
with open(sys.argv[1]) as f:
    print(yaml.safe_load(f)["title"])
' "${file}")

    padded=$(printf 'in-%03d' "${next}")
    summary_lines+=("- ✅ \`${file}\` → will be minted as **\`AMWA-TV/${padded}\`** (\"${title}\").")
    next=$((next + 1))
done <<< "${FILES}"

if [[ ${#summary_lines[@]} -eq 0 ]]; then
    summary=""
else
    summary=$'Mint preview:\n\n'"$(printf '%s\n' "${summary_lines[@]}")"
fi

{
    echo 'summary<<EOF'
    printf '%s\n' "${summary}"
    echo 'EOF'
} >> "${GITHUB_OUTPUT:-/dev/null}"

exit "${had_error}"
