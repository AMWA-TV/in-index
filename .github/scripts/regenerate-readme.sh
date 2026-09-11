#!/usr/bin/env bash
#
# Rewrite the "Issued increments" table in README.md from index.yml and the
# published spec.json metadata for each repository.
# Idempotent: no-ops if the table already matches.

set -euo pipefail

table=$(python - <<'PY'
import sys
from html import escape
from pathlib import Path
sys.path.insert(0, str(Path(".docs").resolve()))

import yaml
from status import metadata_for_repo, tooltip_text

data = yaml.safe_load(open("index.yml")) or {}
docs = sorted(data.get("documents") or [], key=lambda d: d["number"])
lines = [
    "| Number | Title | Repo | Status |",
    "|--------|-------|------|--------|",
]
for d in docs:
    n = f"IN-{int(d['number']):03d}"
    repo = d.get("repo", "")
    metadata = metadata_for_repo(repo) or {}
    title = str(metadata.get("name", d.get("title", ""))).replace("|", "\\|")
    repo_url = str(metadata.get("repo_url", ""))
    repo_label = repo_url.removeprefix("https://github.com/").rstrip("/")
    if not repo_url:
        repo_url = f"https://github.com/{repo}" if repo else ""
        repo_label = repo
    repo_md = f"[`{repo_label}`]({repo_url})" if repo_url else ""
    status = str(metadata.get("status", d.get("status", "")))
    tooltip = tooltip_text(metadata)
    if tooltip:
        tooltip_attr = escape(
            tooltip.replace("\n", " | "), quote=True
        ).replace("|", "&#124;")
        number_label = (
            f'<abbr class="in-index-entry" title="{tooltip_attr}" '
                        f'data-tooltip="{tooltip_attr}" tabindex="0" '
                        f'aria-label="{tooltip_attr}">{n}</abbr>'
        )
    else:
        number_label = n
    lines.append(f"| {number_label} | {title} | {repo_md} | {status} |")
print("\n".join(lines))
PY
)

python - "$table" <<'PY'
import re, sys, pathlib

table = sys.argv[1]
p = pathlib.Path("README.md")
text = p.read_text()
pattern = re.compile(
    r"(<!-- INDEX-START -->\n).*?(\n<!-- INDEX-END -->)",
    re.DOTALL,
)
comment = "<!-- This table is regenerated from index.yml and published spec.json metadata by .github/scripts/regenerate-readme.sh -->\n\n"
replacement = r"\g<1>" + comment + table + "\n" + r"\g<2>"
new = pattern.sub(replacement, text)
if new != text:
    p.write_text(new)
    print("Updated README.md index table.")
else:
    print("README.md index table already up to date.")
PY
