<!--
Thank you for proposing a new AMWA IN document.

💡 Prefer the form-driven flow: open a new issue with the
“Propose new IN document” template (Issues → New Issue), fill in
the form, and a bot will open the PR for you with all sections
pre-filled. This template is for hand-authored PRs and for edits
to existing proposals.

This PR template is required. Fill in every section. Do not delete or
rename section headings — CI matches them by name to enforce the
Pre-merge checklist below.

If you are still drafting, open the PR as a **Draft** and come back to
tick the boxes when ready.
-->

## Document title

<!-- The human-readable title, used verbatim in the new repo's README,
spec.yml, zensical.toml site_name/site_description, and docs/Overview.md.
Include a version if applicable (e.g. "... v1.0").
MUST match `title:` in your `proposals/<slug>.yml`. -->

_Replace this line with the title._

## Slug

<!-- The filename `proposals/<slug>.yml` (without extension). Lowercase,
hyphen-separated, short. Used only in the proposal file and this PR;
the eventual repo will be called `in-NNN`. -->

_Replace this line with the slug._

## Short description

<!-- One sentence for site metadata. MUST match `short_description:` in
your proposal YAML. Max 200 characters. -->

_Replace this line with the short description._

## Purpose

<!-- 2–4 sentences: what problem does this document address, and why is
it needed now? -->

_Replace this paragraph._

## Scope

<!-- Bullet list of what is in scope, then what is explicitly out of
scope. Being explicit here saves later discussion. -->

**In scope:**

-

**Out of scope:**

-

## Relation to other AMWA work

<!-- Any related NMOS specs, INFO documents, other IN documents, or
external references. Write "None" if genuinely none. -->

-

## Initial maintainers

<!-- Optional. GitHub usernames, one per line. These get recorded in
index.yml for audit only; no repo permissions are set automatically. -->

-

## Pre-merge checklist

<!-- CI (`checklist` job) will fail this PR until every box below is ticked.
Reviewers: only tick the review-and-approval box once both approvals are in. -->

- [ ] I have added exactly one file at `proposals/<slug>.yml`.
- [ ] The proposal filename matches the **Slug** section above.
- [ ] `title` and `short_description` in the YAML match the sections above verbatim.
- [ ] The `validate-proposal` CI check is passing on this PR (schema-valid).
- [ ] A **dry-run** of the "Mint IN-XXX repo" workflow has been executed for this branch and the diff was reviewed. (Actions → *Mint IN-XXX repo* → *Run workflow* → select this branch → *Dry run: true*.)
- [ ] I understand the assigned `in-NNN` number is monotonic and can never be re-used or back-filled.
- [ ] Two approvals from [`@AMWA-TV/jt-dmf-in-admin`](https://github.com/orgs/AMWA-TV/teams/jt-dmf-in-admin) have been obtained. _(Reviewers: tick after the second approval.)_
