#!/usr/bin/env python3
"""Generate the Zensical/MkDocs source tree for the IN document index.

Reads `index.yml` (the authoritative record of issued IN documents) and
writes a single landing page into `build/docs/index.md`. Kept intentionally
minimal — one page, one table — to match the current information density
of the index. When we want per-document pages, tags, or filtering, we can
grow this along the lines of ../nmos/.docs/build_index.py.
"""

from __future__ import annotations

from pathlib import Path
import yaml

ROOT = Path(__file__).resolve().parent.parent
INDEX_YML = ROOT / "index.yml"
DOCS_OUT = ROOT / "build" / "docs"


def load_index() -> dict:
    with INDEX_YML.open() as f:
        return yaml.safe_load(f) or {}


def render_index(data: dict) -> str:
    docs = sorted(data.get("documents") or [], key=lambda d: int(d["number"]))
    last = int(data.get("last_assigned", 0))

    lines: list[str] = [
        "# AMWA Increment (IN) Documents",
        "",
        "AMWA **Increment Documents** (IN-xxx) record incremental outputs of",
        "AMWA activity phases. They may stand on their own or be referenced",
        "by other AMWA documents such as the NMOS specifications.",
        "",
        "The authoritative machine-readable index is",
        "[`index.yml`](https://github.com/AMWA-TV/in-index/blob/main/index.yml)",
        "in the [`AMWA-TV/in-index`](https://github.com/AMWA-TV/in-index)",
        "repository. New documents are created via a Pull Request on that repo;",
        "see its [CONTRIBUTING.md](https://github.com/AMWA-TV/in-index/blob/main/CONTRIBUTING.md)",
        "for the process.",
        "",
        "## Issued documents",
        "",
    ]

    if not docs:
        lines.append("_No IN documents have been issued yet._")
    else:
        lines += [
            "| Number | Title | Repository | Site | Status |",
            "|--------|-------|------------|------|--------|",
        ]
        for d in docs:
            n = int(d["number"])
            padded = f"IN-{n:03d}"
            repo = d.get("repo", "")
            slug = repo.split("/", 1)[-1] if repo else f"in-{n:03d}"
            title = str(d.get("title", "")).replace("|", "\\|")
            repo_md = f"[`{repo}`](https://github.com/{repo})" if repo else ""
            # Site URL uses the staging path while zensical rollout is underway.
            site_md = f"[specs.amwa.tv/new/{slug}](https://specs.amwa.tv/new/{slug}/)"
            status = str(d.get("status", ""))
            lines.append(
                f"| {padded} | {title} | {repo_md} | {site_md} | {status} |"
            )

    lines += [
        "",
        "---",
        "",
        f"_Highest number ever assigned: **{last}**. Numbers are monotonic and are_",
        "_never re-used or back-filled — withdrawn documents retain their number._",
        "",
    ]
    return "\n".join(lines) + "\n"


def main() -> None:
    data = load_index()
    DOCS_OUT.mkdir(parents=True, exist_ok=True)
    (DOCS_OUT / "index.md").write_text(render_index(data), encoding="utf-8")
    print(f"Wrote {DOCS_OUT / 'index.md'}")


if __name__ == "__main__":
    main()
