# AMWA Increment Index

This repository is the authoritative index of AMWA **Increments (IN-xxx) **
and the automation that mints new `AMWA-TV/in-NNN` repositories from the
[`in-template`](https://github.com/AMWA-TV/in-template) template.

## How new Increments are created

1. Either:
   - Open a **New Issue** and pick “**Propose new AMWA Increment (IN-xxx)**” — fill in the form and a bot will open the PR for you and close the issue; **or**
   - Open a PR by hand that adds a single file under `proposals/`, e.g.
     `proposals/my-topic.yml`. You do **not** pick the number in either case.
2. Two members of `@AMWA-TV/jt-dmf-in-admin` must approve the PR
   (enforced via `CODEOWNERS` + branch protection).
3. On merge to `main`, the mint workflow:
   - allocates the next unused number (monotonic; never re-used, never
     back-filled),
   - creates `AMWA-TV/in-NNN` from `AMWA-TV/in-template`,
   - patches `README.md`, `spec.yml`, `zensical.toml`, and
     `docs/Overview.md` in the new repo,
   - copies the `SSH_*` upload secrets from this repo into the new one,
   - records the entry in [`index.yml`](./index.yml) and regenerates the
     index table below,
   - deletes the merged proposal file.

See [`CONTRIBUTING.md`](./CONTRIBUTING.md) for the proposal file schema and
the full workflow.

## Issued Increments

<!-- INDEX-START -->
<!-- This table is regenerated from index.yml by .github/scripts/regenerate-readme.sh -->

| Number | Title | Repo | Status |
|--------|-------|------|--------|
| IN-001 | API Requirements – Control of MXL v1.0 | [`AMWA-TV/in-001`](https://github.com/AMWA-TV/in-001) | active |
| IN-002 | Time and Identity in the Dynamic Media Facility | [`AMWA-TV/in-002`](https://github.com/AMWA-TV/in-002) | active |

<!-- INDEX-END -->

## Setup notes

- This repository requires a GitHub App to be installed on the `AMWA-TV`
  organisation with the permissions listed in
  [`docs/github-app-setup.md`](./docs/github-app-setup.md), and its App ID
  and private key stored as the repo secrets `MINTER_APP_ID` and
  `MINTER_APP_PRIVATE_KEY`.
- The four `SSH_*` upload secrets used by the `Documentation` workflow in
  each `in-NNN` repo are also stored on this repo, so they can be
  replicated into freshly-minted repos.
