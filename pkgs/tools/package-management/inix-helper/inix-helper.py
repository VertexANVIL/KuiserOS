#!/usr/bin/env python3
# Wrapper for `nix` commands that automatically override flake input paths
# via use of the special environment variables NIX_FLAKE_PATH_OVERRIDES and NIX_FLAKE_URL_OVERRIDES

import os
import sys
import json
import logging
import subprocess
from typing import List, Set, Mapping

def sprint(out: str):
    sys.stderr.write(out + "\n")

def resolve_metadata() -> Mapping:
    sprint(f"\033[92mFlake: Resolving metadata to check inputs...\033[0m")
    result = subprocess.run(["nix", "flake", "metadata", "--json", "--no-write-lock-file"], capture_output=True)
    if result.returncode != 0:
        return None
    return json.loads(result.stdout)

def build_url(node: Mapping) -> str:
    if not "original" in node:
        return None
    original = node["original"]
    ltype = original["type"]

    if ltype == "github":
        value = f"github:{original['owner']}/{original['repo']}"
        if "ref" in original:
            value += f"/{original['ref']}"
        return value
    elif ltype == "git":
        return f"git+{original['url']}"
    else:
        # unsupported for now
        return None

def resolve_path(tree: Mapping, curr: Mapping, path: List[str]) -> Mapping:
    """
    Resolves a flake path relative to the inputs of "curr"
    """

    # last component means it's a root
    if len(path) == 1:
        return tree[path[0]]
    
    # find and resolve the newest segment
    node = curr
    for segment in path:
        node = resolve_path(tree, node, path[1:])

    # we now have the node
    return node

def merge_url_maps(first: Mapping[str, Set[str]], second: Mapping[str, Set[str]]) -> Mapping:
    result = first.copy()
    for key, value in second.items():
        if key in result:
            result[key] = result[key].union(value)
        else:
            result[key] = value
    return result

def build_url_map(tree: Mapping, curr: Mapping, curr_path: List[str] = [], depth: int = 0) -> Mapping[str, Set[str]]:
    """
    Builds the entire tree of url -> input paths
    """
    
    nodes = {}
    for name in curr.get("inputs", {}).keys():
        path = curr_path + [name]
        node = resolve_path(tree, curr, path)
        url = build_url(node)
        if not url:
            continue

        rec_inputs = build_url_map(tree, node, path, depth)
        nodes = merge_url_maps(nodes, rec_inputs)

        path_str = "/".join(path)
        if not url in nodes:
            nodes[url] = set()
        nodes[url].add(path_str)

    return nodes

def parse_url_overrides(metadata: Mapping) -> Mapping[str, Set[str]]:
    if "NIX_FLAKE_URL_OVERRIDES" not in os.environ:
        return {}
    envvar = os.environ["NIX_FLAKE_URL_OVERRIDES"]

    lock_root = metadata["locks"]["nodes"]
    url_map = build_url_map(lock_root, lock_root["root"])

    results = {}
    for override in envvar.split(";"):
        parts = override.rsplit("=", 1)
        if len(parts) != 2:
            continue
        before = parts[0]
        after = parts[1]

        # find the inputs that correspond to this
        if not before in url_map:
            sprint(f"\033[93mFlake: The path override source \"{before}\" is not present in the lockfile, skipping.\033[0m")
            continue

        # if the override is a path and it doesn't exist, abort
        if after.startswith("path:") and not os.path.exists(after.replace("path:", "")):
            sprint(f"\033[93mFlake: The path override target \"{after}\" does not exist, skipping.\033[0m")
            continue

        sprint(f"\033[92mFlake: Overriding URL \"{before}\" to \"{after}\".\033[0m")
        results[after] = url_map[before]
    return results

def build_nix_params() -> List[str]:
    # if neither envvar is set don't bother doing anything
    if "NIX_FLAKE_PATH_OVERRIDES" not in os.environ and "NIX_FLAKE_URL_OVERRIDES" not in os.environ:
        return []

    metadata = resolve_metadata()
    if not metadata:
        return []

    params = []
    url_overrides = parse_url_overrides(metadata)
    for url, paths in url_overrides.items():
        for path in paths:
            params.extend(["--override-input", path, url])
    
    params.append("--no-write-lock-file")
    return params

params = build_nix_params()
print(";".join(params))
