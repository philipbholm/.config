import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


SCRIPT = Path(__file__).resolve().parents[1] / "lib/stack-images.py"
spec = importlib.util.spec_from_file_location("stack_images", SCRIPT)
stack_images = importlib.util.module_from_spec(spec)
spec.loader.exec_module(stack_images)


class StackImagesTest(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.repo = self.root / "repo"
        self.repo.mkdir()
        subprocess.run(["git", "init", "-q", str(self.repo)], check=True)
        self.write(".gitignore", "node_modules/\n.env\n")
        self.write("services/registries/Dockerfile.dev", "FROM node:24\nCOPY services/registries /app/services/registries\nCOPY services/admin/api /app/services/admin/api\n")
        self.write("services/registries/prisma.config.ts", 'schema: "prisma/schema.prisma"\n')
        self.write("services/registries/package-lock.json", "old dependencies\n")
        self.write("services/registries/scripts/generate-prisma.sh", "old script\n")
        self.write("services/admin/api/admin.proto", "old protocol\n")
        self.build = {"context": str(self.repo), "dockerfile": "services/registries/Dockerfile.dev"}
        self.config = {"name": "wt6-feature", "services": {
            "registries": {"build": self.build, "depends_on": {"postgres": {}}},
            "postgres": {"image": "postgres:17"},
        }}
        self.config_file = self.root / "compose.json"
        self.config_file.write_text(json.dumps(self.config))
        self.state = self.root / "state.json"
        self.images = self.root / "images.json"
        self.images.write_text("{}")
        self.log = self.root / "builds.jsonl"
        self.bin = self.root / "bin"
        self.bin.mkdir()
        docker = self.bin / "docker"
        docker.write_text(f"#!{sys.executable}\n" + '''
import json, os, sys
from pathlib import Path
args = sys.argv[1:]
images_file = Path(os.environ["TEST_IMAGES"])
images = json.loads(images_file.read_text())
if args[:2] == ["image", "inspect"]:
    if args[-1] not in images: sys.exit(1)
    print(images[args[-1]])
elif "config" in args:
    print(Path(os.environ["TEST_CONFIG"]).read_text())
elif "build" in args:
    services = args[args.index("build") + 1:]
    with open(os.environ["TEST_BUILDS"], "a") as log: log.write(json.dumps(services) + "\\n")
    if os.environ.get("TEST_BUILD_FAIL"): sys.exit(12)
    for service in services: images["wt6-feature-" + service] = "sha256:rebuilt-" + service
    images_file.write_text(json.dumps(images))
else:
    sys.exit(99)
''')
        docker.chmod(0o755)
        self.env = {**os.environ, "PATH": f"{self.bin}:{os.environ['PATH']}",
                    "TEST_IMAGES": str(self.images), "TEST_CONFIG": str(self.config_file),
                    "TEST_BUILDS": str(self.log)}

    def write(self, name, content):
        path = self.repo / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content)

    def run_check(self, *arguments):
        return subprocess.run([sys.executable, str(SCRIPT), "--state", str(self.state),
                               "--file", str(self.config_file), *arguments],
                              env=self.env, capture_output=True, text=True)

    def test_rebuild_after_prisma_config_changes_and_reuse_unchanged_image(self):
        first = self.run_check("registries")
        self.assertEqual(first.returncode, 0, first.stderr)
        self.assertEqual(self.run_check("registries").returncode, 0)
        self.assertEqual(len(self.log.read_text().splitlines()), 1)
        self.write("services/registries/prisma.config.ts", 'schema: "prisma/schema"\n')
        changed = self.run_check("registries")
        self.assertEqual(changed.returncode, 0, changed.stderr)
        self.assertEqual(len(self.log.read_text().splitlines()), 2)

    def test_include_dependencies_but_leave_postgres_only_startup_without_builds(self):
        self.config["services"]["frontend"] = {"depends_on": {"registries": {}}}
        self.config_file.write_text(json.dumps(self.config))
        self.assertEqual(self.run_check("postgres").returncode, 0)
        self.assertFalse(self.log.exists())
        self.assertEqual(self.run_check("--no-deps", "frontend").returncode, 0)
        self.assertFalse(self.log.exists())
        self.assertEqual(self.run_check("frontend").returncode, 0)
        self.assertEqual(json.loads(self.log.read_text()), ["registries"])

    def test_fail_without_recording_a_failed_build(self):
        self.env["TEST_BUILD_FAIL"] = "1"
        result = self.run_check("registries")
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(self.state.exists())

    def test_refuse_stale_images_when_building_is_disabled(self):
        result = self.run_check("--no-build", "registries")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("stale or unverified", result.stderr)
        self.assertFalse(self.log.exists())

    def test_detect_image_replacement_even_when_inputs_are_unchanged(self):
        self.assertEqual(self.run_check("registries").returncode, 0)
        self.images.write_text(json.dumps({"wt6-feature-registries": "sha256:old-image"}))
        self.assertEqual(self.run_check("registries").returncode, 0)
        self.assertEqual(len(self.log.read_text().splitlines()), 2)

    def test_hash_lockfiles_scripts_and_shared_copy_consumers(self):
        for name in ["services/registries/package-lock.json",
                     "services/registries/scripts/generate-prisma.sh",
                     "services/admin/api/admin.proto"]:
            before = stack_images.fingerprint(self.build)
            self.write(name, "changed\n")
            self.assertNotEqual(stack_images.fingerprint(self.build), before, name)

    def test_ignore_unrelated_files_and_generated_dependencies(self):
        before = stack_images.fingerprint(self.build)
        self.write("services/studies/package.json", "unrelated\n")
        self.write("services/registries/node_modules/generated.js", "generated\n")
        self.write("services/registries/.env", "local secret\n")
        self.assertEqual(stack_images.fingerprint(self.build), before)

    def test_detect_deleted_tracked_inputs(self):
        subprocess.run(["git", "-C", str(self.repo), "add", "."], check=True)
        before = stack_images.fingerprint(self.build)
        (self.repo / "services/registries/scripts/generate-prisma.sh").unlink()
        self.assertNotEqual(stack_images.fingerprint(self.build), before)


if __name__ == "__main__":
    unittest.main()
