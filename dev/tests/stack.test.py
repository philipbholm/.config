import argparse
import importlib.util
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest import mock


SCRIPT = Path(__file__).resolve().parents[1] / "lib/stack.py"


def load_stack(stacks_dir, main_repo):
    with mock.patch.dict(os.environ, {"DEV_STACKS_DIR": str(stacks_dir), "DEV_MAIN_REPO": str(main_repo)}):
        spec = importlib.util.spec_from_file_location("stack", SCRIPT)
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
    return module


class StackTest(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name).resolve()
        self.repo = self.root / "repo"
        self.repo.mkdir()
        self.git("init", "-q")
        self.git("-c", "user.name=Stack Test", "-c", "user.email=stack-test@example.invalid",
                 "-c", "commit.gpgsign=false", "commit", "-q", "--allow-empty", "-m", "Create fixture")
        self.stack = load_stack(self.root / "stacks", self.repo)
        self.stack.log = lambda message: None
        for name, value in {"port_in_use": lambda port: False, "render_context": lambda root: None,
                            "read_process": lambda path: Path(path).exists() or None}.items():
            patcher = mock.patch.object(self.stack, name, value)
            patcher.start()
            self.addCleanup(patcher.stop)

    def git(self, *args):
        subprocess.run(["git", "-C", str(self.repo), *args], check=True, capture_output=True)

    def worktree(self, name):
        path = self.root / name
        self.git("worktree", "add", "-q", "-b", name, str(path))
        return self.stack.Checkout(path)

    def claim(self, stack_id, slot, running=False):
        stack_dir = self.stack.STACKS_DIR / stack_id
        (stack_dir / "pids").mkdir(parents=True)
        (stack_dir / "worktree-slot").write_text(f"{slot}\n")
        if running:
            (stack_dir / "pids" / "registries.json").write_text("{}")
        return stack_dir

    def test_database_names_stay_within_the_postgres_limit(self):
        self.assertEqual(self.stack.database_name("registries", "fix-login"), "registries_fix_login")
        long_name = self.stack.database_name("registries_test", "a" * 80)
        self.assertEqual(len(long_name), 63)
        self.assertNotEqual(long_name, self.stack.database_name("registries_test", "a" * 81))

    def test_read_one_service_environment_from_the_compose_file(self):
        compose = self.root / "docker-compose.yml"
        compose.write_text(
            "services:\n"
            "  registries:\n"
            "    image: registries\n"
            "    environment:\n"
            "      - PORT=4000\n"
            "      - TOKEN=${NPM_TOKEN:-none}  # from the host\n"
            "      - EMPTY=${UNSET_VARIABLE}\n"
            "    ports:\n"
            "      - 4006:4000\n"
            "  codelist:\n"
            "    environment:\n"
            "      - PORT=5000\n"
        )
        with mock.patch.dict(os.environ, {"NPM_TOKEN": "secret"}):
            os.environ.pop("UNSET_VARIABLE", None)
            env = self.stack.compose_environment(compose, "registries")
        self.assertEqual(env, {"PORT": "4000", "TOKEN": "secret", "EMPTY": ""})

    def test_the_main_checkout_always_uses_slot_zero(self):
        self.claim("other", 1, running=True)
        self.assertEqual(self.stack.choose_slot(self.stack.Checkout(self.repo), None), 0)

    def test_a_worktree_keeps_its_saved_slot_while_the_slot_is_free(self):
        checkout = self.worktree("feature")
        self.claim("feature", 4)
        self.assertEqual(self.stack.choose_slot(checkout, None), 4)

    def test_a_worktree_skips_slots_that_other_stacks_claim(self):
        checkout = self.worktree("feature")
        self.claim("running", 1, running=True)
        self.claim("stopped", 2)
        self.assertEqual(self.stack.choose_slot(checkout, None), 3)

    def test_a_worktree_takes_a_stopped_stack_slot_when_every_slot_is_claimed(self):
        checkout = self.worktree("feature")
        for slot in range(1, 10):
            self.claim(f"stack-{slot}", slot, running=slot != 6)
        self.assertEqual(self.stack.choose_slot(checkout, None), 6)
        self.assertFalse((self.stack.STACKS_DIR / "stack-6" / "worktree-slot").exists())

    def test_refuse_a_requested_slot_that_a_running_stack_holds(self):
        checkout = self.worktree("feature")
        self.claim("running", 2, running=True)
        with self.assertRaisesRegex(self.stack.StackError, "slot 2 is in use"):
            self.stack.choose_slot(checkout, 2)

    def test_reap_removes_only_stacks_whose_checkout_is_gone(self):
        kept = self.worktree("kept")
        gone = self.worktree("gone")
        for checkout in (kept, gone):
            checkout.stack_dir.mkdir(parents=True)
            (checkout.stack_dir / "checkout").write_text(f"{checkout.root}\n")
        self.git("worktree", "remove", str(gone.root))
        dropped = []
        with mock.patch.object(self.stack, "drop_checkout_databases", lambda checkout: dropped.append(checkout.id)), \
             mock.patch.object(self.stack, "postgres_running", lambda: False):
            self.stack.command_reap(argparse.Namespace(dry_run=False))
        self.assertEqual(dropped, ["gone"])
        self.assertTrue(kept.stack_dir.exists())
        self.assertFalse(gone.stack_dir.exists())

    def test_reap_removes_nothing_when_the_worktree_list_fails(self):
        checkout = self.worktree("feature")
        checkout.stack_dir.mkdir(parents=True)
        (checkout.stack_dir / "checkout").write_text(f"{checkout.root}\n")
        stack = load_stack(self.root / "stacks", self.root / "missing")
        with self.assertRaises(stack.StackError):
            stack.command_reap(argparse.Namespace(dry_run=False))
        self.assertTrue(checkout.stack_dir.exists())


if __name__ == "__main__":
    unittest.main()
