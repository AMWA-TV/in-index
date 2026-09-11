#!/usr/bin/env python3
"""Generate the Zensical/MkDocs source tree for the Increment index.

Reads `index.yml` (the authoritative record of issued Increments), uses
published repository metadata for each status, and writes a single landing
page into `build/docs/index.md`. Kept intentionally minimal — one page, one
table — to match the current information density of the index. When we want
per-Increment pages, tags, or filtering, we can grow this along the lines of
../nmos/.docs/build_index.py.
"""

from __future__ import annotations

import shutil
from html import escape
from pathlib import Path

import yaml

from status import metadata_for_repo, tooltip_html, tooltip_text

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
        "# AMWA Increments (IN) Index",
        "",
        "AMWA **Increments** (IN-xxx) record incremental outputs of",
        "AMWA activity phases. They may stand on their own or be referenced",
        "by other AMWA documents such as the NMOS specifications.",
        "",
        "The authoritative machine-readable index is",
        "[`index.yml`](https://github.com/AMWA-TV/in-index/blob/main/index.yml)",
        "in the [`AMWA-TV/in-index`](https://github.com/AMWA-TV/in-index)",
        "repository. New Increments are created via a Pull Request on that repo;",
        "see its [CONTRIBUTING.md](https://github.com/AMWA-TV/in-index/blob/main/CONTRIBUTING.md)",
        "for the process.",
        "",
        "## Issued Increments",
        "",
    ]

    if not docs:
        lines.append("_No Increments have been issued yet._")
    else:
        lines += [
            '<table class="in-index-table">',
            "<thead>",
            "<tr><th>Number</th><th>Title</th><th>Repository</th>"
            "<th>Site</th><th>Status</th></tr>",
            "</thead>",
            "<tbody>",
        ]
        for d in docs:
            n = int(d["number"])
            padded = f"IN-{n:03d}"
            repo = d.get("repo", "")
            slug = repo.split("/", 1)[-1] if repo else f"in-{n:03d}"
            metadata = metadata_for_repo(repo) or {}
            title = str(metadata.get("name", d.get("title", "")))
            repo_url = str(metadata.get("repo_url", ""))
            repo_label = repo_url.removeprefix("https://github.com/").rstrip("/")
            if not repo_url:
                repo_url = f"https://github.com/{repo}" if repo else ""
                repo_label = repo
            repo_html = (
                f'<a href="{escape(repo_url, quote=True)}">'
                f"<code>{escape(repo_label)}</code></a>"
                if repo_url
                else ""
            )
            site_url = str(metadata.get("url", ""))
            if not site_url:
                # Site URL uses the staging path while zensical rollout is
                # underway and metadata is unavailable.
                site_url = f"https://specs.amwa.tv/new/{slug}/"
            site_label = site_url.removeprefix("https://").rstrip("/")
            site_html = (
                f'<a href="{escape(site_url, quote=True)}">'
                f"{escape(site_label)}</a>"
            )
            status = str(metadata.get("status", d.get("status", "")))
            tooltip = tooltip_text(metadata)
            tooltip_markup = tooltip_html(metadata)
            if tooltip and tooltip_markup:
                tooltip_attr = escape(
                    tooltip.replace("\n", " | "), quote=True
                ).replace("|", "&#124;")
                number_label = (
                    f'<abbr class="in-index-entry" tabindex="0" '
                    f'aria-label="{tooltip_attr}">{padded}'
                    f'<span class="in-index-tooltip" role="tooltip">'
                    f"{tooltip_markup}</span></abbr>"
                )
            else:
                number_label = padded
            lines.append(
                "<tr>"
                f"<td>{number_label}</td>"
                f"<td>{escape(title)}</td>"
                f"<td>{repo_html}</td>"
                f"<td>{site_html}</td>"
                f"<td>{escape(status)}</td>"
                "</tr>"
            )
        lines += ["</tbody>", "</table>"]

    # lines += [
    #     "",
    #     "---",
    #     "",
    #     f"_Highest number ever assigned: **{last}**. Numbers are monotonic and are_",
    #     "_never re-used or back-filled — withdrawn Increments retain their number._",
    #     "",
    # ]
    return "\n".join(lines) + "\n"


def main() -> None:
    data = load_index()
    DOCS_OUT.mkdir(parents=True, exist_ok=True)
    (DOCS_OUT / "index.md").write_text(render_index(data), encoding="utf-8")

    stylesheet = ROOT / "docs" / "stylesheets" / "in-index.css"
    if stylesheet.is_file():
        destination = DOCS_OUT / "stylesheets" / stylesheet.name
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(stylesheet, destination)

    print(f"Wrote {DOCS_OUT / 'index.md'}")


if __name__ == "__main__":
    main()
