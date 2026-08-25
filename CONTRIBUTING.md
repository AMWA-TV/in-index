# Contributing to `in-index`

## Proposing a new Increment

There are two ways to propose a new Increment. Both end up in the same
place: a PR that adds `proposals/<slug>.yml` and is gated by
[`CODEOWNERS`](.github/CODEOWNERS) + branch protection.

### Option A: form-driven (recommended)

1. Go to **Issues → New Issue → “Propose new AMWA Increment (IN-xxx)”** and fill in the form.
2. A bot will open a PR containing the generated `proposals/<slug>.yml`, and close your issue with a link to the PR.
3. Continue on the PR: tick the remaining checklist items and request review.

### Option B: hand-authored

1. Fork this repository.
2. Add a single YAML file under `proposals/`, named `proposals/<short-slug>.yml`. The slug is only used for the proposal file and for a human-friendly log entry — the eventual repository will be called `in-NNN`, where `NNN` is assigned automatically.
3. Fill it in using the schema below.
4. Open a Pull Request. The pull_request_template will prompt you for the other required sections.

### Review and merge

5. Two members of `@AMWA-TV/jt-dmf-in-admin` must approve.
6. On merge, the mint workflow runs on `main` and creates the new repo.

## Proposal schema

```yaml
# proposals/example.yml

# Human-readable Increment title. Will be used verbatim as the AMWA
# Increment name.
title: "API Requirements – Control of MXL v1.0"

# One-sentence description used in the site metadata.
short_description: "Requirements for a control API for MXL Readers/Writers"

# Optional: GitHub usernames of initial maintainers. Recorded in
# index.yml for audit; no permissions are set automatically.
initial_maintainers:
  - some-user
  - another-user
```

The JSON Schema used by CI lives at
[`schemas/proposal.schema.json`](./schemas/proposal.schema.json).

## Numbering rules

- Numbers are monotonically increasing. `index.yml`'s `last_assigned`
  field is the source of truth.
- Numbers are **never re-used** and **never back-filled**. If an Increment
  is withdrawn, its entry in `index.yml` is marked `status: withdrawn`
  and its number is retained.
- Numbers are zero-padded to three digits in repo names (`in-001`,
  `in-042`, …).

## What the mint workflow does to the new repo

Immediately after `POST /repos/AMWA-TV/in-template/generate` succeeds, the
mint workflow clones the new repo and patches:

- `README.md` — title line and Lint/Render badge URLs.
- `spec.yml` — `amwa_id`, `url`, `name`, `repo_name`, `repo_url`.
- `zensical.toml` — `site_name`, `site_description`.
- `docs/Overview.md` — H1 title line.
- `.github/workflows/docs.yml` — `SITE_NAME` env value.

It also copies `SSH_USER`, `SSH_HOST`, `SSH_PRIVATE_KEY`, `SSH_KNOWN_HOSTS`
from this repo's secrets into the new repo, so the Documentation workflow
there can deploy on its first run.

Anything else (branch protection, team access, topics, description) is
currently a manual follow-up.
