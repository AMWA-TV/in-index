#!/usr/bin/env bash
#
# Rewrite the "Issued increments" table in README.md from index.yml.
# Idempotent: no-ops if the table already matches.

set -euo pipefail

table=$(python - <<'PY'
import yaml
data = yaml.safe_load(open("index.yml")) or {}
docs = sorted(data.get("documents") or [], key=lambda d: d["number"])
lines = [
    "| Number | Title | Repo | Status |",
    "|--------|-------|------|--------|",
]
for d in docs:
    n = f"IN-{int(d['number']):03d}"
    title = d.get("title", "").replace("|", "\\|")
    repo = d.get("repo", "")
    repo_md = f"[`{repo}`](https://github.com/{repo})" if repo else ""
    status = d.get("status", "")
    lines.append(f"| {n} | {title} | {repo_md} | {status} |")
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
comment = "<!-- This table is regenerated from index.yml by .github/scripts/regenerate-readme.sh -->\n\n"
replacement = r"\g<1>" + comment + table + "\n" + r"\g<2>"
new = pattern.sub(replacement, text)
if new != text:
    p.write_text(new)
    print("Updated README.md index table.")
else:
    print("README.md index table already up to date.")
PY
