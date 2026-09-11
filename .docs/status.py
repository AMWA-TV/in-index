"""Read published specification metadata for the Increment index."""

from __future__ import annotations

import json
import os
import re
from html import escape
from typing import Any
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen

import yaml


PRODUCTION_BASE_URL = "https://specs.amwa.tv"
STAGING_BASE_URL = f"{PRODUCTION_BASE_URL}/new"


def _base_urls() -> list[str]:
    configured = os.environ.get("SPEC_BASE_URL", PRODUCTION_BASE_URL).rstrip("/")
    bases = [configured]
    # The current documentation rollout publishes under /new/. Keep this
    # fallback so the index can use the same source before production cutover.
    if configured == PRODUCTION_BASE_URL:
        bases.append(STAGING_BASE_URL)
    return list(dict.fromkeys(bases))


def _read_spec(url: str) -> dict[str, Any] | None:
    request = Request(url, headers={"User-Agent": "AMWA-TV/in-index"})
    try:
        with urlopen(request, timeout=10) as response:
            data = json.load(response)
    except (HTTPError, URLError, TimeoutError, OSError, json.JSONDecodeError):
        return None
    return data if isinstance(data, dict) else None


def _read_source_spec(url: str) -> dict[str, Any] | None:
    request = Request(url, headers={"User-Agent": "AMWA-TV/in-index"})
    try:
        with urlopen(request, timeout=10) as response:
            data = yaml.safe_load(response.read().decode("utf-8"))
    except (HTTPError, URLError, TimeoutError, OSError, yaml.YAMLError):
        return None
    return data if isinstance(data, dict) else None


def _read_readme(url: str) -> str | None:
    request = Request(url, headers={"User-Agent": "AMWA-TV/in-index"})
    try:
        with urlopen(request, timeout=10) as response:
            return response.read().decode("utf-8")
    except (HTTPError, URLError, TimeoutError, OSError, UnicodeDecodeError):
        return None


_INTRO_HEADINGS = {
    "What does it do?": "what_does_it_do",
    "Why does it matter?": "why_does_it_matter",
    "How does it work?": "how_does_it_work",
}


def _readme_intro(text: str) -> dict[str, list[str]]:
    """Extract the three standard README intro bullet lists."""

    if "<!-- INTRO-START -->" in text:
        text = text.split("<!-- INTRO-START -->", 1)[1]
    if "<!-- INTRO-END -->" in text:
        text = text.split("<!-- INTRO-END -->", 1)[0]

    intro: dict[str, list[str]] = {}
    current: str | None = None
    for line in text.splitlines():
        heading = re.match(r"^###\s+(.+?)\s*$", line)
        if heading:
            current = _INTRO_HEADINGS.get(heading.group(1))
            if current:
                intro[current] = []
            continue
        bullet = re.match(r"^\s*-\s+(.+?)\s*$", line)
        if current and bullet:
            intro[current].append(bullet.group(1))

    return {key: values for key, values in intro.items() if values}


def _with_intro(data: dict[str, Any], repo: str) -> dict[str, Any]:
    """Add README intro metadata when older spec.json lacks it."""

    if isinstance(data.get("intro"), dict) and any(data["intro"].values()):
        return data

    branch = str(data.get("default_branch", "main"))
    readme = _read_readme(
        f"https://raw.githubusercontent.com/{repo}/{branch}/README.md"
    )
    if not readme:
        return data

    intro = _readme_intro(readme)
    if not intro:
        return data

    enriched = dict(data)
    enriched["intro"] = intro
    return enriched


def metadata_for_repo(repo: str) -> dict[str, Any] | None:
    """Return published repository metadata, including README intro bullets."""

    repo_name = repo.rsplit("/", 1)[-1]
    if not repo_name:
        return None

    for base_url in _base_urls():
        data = _read_spec(f"{base_url}/{repo_name}/spec.json")
        if data is not None:
            return _with_intro(data, repo)

    # Use the source metadata while a repository is waiting for its first
    # Zensical deployment. This is still remote, so the index never needs a
    # local checkout of the Increment repository.
    data = _read_source_spec(
        f"https://raw.githubusercontent.com/{repo}/main/spec.yml"
    )
    return _with_intro(data, repo) if data is not None else None


def _plain_text(value: Any) -> str:
    """Remove Markdown constructs that are unsafe inside an HTML attribute."""

    text = str(value).strip()
    text = re.sub(r"\[([^\]]+)\]\([^)]+\)", r"\1", text)
    text = re.sub(r"`([^`]+)`", r"\1", text)
    return text


def tooltip_sections(
    metadata: dict[str, Any],
) -> tuple[str, list[tuple[str, list[str]]]] | None:
    """Return the name and structured README intro sections for an Increment."""

    name = _plain_text(metadata.get("name", ""))
    intro = metadata.get("intro")
    if not name or not isinstance(intro, dict):
        return None

    sections = (
        ("What does it do?", "what_does_it_do"),
        ("Why does it matter?", "why_does_it_matter"),
        ("How does it work?", "how_does_it_work"),
    )
    result: list[tuple[str, list[str]]] = []
    for heading, key in sections:
        bullets = intro.get(key)
        if not isinstance(bullets, list):
            continue
        cleaned = [_plain_text(bullet) for bullet in bullets if _plain_text(bullet)]
        if cleaned:
            result.append((heading, cleaned))

    return (name, result) if result else None


def tooltip_text(metadata: dict[str, Any]) -> str | None:
    """Return the human-readable hover text for an Increment table entry."""

    sections = tooltip_sections(metadata)
    if not sections:
        return None

    name, section_data = sections
    lines = [name]
    for heading, bullets in section_data:
        lines.extend(["", heading])
        lines.extend(f"• {bullet}" for bullet in bullets)
    return "\n".join(lines)


def tooltip_html(metadata: dict[str, Any]) -> str | None:
    """Return structured, escaped HTML for the custom table tooltip."""

    sections = tooltip_sections(metadata)
    if not sections:
        return None

    def safe(value: str) -> str:
        return escape(value).replace("|", "&#124;")

    name, section_data = sections
    parts = [f'<span class="in-index-tooltip-title">{safe(name)}</span>']
    for heading, bullets in section_data:
        parts.append(
            f'<span class="in-index-tooltip-heading">{safe(heading)}</span>'
        )
        parts.extend(
            f'<span class="in-index-tooltip-item">• {safe(bullet)}</span>'
            for bullet in bullets
        )
    return "".join(parts)

