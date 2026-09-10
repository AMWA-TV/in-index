"""Read published specification metadata for the Increment index."""

from __future__ import annotations

import json
import os
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


def metadata_for_repo(repo: str) -> dict[str, Any] | None:
    """Return published repository metadata, or remote source metadata."""

    repo_name = repo.rsplit("/", 1)[-1]
    if not repo_name:
        return None

    for base_url in _base_urls():
        data = _read_spec(f"{base_url}/{repo_name}/spec.json")
        if data is not None:
            return data

    # Use the source metadata while a repository is waiting for its first
    # Zensical deployment. This is still remote, so the index never needs a
    # local checkout of the Increment repository.
    return _read_source_spec(
        f"https://raw.githubusercontent.com/{repo}/main/spec.yml"
    )

