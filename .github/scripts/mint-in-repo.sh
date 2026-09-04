#!/usr/bin/env bash
#
# For each YAML file under proposals/, allocate the next IN number,
# create AMWA-TV/in-NNN from the in-template template, patch its
# identity files, seed its SSH_* secrets, and record the mint in
# index.yml. Deletes the proposal file on success.
#
# Requires the following in the environment:
#   GH_TOKEN            GitHub App installation token with Administration,
#                       Contents, and Secrets: write on AMWA-TV.
#   SSH_USER, SSH_HOST, SSH_PRIVATE_KEY, SSH_KNOWN_HOSTS
#                       Values to seed as secrets on each new repo.
#
# Flags:
#   --dry-run           Report what would be minted (numbers, repo names,
#                       customisation diffs) without creating repos,
#                       pushing commits, setting secrets, or modifying
#                       index.yml / proposal files. GH_TOKEN and SSH_*
#                       are not required in dry-run mode.
#
# Idempotent-ish: if the repo AMWA-TV/in-NNN already exists (e.g. a
# previous run failed mid-flight), the script errors out; the operator
# must decide whether to bump last_assigned in index.yml and re-run.

set -euo pipefail

DRY_RUN="${DRY_RUN:-0}"
for arg in "$@"; do
    case "$arg" in
        --dry-run) DRY_RUN=1 ;;
        -h|--help)
            sed -n '2,25p' "$0"; exit 0 ;;
        *) echo "error: unknown arg: $arg" >&2; exit 2 ;;
    esac
done

if [[ "$DRY_RUN" == "1" ]]; then
    echo "*** DRY RUN: no repos will be created, no secrets set, no files changed. ***"
fi

# Wrap side-effecting commands so dry-run mode just echoes them.
run() {
    if [[ "$DRY_RUN" == "1" ]]; then
        printf '  [dry-run] would run: '
        printf '%q ' "$@"
        printf '\n'
    else
        "$@"
    fi
}

TEMPLATE_OWNER="AMWA-TV"
TEMPLATE_REPO="in-template"
ORG="AMWA-TV"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

# yq-lite via python, so we don't depend on runner-preinstalled binaries.
py_read() { python -c "$@"; }

get_last_assigned() {
    py_read '
import yaml
print(int((yaml.safe_load(open("index.yml")) or {}).get("last_assigned", 0)))
'
}

# Append an increment entry and bump last_assigned in index.yml, preserving
# ordering and comments as best we can. We use ruamel.yaml if available for
# comment-preservation, else fall back to PyYAML (which drops comments).
append_index_entry() {
    local number="$1" repo="$2" title="$3" maintainers_json="$4" proposal_file="$5"
    python - "$number" "$repo" "$title" "$maintainers_json" "$proposal_file" <<'PY'
import json, sys, datetime, pathlib
try:
    from ruamel.yaml import YAML
    yaml = YAML()
    yaml.preserve_quotes = True
    yaml.indent(mapping=2, sequence=2, offset=0)
    load, dump = yaml.load, yaml.dump
    use_ruamel = True
except ImportError:
    import yaml as _y
    load = lambda f: _y.safe_load(f)
    def dump(data, f):
        _y.safe_dump(data, f, sort_keys=False, allow_unicode=True)
    use_ruamel = False

number, repo, title, maintainers_json, proposal_file = sys.argv[1:6]
maintainers = json.loads(maintainers_json)

p = pathlib.Path("index.yml")
with p.open() as f:
    data = load(f) or {}

data["last_assigned"] = int(number)
data.setdefault("documents", []).append({
    "number": int(number),
    "repo": repo,
    "title": title,
    "status": "active",
    "minted_at": datetime.datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ"),
    "minted_from_proposal": proposal_file,
    "initial_maintainers": maintainers,
})

with p.open("w") as f:
    dump(data, f)
PY
}

# Extract a value from a proposal file. Missing keys yield an empty string.
proposal_get() {
    local file="$1" key="$2"
    python - "$file" "$key" <<'PY'
import sys, yaml, json
file, key = sys.argv[1], sys.argv[2]
data = yaml.safe_load(open(file)) or {}
v = data.get(key, "")
if isinstance(v, (list, dict)):
    print(json.dumps(v))
else:
    print(v)
PY
}

encrypt_secret() { :; }  # legacy no-op; gh secret set handles encryption for us.

set_repo_secret() {
    # Args: <owner/repo> <secret-name> <plaintext>
    local repo="$1" name="$2" value="$3"
    printf '%s' "${value}" | gh secret set "${name}" --repo "${repo}" --body -
}

# ---------------------------------------------------------------------------
# In-place customisation of a freshly-cloned in-NNN checkout.
#
# Applied to `.` in the cwd. Values are read from env for simplicity.
#   NEW_REPO_NAME       e.g. in-042
#   AMWA_ID             e.g. IN-042
#   DOC_TITLE           e.g. "API Requirements ..."
#   SHORT_DESCRIPTION   e.g. "One-sentence summary"
# ---------------------------------------------------------------------------
customise_new_repo() {
    # README.md: replace the badge links' repo slug and the H1 title.
    sed -i -E \
        -e "s#(AMWA-TV/)in-template#\\1${NEW_REPO_NAME}#g" \
        -e "1s#.*#\\# \\\\[Work In Progress\\\\] AMWA ${AMWA_ID}: ${DOC_TITLE}#" \
        README.md

    # spec.yml
    python - <<PY
import yaml, pathlib
p = pathlib.Path("spec.yml")
data = yaml.safe_load(p.read_text()) or {}
data["amwa_id"]   = "${AMWA_ID}"
data["url"]       = "https://specs.amwa.tv/${NEW_REPO_NAME}"
data["name"]      = """${DOC_TITLE}"""
data["repo_name"] = "${NEW_REPO_NAME}"
data["repo_url"]  = "https://github.com/${ORG}/${NEW_REPO_NAME}"
p.write_text(yaml.safe_dump(data, sort_keys=False, allow_unicode=True))
PY

    # .render/_config.yml
    if [[ -f .render/_config.yml ]]; then
        sed -i -E \
            -e "s#^amwa_id: .*#amwa_id: ${AMWA_ID}#" \
            -e "s#^baseurl: .*#baseurl: /${NEW_REPO_NAME}#" \
            .render/_config.yml
    fi

    # zensical.toml
    sed -i -E \
        -e "s#^site_name = .*#site_name = \"${AMWA_ID}\"#" \
        -e "s#^site_description = .*#site_description = \"AMWA ${AMWA_ID}: ${DOC_TITLE}\"#" \
        -e "s#^repo_url = .*#repo_url = \"https://github.com/${ORG}/${NEW_REPO_NAME}\"#" \
        -e "s#^repo_name = .*#repo_name = \"${ORG}/${NEW_REPO_NAME}\"#" \
        zensical.toml

    # docs/Overview.md: replace only the first H1.
    if [[ -f docs/Overview.md ]]; then
        python - <<'PY'
import os, pathlib
p = pathlib.Path("docs/Overview.md")
lines = p.read_text().splitlines(keepends=True)
title = os.environ["DOC_TITLE"]
for i, line in enumerate(lines):
    if line.startswith("# "):
        lines[i] = f"# {title}\n"
        break
p.write_text("".join(lines))
PY
    fi

    # docs.yml: update the SITE_NAME env value and the landing-page check.
    if [[ -f .github/workflows/docs.yml ]]; then
        sed -i -E \
            -e "s#(SITE_NAME:\s*)in-template#\1${NEW_REPO_NAME}#" \
            -e "s#grep -Fq \"Template for AMWA Increments\"#grep -Fq \"${DOC_TITLE}\"#" \
            .github/workflows/docs.yml
    fi
}

# mktemp on macOS is finicky about TMPDIR; allow callers to force the parent.
make_tempdir() {
    if [[ -n "${MINT_TMP_ROOT:-}" ]]; then
        mkdir -p "${MINT_TMP_ROOT}"
        mktemp -d "${MINT_TMP_ROOT}/mint-XXXXXX"
    else
        mktemp -d
    fi
}

wait_for_repo_ready() {
    # After POST /generate the repo returns 202-ish for a moment while
    # GitHub materialises the initial commit. Poll until we can see a
    # default branch.
    local repo="$1" i
    for i in $(seq 1 30); do
        # Repository generation creates the repo/default branch before the
        # template contents are necessarily available. Wait for a known
        # template file as well, otherwise the first clone can be empty.
        if gh api "repos/${repo}" --jq '.default_branch' 2>/dev/null | grep -q . \
            && gh api "repos/${repo}/contents/README.md" --jq '.sha' 2>/dev/null | grep -q .; then
            return 0
        fi
        sleep 2
    done
    echo "Timed out waiting for ${repo} to become ready" >&2
    return 1
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

# In dry-run mode SSH_* and GH_TOKEN are not needed.
required_vars=( GH_TOKEN SSH_USER SSH_HOST SSH_PRIVATE_KEY SSH_KNOWN_HOSTS )
if [[ "$DRY_RUN" == "1" ]]; then
    required_vars=()
fi
for var in "${required_vars[@]}"; do
    if [[ -z "${!var:-}" ]]; then
        echo "error: ${var} not set" >&2
        exit 1
    fi
done

shopt -s nullglob
proposals=( proposals/*.yml proposals/*.yaml )
# The proposals/README.md is not a proposal; filter accidentally-matched files.
proposals_filtered=()
for f in "${proposals[@]}"; do
    [[ "$(basename "$f")" == "README.md" ]] && continue
    proposals_filtered+=( "$f" )
done
proposals=( "${proposals_filtered[@]}" )

if [[ ${#proposals[@]} -eq 0 ]]; then
    echo "No proposals to process."
    exit 0
fi

# Deterministic order (alphabetical by filename) so mint numbers are
# predictable when a single PR adds multiple proposals.
IFS=$'\n' proposals=( $(printf '%s\n' "${proposals[@]}" | sort) )
unset IFS

for proposal in "${proposals[@]}"; do
    echo
    echo "=============================================================="
    echo "Processing ${proposal}"
    echo "=============================================================="

    title=$(proposal_get "${proposal}" title)
    short_description=$(proposal_get "${proposal}" short_description)
    maintainers_json=$(proposal_get "${proposal}" initial_maintainers)
    [[ -z "${maintainers_json}" ]] && maintainers_json="[]"

    last=$(get_last_assigned)
    number=$((last + 1))
    padded=$(printf '%03d' "${number}")
    new_repo_name="in-${padded}"
    amwa_id="IN-${padded}"
    full_repo="${ORG}/${new_repo_name}"

    echo "Allocating ${amwa_id} → ${full_repo}"

    # Guard against collision (never re-use).
    if [[ "$DRY_RUN" == "1" ]]; then
        if gh api "repos/${full_repo}" >/dev/null 2>&1; then
            echo "  [dry-run] warning: ${full_repo} already exists on GitHub; a real run would abort here."
        fi
    else
        if gh api "repos/${full_repo}" >/dev/null 2>&1; then
            echo "error: ${full_repo} already exists; refusing to overwrite." >&2
            echo "Fix index.yml's last_assigned and re-run." >&2
            exit 1
        fi
    fi

    if [[ "$DRY_RUN" == "1" ]]; then
        echo "Preview: cloning ${TEMPLATE_OWNER}/${TEMPLATE_REPO} and applying customisation to show diff..."
        workdir="$(make_tempdir)"
        (
            cd "${workdir}"
            # Public template, so no auth needed for the dry-run preview.
            git clone --depth=1 --quiet "https://github.com/${TEMPLATE_OWNER}/${TEMPLATE_REPO}.git" .
            NEW_REPO_NAME="${new_repo_name}" \
            AMWA_ID="${amwa_id}" \
            DOC_TITLE="${title}" \
            SHORT_DESCRIPTION="${short_description}" \
            ORG="${ORG}" \
                customise_new_repo
            echo
            echo "--- customisation diff (${full_repo}) ---"
            git --no-pager diff --stat
            echo
            git --no-pager diff
            echo "--- end diff ---"
        )
        rm -rf "${workdir}"
        echo
        echo "  [dry-run] would seed secrets SSH_USER, SSH_HOST, SSH_PRIVATE_KEY, SSH_KNOWN_HOSTS on ${full_repo}"
        echo "  [dry-run] would append entry #${number} (${full_repo}, \"${title}\") to index.yml"
        echo "  [dry-run] would git rm ${proposal}"
        echo "Done (dry-run): ${full_repo}"
        continue
    fi

    echo "Creating repository from template..."
    gh api --method POST "repos/${TEMPLATE_OWNER}/${TEMPLATE_REPO}/generate" \
        -f "owner=${ORG}" \
        -f "name=${new_repo_name}" \
        -f "description=${short_description}" \
        -F "private=false" \
        -F "include_all_branches=false" >/dev/null

    wait_for_repo_ready "${full_repo}"

    workdir="$(make_tempdir)"
    (
        cd "${workdir}"
        git clone --depth=1 "https://x-access-token:${GH_TOKEN}@github.com/${full_repo}.git" .
        git config user.name  'amwa-in-index-bot[bot]'
        git config user.email 'amwa-in-index-bot[bot]@users.noreply.github.com'

        NEW_REPO_NAME="${new_repo_name}" \
        AMWA_ID="${amwa_id}" \
        DOC_TITLE="${title}" \
        SHORT_DESCRIPTION="${short_description}" \
        ORG="${ORG}" \
            customise_new_repo

        git add -A
        if ! git --no-pager diff --cached --quiet; then
            git commit -m "chore: customise repo for ${amwa_id}"
            git push origin HEAD
        else
            echo "No customisation changes (template already matched?)."
        fi
    )
    rm -rf "${workdir}"

    echo "Seeding SSH_* secrets on ${full_repo}..."
    set_repo_secret "${full_repo}" SSH_USER        "${SSH_USER}"
    set_repo_secret "${full_repo}" SSH_HOST        "${SSH_HOST}"
    set_repo_secret "${full_repo}" SSH_PRIVATE_KEY "${SSH_PRIVATE_KEY}"
    set_repo_secret "${full_repo}" SSH_KNOWN_HOSTS "${SSH_KNOWN_HOSTS}"

    echo "Recording in index.yml..."
    append_index_entry "${number}" "${full_repo}" "${title}" "${maintainers_json}" "${proposal}"

    echo "Removing merged proposal file ${proposal}..."
    git rm -f "${proposal}"

    echo "Done: ${full_repo}"
done
