"""Rebuild local Compose images when their checkout inputs or image IDs change."""

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shlex
import subprocess
import sys
import tempfile


def output(command):
    return subprocess.check_output(command, text=True).strip()


def copy_sources(dockerfile):
    sources = []
    for line in re.sub(r"\\\n", " ", dockerfile).splitlines():
        parts = line.split(None, 1)
        if len(parts) != 2:
            continue
        instruction, arguments = parts
        if instruction.upper() not in {"COPY", "ADD"}:
            continue
        if "$" in arguments or arguments.startswith("--"):
            return ["."]
        parts = json.loads(arguments) if arguments.startswith("[") else shlex.split(arguments)
        sources.extend(parts[:-1])
    return sources


def fingerprint(build):
    context = Path(build["context"]).resolve()
    dockerfile = context / build.get("dockerfile", "Dockerfile")
    source_text = build.get("dockerfile_inline")
    if source_text is None:
        source_text = dockerfile.read_text()
    sources = copy_sources(source_text)
    if build.get("additional_contexts"):
        raise ValueError("image freshness checks do not support additional build contexts")
    # Build-time bind mounts can consume files beyond the COPY instructions.
    if "type=bind" in source_text:
        sources = ["."]
    files = subprocess.check_output([
        "git", "-C", str(context), "ls-files", "-z", "--cached", "--others",
        "--exclude-standard", "--", *sources,
    ], text=True).split("\0") if sources else []
    paths = {context / name for name in files if name}
    paths.update({dockerfile, context / ".dockerignore", Path(str(dockerfile) + ".dockerignore")})
    digest = hashlib.sha256()
    digest.update(json.dumps(build, sort_keys=True).encode())
    digest.update(source_text.encode())
    for path in sorted(paths):
        digest.update(str(path).encode() + b"\0")
        if path.is_symlink():
            digest.update(os.readlink(path).encode())
        elif path.is_file():
            digest.update(str(path.stat().st_mode & 0o777).encode())
            digest.update(path.read_bytes())
        else:
            digest.update(b"missing")
        digest.update(b"\0")
    return digest.hexdigest()


def selected_services(services, requested, include_dependencies):
    selected = set()

    def visit(name):
        if name in selected:
            return
        if name not in services:
            raise ValueError(f"unknown Compose service: {name}")
        selected.add(name)
        if include_dependencies:
            for dependency in services[name].get("depends_on", {}):
                visit(dependency)

    for name in requested:
        visit(name)
    return sorted(selected)


def image_id(name):
    result = subprocess.run(
        ["docker", "image", "inspect", "--format", "{{.Id}}", name],
        capture_output=True, text=True,
    )
    return result.stdout.strip() if result.returncode == 0 else None


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--state", required=True, type=Path)
    parser.add_argument("--file", action="append", required=True)
    parser.add_argument("--no-build", action="store_true")
    parser.add_argument("--no-deps", action="store_true")
    parser.add_argument("services", nargs="+")
    args = parser.parse_args()
    compose = ["docker", "compose"]
    for file in args.file:
        compose.extend(["-f", file])
    config = json.loads(output([*compose, "config", "--format", "json"]))
    services = config["services"]
    selected = selected_services(services, args.services, not args.no_deps)
    previous = json.loads(args.state.read_text()) if args.state.exists() else {}
    inputs = {}
    images = {}
    stale = []
    for name in selected:
        build = services[name].get("build")
        if not build:
            continue
        inputs[name] = fingerprint(build)
        images[name] = services[name].get("image") or f"{config['name']}-{name}"
        current_id = image_id(images[name])
        if not current_id or previous.get(name) != {"inputs": inputs[name], "image": current_id}:
            stale.append(name)
    if not stale:
        return
    if args.no_build:
        raise ValueError(f"stale or unverified images: {', '.join(stale)}. Rerun dev stack up without --no-build")
    print(f"Rebuilding stale or unverified images: {', '.join(stale)}", flush=True)
    subprocess.run([*compose, "build", *stale], check=True)
    for name in stale:
        current_id = image_id(images[name])
        if not current_id:
            raise ValueError(f"build did not produce an image for {name}")
        if fingerprint(services[name]["build"]) != inputs[name]:
            raise ValueError(f"build inputs changed while building {name}. Rerun dev stack up")
        previous[name] = {"inputs": inputs[name], "image": current_id}
    args.state.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(mode="w", dir=args.state.parent, delete=False) as temporary:
        json.dump(previous, temporary, indent=2)
        temporary.write("\n")
    Path(temporary.name).replace(args.state)


if __name__ == "__main__":
    try:
        main()
    except (ValueError, OSError, subprocess.CalledProcessError) as error:
        sys.exit(f"Error: {error}")
