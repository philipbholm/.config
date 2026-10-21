import argparse
import contextlib
import ctypes
import fcntl
import hashlib
import json
import os
import re
import shlex
import shutil
import signal
import socket
import subprocess
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

DEV_DIR = Path(__file__).resolve().parent.parent
STACKS_DIR = Path(os.environ.get("DEV_STACKS_DIR", Path.home() / "work" / ".dev-stacks"))
SHARED_DIR = STACKS_DIR / ".shared"
MAIN_REPO = Path(os.environ.get("DEV_MAIN_REPO", Path.home() / "work" / "ledidi-monorepo"))
SCRIPTS_DIR = Path(os.environ.get("DEV_SCRIPTS_DIR", Path.home() / "work" / "scripts"))
PG_BIN = Path(os.environ.get("DEV_PG_BIN", "/opt/homebrew/opt/postgresql@17/bin"))
PG_DATA = SHARED_DIR / "postgres"
PG_PORT = 5432
PG_SUPERUSER = "postgres"
PG_PASSWORD = "postgres"
APP_ROLE = "registries_app_user"
APP_PASSWORD = "password"
ADMIN_MOCK_DIR = DEV_DIR / "admin-mock"
ADMIN_MOCK_GRAPHQL_PORT = 4054
ADMIN_MOCK_GRPC_PORT = 50004
S3_ENDPOINT = "http://localhost:9090"
IDLE_LIMIT_SECONDS = int(os.environ.get("DEV_STACK_IDLE_SECONDS", 2 * 60 * 60))

FRONTEND_BASE_PORT = 3003
CODELIST_BASE_PORT = 4005
CODELIST_GRPC_BASE_PORT = 50005
REGISTRIES_BASE_PORT = 4006
REGISTRIES_GRPC_BASE_PORT = 50006
SHELL_BASE_PORT = 3010

SERVICES = ("registries", "registries-frontend", "codelist")
DEFAULT_SERVICES = ("registries", "registries-frontend")
WORKSPACES = {
    "registries": "services/registries",
    "registries-frontend": "apps/registries-frontend",
    "codelist": "services/codelist",
}


class StackError(Exception):
    pass


def log(message):
    print(message, flush=True)


def slugify(name):
    slug = name.lower().replace("/", "-")
    slug = re.sub(r"[^a-z0-9_-]", "-", slug)
    slug = re.sub(r"-+", "-", slug).strip("-")
    return slug or "workspace"


def database_name(prefix, checkout_id):
    name = f"{prefix}_{re.sub(r'[^a-z0-9_]', '_', checkout_id)}"
    if len(name) <= 63:
        return name
    digest = hashlib.sha1(name.encode()).hexdigest()[:8]
    return f"{name[:54]}_{digest}"


def offset_for(slot):
    return slot * 100


class Checkout:
    def __init__(self, root):
        self.root = Path(root)
        self.is_worktree = (self.root / ".git").is_file()
        self.id = slugify(self.root.name)
        self.stack_dir = STACKS_DIR / self.id
        self.slot_file = self.stack_dir / "worktree-slot"
        self.registries_db = database_name("registries", self.id)
        self.test_db = database_name("registries_test", self.id)
        self.codelist_db = database_name("codelist", self.id)

    @classmethod
    def current(cls):
        try:
            root = subprocess.run(
                ["git", "rev-parse", "--show-toplevel"],
                check=True, capture_output=True, text=True,
            ).stdout.strip()
        except subprocess.CalledProcessError:
            raise StackError("not inside a Git checkout")
        checkout = cls(root)
        if not (checkout.root / "docker-compose.yml").is_file():
            raise StackError(f"{checkout.root} is not a Ledidi monorepo checkout (no docker-compose.yml)")
        return checkout

    def saved_slot(self):
        try:
            value = self.slot_file.read_text().strip()
        except FileNotFoundError:
            return None
        return int(value) if re.fullmatch(r"[0-9]", value) else None

    def pid_file(self, service):
        return self.stack_dir / "pids" / f"{service}.json"

    def log_file(self, service):
        return self.stack_dir / "logs" / f"{service}.log"

    def running_services(self):
        return [service for service in SERVICES if read_process(self.pid_file(service))]


def stack_dirs():
    if not STACKS_DIR.is_dir():
        return []
    return sorted(path for path in STACKS_DIR.iterdir() if path.is_dir() and not path.name.startswith("."))


def recorded_checkout(stack_dir):
    try:
        return Path((stack_dir / "checkout").read_text().strip())
    except FileNotFoundError:
        return None


def ports_for(slot):
    offset = offset_for(slot)
    return {
        "frontend": FRONTEND_BASE_PORT + offset,
        "e2e_frontend": FRONTEND_BASE_PORT + 1 + offset,
        "shell": SHELL_BASE_PORT + offset,
        "registries": REGISTRIES_BASE_PORT + offset,
        "registries_grpc": REGISTRIES_GRPC_BASE_PORT + offset,
        "codelist": CODELIST_BASE_PORT + offset,
        "codelist_grpc": CODELIST_GRPC_BASE_PORT + offset,
    }


def service_ports(service, slot):
    ports = ports_for(slot)
    return {
        "registries": [ports["registries"], ports["registries_grpc"]],
        "registries-frontend": [ports["frontend"]],
        "codelist": [ports["codelist"], ports["codelist_grpc"]],
    }[service]


def port_in_use(port):
    for host in ("127.0.0.1", "::1"):
        family = socket.AF_INET6 if ":" in host else socket.AF_INET
        with socket.socket(family, socket.SOCK_STREAM) as probe:
            probe.settimeout(0.2)
            try:
                if probe.connect_ex((host, port)) == 0:
                    return True
            except OSError:
                continue
    return False


def port_owner(port):
    result = subprocess.run(
        ["lsof", "-nP", f"-iTCP:{port}", "-sTCP:LISTEN"],
        capture_output=True, text=True,
    )
    lines = result.stdout.strip().splitlines()[1:]
    return lines[0].split()[0] + f" (pid {lines[0].split()[1]})" if lines else "an unknown process"


@contextlib.contextmanager
def file_lock(name):
    SHARED_DIR.mkdir(parents=True, exist_ok=True)
    with open(SHARED_DIR / f"{name}.lock", "w") as handle:
        fcntl.flock(handle, fcntl.LOCK_EX)
        try:
            yield
        finally:
            fcntl.flock(handle, fcntl.LOCK_UN)


def process_start_time(pid):
    result = subprocess.run(["ps", "-o", "lstart=", "-p", str(pid)], capture_output=True, text=True)
    return result.stdout.strip() or None


def read_process(path):
    try:
        record = json.loads(Path(path).read_text())
    except (FileNotFoundError, json.JSONDecodeError):
        return None
    if process_start_time(record["pid"]) != record.get("started"):
        return None
    return record


def spawn(command, cwd, env, log_path, pid_path):
    log_path.parent.mkdir(parents=True, exist_ok=True)
    pid_path.parent.mkdir(parents=True, exist_ok=True)
    with open(log_path, "wb") as output:
        process = subprocess.Popen(
            ["/bin/bash", "-c", command],
            cwd=cwd, env=env, stdin=subprocess.DEVNULL,
            stdout=output, stderr=subprocess.STDOUT, start_new_session=True,
        )
    record = {"pid": process.pid, "started": process_start_time(process.pid), "command": command}
    pid_path.write_text(json.dumps(record))
    return record


def stop_process(path, timeout=20):
    record = read_process(path)
    Path(path).unlink(missing_ok=True)
    if not record:
        return False
    pgid = record["pid"]
    with contextlib.suppress(ProcessLookupError):
        os.killpg(pgid, signal.SIGTERM)
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        with contextlib.suppress(ChildProcessError):
            os.waitpid(pgid, os.WNOHANG)
        try:
            os.killpg(pgid, 0)
        except (ProcessLookupError, PermissionError):
            return True
        time.sleep(0.2)
    with contextlib.suppress(ProcessLookupError):
        os.killpg(pgid, signal.SIGKILL)
    return True


def psql(sql, database="postgres", check=True):
    result = subprocess.run(
        [str(PG_BIN / "psql"), "-h", "localhost", "-p", str(PG_PORT), "-U", PG_SUPERUSER,
         "-d", database, "-v", "ON_ERROR_STOP=1", "-Atq", "-c", sql],
        capture_output=True, text=True,
        env={**os.environ, "PGPASSWORD": PG_PASSWORD},
    )
    if check and result.returncode != 0:
        raise StackError(f"psql failed: {result.stderr.strip()}")
    return result.stdout.strip()


def quote_literal(value):
    return "'" + value.replace("'", "''") + "'"


def database_exists(name):
    return psql(f"SELECT 1 FROM pg_database WHERE datname = {quote_literal(name)}") == "1"


def drop_database(name):
    psql(f'DROP DATABASE IF EXISTS "{name}" WITH (FORCE)')


def postgres_url(database, user=PG_SUPERUSER, password=PG_PASSWORD):
    return f"postgresql://{user}:{password}@localhost:{PG_PORT}/{database}"


POSTGRES_SETTINGS = """
listen_addresses = 'localhost'
port = 5432
max_connections = 400
shared_buffers = 256MB
fsync = off
synchronous_commit = off
full_page_writes = off
"""


def postgres_running():
    return subprocess.run(
        [str(PG_BIN / "pg_ctl"), "-D", str(PG_DATA), "status"],
        capture_output=True,
    ).returncode == 0


def ensure_postgres():
    if not (PG_BIN / "postgres").exists():
        raise StackError(f"PostgreSQL 17 is not installed at {PG_BIN}. Run: brew install postgresql@17")
    with file_lock("postgres"):
        if not (PG_DATA / "PG_VERSION").exists():
            log(f"Creating the shared PostgreSQL cluster in {PG_DATA}...")
            PG_DATA.mkdir(parents=True, exist_ok=True)
            subprocess.run(
                [str(PG_BIN / "initdb"), "-D", str(PG_DATA), "-U", PG_SUPERUSER, "--auth=trust",
                 "-E", "UTF8", "--locale=en_US.UTF-8"],
                check=True, stdout=subprocess.DEVNULL,
            )
            with open(PG_DATA / "postgresql.conf", "a") as conf:
                conf.write(POSTGRES_SETTINGS)
        if not postgres_running():
            if port_in_use(PG_PORT):
                raise StackError(f"port {PG_PORT} is taken by {port_owner(PG_PORT)}; stop it so the shared PostgreSQL can start")
            log("Starting the shared PostgreSQL...")
            subprocess.run(
                [str(PG_BIN / "pg_ctl"), "-D", str(PG_DATA), "-l", str(SHARED_DIR / "postgres.log"), "-w", "start"],
                check=True, stdout=subprocess.DEVNULL, env={**os.environ, "LC_ALL": "en_US.UTF-8"},
            )
        psql(
            "DO $$ BEGIN "
            f"IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = '{APP_ROLE}') THEN "
            f"CREATE ROLE {APP_ROLE} LOGIN PASSWORD '{APP_PASSWORD}'; "
            "END IF; END $$"
        )


def ensure_admin_mock():
    pid_path = SHARED_DIR / "admin-mock.json"
    with file_lock("admin-mock"):
        if read_process(pid_path) and port_in_use(ADMIN_MOCK_GRPC_PORT):
            return
        for port in (ADMIN_MOCK_GRAPHQL_PORT, ADMIN_MOCK_GRPC_PORT):
            if port_in_use(port):
                raise StackError(f"admin mock port {port} is taken by {port_owner(port)}")
        if not (ADMIN_MOCK_DIR / "node_modules").is_dir():
            log("Installing admin mock dependencies...")
            subprocess.run(["npm", "ci", "--loglevel=warn"], cwd=ADMIN_MOCK_DIR, check=True)
        log("Starting the admin mock...")
        env = {
            **os.environ,
            "ADMIN_MOCK_GRAPHQL_PORT": str(ADMIN_MOCK_GRAPHQL_PORT),
            "ADMIN_MOCK_GRPC_PORT": str(ADMIN_MOCK_GRPC_PORT),
        }
        spawn("exec node build/index.js", ADMIN_MOCK_DIR, env, SHARED_DIR / "admin-mock.log", pid_path)
        wait_for(lambda: port_in_use(ADMIN_MOCK_GRPC_PORT) and port_in_use(ADMIN_MOCK_GRAPHQL_PORT),
                 30, "admin mock", SHARED_DIR / "admin-mock.log", pid_path)


def wait_for(condition, timeout, name, log_path, pid_path):
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        if condition():
            return
        if not read_process(pid_path):
            raise StackError(f"{name} exited during startup:\n{tail(log_path, 40)}")
        time.sleep(1)
    raise StackError(f"{name} was not ready after {timeout}s:\n{tail(log_path, 40)}")


def tail(path, lines):
    try:
        return "\n".join(Path(path).read_text(errors="replace").splitlines()[-lines:])
    except FileNotFoundError:
        return "(no log)"


INTERPOLATION = re.compile(r"\$\{([A-Za-z_][A-Za-z0-9_]*)(?::?-([^}]*))?\}")


def compose_environment(compose_file, service):
    lines = Path(compose_file).read_text().splitlines()
    env = {}
    in_services = in_service = in_environment = False
    for line in lines:
        stripped = line.strip()
        if not stripped or stripped.startswith("#"):
            continue
        indent = len(line) - len(line.lstrip(" "))
        if indent == 0:
            in_services = stripped == "services:"
            in_service = in_environment = False
            continue
        if not in_services:
            continue
        if indent == 2:
            in_service = stripped == f"{service}:"
            in_environment = False
            continue
        if not in_service:
            continue
        if indent == 4:
            in_environment = stripped == "environment:"
            continue
        if in_environment and stripped.startswith("- "):
            entry = re.sub(r"\s+#.*$", "", stripped[2:].strip())
            key, _, value = entry.partition("=")
            env[key] = INTERPOLATION.sub(lambda match: os.environ.get(match.group(1)) or (match.group(2) or ""), value)
    if not env:
        raise StackError(f"no environment for {service} in {compose_file}")
    return env


def service_spec(checkout, service, slot):
    spec = base_service_spec(checkout, service, slot)
    try:
        overrides = json.loads((checkout.stack_dir / "overrides.json").read_text()).get(service, {})
    except FileNotFoundError:
        return spec
    spec["env"].update(overrides.get("env", {}))
    if overrides.get("vite_config"):
        spec["command"] += f" --config {shlex.quote(overrides['vite_config'])}"
    return spec


def base_service_spec(checkout, service, slot):
    ports = ports_for(slot)
    compose = checkout.root / "docker-compose.yml"
    base_env = {key: value for key, value in os.environ.items() if not key.startswith(("POSTGRES_", "VITE_"))}
    frontend_url = f"http://localhost:{ports['frontend']}"
    registries_url = f"http://localhost:{ports['registries']}"
    if service == "registries":
        env = compose_environment(compose, "registries")
        env.update({
            "POSTGRES_HOST": "localhost",
            "POSTGRES_APP_HOST": "localhost",
            "POSTGRES_PORT": str(PG_PORT),
            "POSTGRES_DATABASE": checkout.registries_db,
            "POSTGRES_USER": PG_SUPERUSER,
            "POSTGRES_PASSWORD": PG_PASSWORD,
            "POSTGRES_APP_USER": APP_ROLE,
            "POSTGRES_APP_PASSWORD": APP_PASSWORD,
            "GRAPHQL_PORT": str(ports["registries"]),
            "GRPC_PORT": str(ports["registries_grpc"]),
            "ADMIN_SERVICE_GRPC_ADDRESS": f"localhost:{ADMIN_MOCK_GRPC_PORT}",
            "CODELIST_SERVICE_GRPC_ADDRESS": f"localhost:{ports['codelist_grpc']}",
            "REGISTRIES_SERVICE_GRPC_ADDRESS": f"localhost:{ports['registries_grpc']}",
            "AWS_ENDPOINT_URL_S3": S3_ENDPOINT,
            "S3_PRESIGN_ENDPOINT_URL": S3_ENDPOINT,
            "FRONTEND_URL": frontend_url,
            "ALLOWED_ORIGINS": ",".join(
                f"http://localhost:{port}" for port in (ports["frontend"], ports["e2e_frontend"], ports["shell"])
            ),
            "PROM_RATE_LIMIT_MAX": "10000",
        })
        return {
            "cwd": checkout.root / WORKSPACES[service],
            "command": "exec npm run dev",
            "env": {**base_env, **env},
            "ready": lambda: http_ok(f"{registries_url}/health"),
            "timeout": 900,
        }
    if service == "registries-frontend":
        env = compose_environment(compose, "registries-frontend")
        env.update({
            "PORT": str(ports["frontend"]),
            "VITE_APP_URL": frontend_url,
            "VITE_GRAPHQL_URI": f"{registries_url}/graphql",
            "VITE_GRAPHQL_PROM_URI": f"{registries_url}/graphql-prom",
            "VITE_REGISTRIES_API_URL": registries_url,
            "VITE_ADMIN_GRAPHQL_URI": f"http://localhost:{ADMIN_MOCK_GRAPHQL_PORT}/graphql",
        })
        if checkout.is_worktree:
            env["VITE_WORKTREE_ID"] = str(slot)
        return {
            "cwd": checkout.root / WORKSPACES[service],
            "command": f"npm run generate && exec npx vite dev --port {ports['frontend']} --strictPort",
            "env": {**base_env, **env},
            "ready": lambda: http_ok(frontend_url),
            "timeout": 600,
        }
    if service == "codelist":
        env = compose_environment(compose, "codelist")
        env.update({
            "POSTGRES_HOST": "localhost",
            "POSTGRES_PORT": str(PG_PORT),
            "POSTGRES_DATABASE": checkout.codelist_db,
            "POSTGRES_USER": PG_SUPERUSER,
            "POSTGRES_PASSWORD": PG_PASSWORD,
            "GRAPHQL_PORT": str(ports["codelist"]),
            "GRPC_PORT": str(ports["codelist_grpc"]),
        })
        return {
            "cwd": checkout.root / WORKSPACES[service],
            "command": "exec npm run dev",
            "env": {**base_env, **env},
            "ready": lambda: port_in_use(ports["codelist_grpc"]),
            "timeout": 600,
        }
    raise StackError(f"unknown service: {service}")


def http_ok(url):
    try:
        with urllib.request.urlopen(url, timeout=2) as response:
            return response.status < 500
    except urllib.error.HTTPError as error:
        return error.code < 500
    except (urllib.error.URLError, OSError):
        return False


def file_hash(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def installed_matches_lockfile(directory):
    try:
        wanted = json.loads((directory / "package-lock.json").read_text())["packages"]
        installed = json.loads((directory / "node_modules" / ".package-lock.json").read_text())["packages"]
    except (FileNotFoundError, KeyError, json.JSONDecodeError):
        return False
    for name, entry in wanted.items():
        if not name or entry.get("optional"):
            continue
        if installed.get(name, {}).get("version") != entry.get("version"):
            return False
    return True


def dependency_cache_root(workspace):
    return SHARED_DIR / "node_modules" / slugify(workspace)


def dependency_cache(workspace, directory):
    return dependency_cache_root(workspace) / file_hash(directory / "package-lock.json")[:16]


def cached_dependency_sets(workspace):
    root = dependency_cache_root(workspace)
    if not root.is_dir():
        return []
    return sorted((path for path in root.iterdir() if (path / "node_modules").is_dir()),
                  key=lambda path: path.stat().st_mtime, reverse=True)


LIBC = ctypes.CDLL("libc.dylib", use_errno=True)


def clone_tree(source, target):
    if LIBC.clonefile(os.fsencode(source), os.fsencode(target), 0) != 0:
        subprocess.run(["cp", "-cR", str(source), str(target)], check=True)


def remove_in_background(path):
    if not path.exists():
        return
    trash = SHARED_DIR / "trash"
    trash.mkdir(parents=True, exist_ok=True)
    doomed = trash / f"{path.name}.{os.getpid()}.{time.time_ns()}"
    path.rename(doomed)
    subprocess.Popen(["rm", "-rf", str(doomed)], stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL,
                     stderr=subprocess.DEVNULL, start_new_session=True)


def clone_node_modules(source, directory):
    remove_in_background(directory / "node_modules")
    clone_tree(source / "node_modules", directory / "node_modules")
    os.utime(source)


def npm(directory, *args):
    lockfile = directory / "package-lock.json"
    original = lockfile.read_bytes()
    try:
        return subprocess.run(["npm", *args, "--no-audit", "--no-fund", "--loglevel=warn"], cwd=directory).returncode == 0
    finally:
        if lockfile.read_bytes() != original:
            lockfile.write_bytes(original)


def fill_dependency_cache(workspace, directory):
    cache = dependency_cache(workspace, directory)
    if cache.exists():
        return
    staging = cache.with_name(cache.name + f".{os.getpid()}")
    staging.mkdir(parents=True, exist_ok=True)
    clone_tree(directory / "node_modules", staging / "node_modules")
    try:
        staging.rename(cache)
    except OSError:
        shutil.rmtree(staging, ignore_errors=True)


def install_dependencies(workspace, directory):
    with file_lock("dependency-cache"):
        cache = dependency_cache(workspace, directory)
        if (cache / "node_modules").is_dir():
            log(f"{workspace}: cloning node_modules from the dependency cache...")
            clone_node_modules(cache, directory)
            return
        if not (directory / "node_modules").is_dir():
            nearest = next(iter(cached_dependency_sets(workspace)), None)
            if nearest:
                log(f"{workspace}: cloning the newest cached node_modules as a starting point...")
                clone_node_modules(nearest, directory)
    if (directory / "node_modules").is_dir():
        log(f"{workspace}: installing the packages that differ from package-lock.json...")
        if npm(directory, "install", "--prefer-offline") and installed_matches_lockfile(directory):
            fill_dependency_cache(workspace, directory)
            return
    log(f"{workspace}: installing every package with npm ci...")
    if not npm(directory, "ci", "--prefer-offline") or not installed_matches_lockfile(directory):
        raise StackError(f"npm ci failed in {workspace}")
    fill_dependency_cache(workspace, directory)


def ensure_dependencies(checkout, workspaces):
    for workspace in workspaces:
        directory = checkout.root / workspace
        if not installed_matches_lockfile(directory):
            install_dependencies(workspace, directory)


def prune_dependency_cache(live, dry_run):
    actions = []
    for workspace in WORKSPACES.values():
        wanted = {dependency_cache(workspace, root / workspace).name for root in live
                  if (root / workspace / "package-lock.json").is_file()}
        sets = cached_dependency_sets(workspace)
        for path in sets[1:]:
            if path.name not in wanted:
                actions.append(f"removed cached node_modules {workspace} {path.name}")
                if not dry_run:
                    with file_lock("dependency-cache"):
                        shutil.rmtree(path, ignore_errors=True)
    return actions


def migrations_hash(root):
    directory = Path(root) / "services" / "registries" / "prisma" / "migrations"
    digest = hashlib.sha256()
    for path in sorted(directory.rglob("*")):
        if path.is_file():
            digest.update(str(path.relative_to(directory)).encode())
            digest.update(path.read_bytes())
    return digest.hexdigest()[:12]


def template_names(migration_hash):
    return f"registries_tpl_{migration_hash}", f"registries_seed_{migration_hash}"


def ensure_registries_database(checkout):
    if database_exists(checkout.registries_db):
        return "existing"
    migration_hash = migrations_hash(checkout.root)
    migrated, seeded = template_names(migration_hash)
    with file_lock(f"template-{migration_hash}"):
        if database_exists(seeded):
            log(f"Copying {checkout.registries_db} from the seeded template {seeded}...")
            psql(f'CREATE DATABASE "{checkout.registries_db}" TEMPLATE "{seeded}"')
            return "seeded"
        if not database_exists(migrated):
            building = f"{migrated}_build"
            log(f"Building the migrated template {migrated}...")
            drop_database(building)
            psql(f'CREATE DATABASE "{building}"')
            result = subprocess.run(
                ["npx", "prisma", "migrate", "deploy"],
                cwd=checkout.root / "services" / "registries",
                env={**os.environ, "POSTGRES_URL": postgres_url(building)},
                capture_output=True, text=True,
            )
            if result.returncode != 0:
                drop_database(building)
                raise StackError(f"migrations failed while building {migrated}:\n{result.stdout[-3000:]}{result.stderr[-3000:]}")
            psql(f'ALTER DATABASE "{building}" RENAME TO "{migrated}"')
        log(f"Copying {checkout.registries_db} from the migrated template {migrated}...")
        psql(f'CREATE DATABASE "{checkout.registries_db}" TEMPLATE "{migrated}"')
    return "migrated"


def snapshot_seeded_template(checkout, slot):
    migration_hash = migrations_hash(checkout.root)
    _, seeded = template_names(migration_hash)
    with file_lock(f"template-{migration_hash}"):
        if database_exists(seeded):
            return
        log(f"Saving the seeded database as {seeded} for the next new checkout...")
        stop_process(checkout.pid_file("registries"))
        try:
            psql(f'CREATE DATABASE "{seeded}" TEMPLATE "{checkout.registries_db}"')
        finally:
            start_services(checkout, slot, ["registries"])


def seed(checkout, slot):
    script = SCRIPTS_DIR / "create-registry.ts"
    if not script.is_file():
        log(f"Warning: {script} not found; skipping the Analysis test registry.")
        return False
    log("Ensuring the Analysis test registry...")
    result = subprocess.run(["npx", "tsx", "create-registry.ts", "analysis", "--slot", str(slot), "--if-missing"],
                            cwd=SCRIPTS_DIR)
    if result.returncode != 0:
        log("Warning: create-registry.ts failed; the Analysis test registry may be missing or incomplete.")
        return False
    return True


def write_test_env(checkout):
    path = checkout.root / "services" / "registries" / ".env.test.local"
    path.write_text(f"POSTGRES_URL={postgres_url(checkout.test_db)}\n")


def remove_test_env(checkout):
    (checkout.root / "services" / "registries" / ".env.test.local").unlink(missing_ok=True)


def checkout_running(stack_dir):
    return any(read_process(stack_dir / "pids" / f"{service}.json") for service in SERVICES)


def choose_slot(checkout, requested):
    if not checkout.is_worktree:
        return 0
    claims = {}
    for stack_dir in stack_dirs():
        if stack_dir == checkout.stack_dir:
            continue
        try:
            value = (stack_dir / "worktree-slot").read_text().strip()
        except FileNotFoundError:
            continue
        if re.fullmatch(r"[1-9]", value):
            claims.setdefault(int(value), []).append(stack_dir)

    def taken(slot):
        if any(checkout_running(stack_dir) for stack_dir in claims.get(slot, [])):
            return True
        own = set(checkout.running_services())
        return any(port_in_use(port) for service in SERVICES if service not in own
                   for port in service_ports(service, slot))

    if requested is not None:
        if taken(requested):
            raise StackError(f"slot {requested} is in use by another stack")
        return requested
    saved = checkout.saved_slot()
    if saved and (checkout.running_services() or not taken(saved)):
        return saved
    unclaimed = [slot for slot in range(1, 10) if slot not in claims and not taken(slot)]
    if unclaimed:
        return unclaimed[0]
    for slot in range(1, 10):
        if not taken(slot):
            for stack_dir in claims.get(slot, []):
                (stack_dir / "worktree-slot").unlink(missing_ok=True)
                previous = recorded_checkout(stack_dir)
                if previous and previous.is_dir():
                    render_context(previous)
                log(f"Took slot {slot} from the stopped stack {stack_dir.name}.")
            return slot
    raise StackError("all worktree slots (1-9) have running stacks; stop one with dev stack down")


def spawn_services(checkout, slot, services):
    for service in services:
        if read_process(checkout.pid_file(service)):
            continue
        for port in service_ports(service, slot):
            if port_in_use(port):
                raise StackError(f"{service} port {port} is taken by {port_owner(port)}")
        spec = service_spec(checkout, service, slot)
        log(f"Starting {service}...")
        spawn(spec["command"], spec["cwd"], spec["env"], checkout.log_file(service), checkout.pid_file(service))


def start_services(checkout, slot, services):
    spawn_services(checkout, slot, services)
    wait_ready(checkout, slot, services)


def wait_ready(checkout, slot, services):
    pending = {service: service_spec(checkout, service, slot) for service in services}
    started = time.monotonic()
    while pending:
        for service, spec in list(pending.items()):
            if spec["ready"]():
                log(f"{service} is ready ({time.monotonic() - started:.0f}s).")
                del pending[service]
            elif not read_process(checkout.pid_file(service)) or nodemon_crashed(checkout.log_file(service)):
                raise StackError(f"{service} failed during startup. Last log lines:\n{tail(checkout.log_file(service), 40)}")
            elif time.monotonic() - started > spec["timeout"]:
                raise StackError(f"{service} was not ready after {spec['timeout']}s. Last log lines:\n{tail(checkout.log_file(service), 40)}")
        if pending:
            time.sleep(1)


def nodemon_crashed(log_path):
    text = tail(log_path, 20)
    crashed = text.rfind("[nodemon] app crashed")
    return crashed != -1 and crashed > max(text.rfind("[nodemon] starting"), text.rfind("[nodemon] restarting"))


def render_context(root):
    subprocess.run(["bash", str(DEV_DIR / "context-render.sh")], cwd=root,
                   stdout=subprocess.DEVNULL, check=False)


def touch_activity(checkout):
    checkout.stack_dir.mkdir(parents=True, exist_ok=True)
    (checkout.stack_dir / "last-active").touch()


def command_up(args):
    services = []
    for name in args.services:
        if name in ("-d", "--detach", "--wait"):
            continue
        if name.startswith("-"):
            raise StackError(f"unknown option for dev stack up: {name}")
        if name != "postgres" and name not in SERVICES:
            raise StackError(f"unknown service: {name} (choose from postgres, {', '.join(SERVICES)})")
        if name not in services:
            services.append(name)
    if args.include_patient:
        raise StackError("the patient services do not run natively yet")
    if not services:
        services = list(DEFAULT_SERVICES)
    checkout = Checkout.current()
    ensure_postgres()
    write_test_env(checkout)
    app_services = [service for service in SERVICES if service in services]
    if not app_services:
        log(f"PostgreSQL is running on localhost:{PG_PORT}.")
        log(f"Backend tests use {checkout.test_db} through services/registries/.env.test.local.")
        return
    for service in app_services:
        directory = checkout.root / WORKSPACES[service]
        if (read_process(checkout.pid_file(service)) and (directory / "package-lock.json").is_file()
                and not installed_matches_lockfile(directory)):
            log(f"Stopping {service}: its dependencies no longer match package-lock.json.")
            stop_process(checkout.pid_file(service))
    ensure_dependencies(checkout, [WORKSPACES[service] for service in app_services])
    if "registries" in app_services:
        ensure_admin_mock()
    database_state = "existing"
    with file_lock("slots"):
        slot = choose_slot(checkout, args.slot)
        checkout.stack_dir.mkdir(parents=True, exist_ok=True)
        checkout.slot_file.write_text(f"{slot}\n")
        (checkout.stack_dir / "checkout").write_text(f"{checkout.root}\n")
        if "registries" in app_services:
            database_state = ensure_registries_database(checkout)
        if "codelist" in app_services and not database_exists(checkout.codelist_db):
            psql(f'CREATE DATABASE "{checkout.codelist_db}"')
        log(f"Checkout: {checkout.id} (slot {slot})")
        spawn_services(checkout, slot, app_services)
    touch_activity(checkout)
    render_context(checkout.root)
    wait_ready(checkout, slot, app_services)
    if "registries" in app_services:
        if seed(checkout, slot) and database_state == "migrated":
            snapshot_seeded_template(checkout, slot)
    ports = ports_for(slot)
    if "registries-frontend" in app_services:
        log(f"Stack is running at http://localhost:{ports['frontend']}/en/registries")
    else:
        log("Stack is running.")


def stop_checkout(checkout):
    stopped = [service for service in SERVICES if stop_process(checkout.pid_file(service))]
    if not checkout.is_worktree:
        checkout.slot_file.unlink(missing_ok=True)
    return stopped


def command_down(args):
    checkout = Checkout.current()
    stopped = stop_checkout(checkout)
    render_context(checkout.root)
    log(f"Stopped {', '.join(stopped)}." if stopped else "No services were running.")


def drop_checkout_databases(checkout):
    if not PG_DATA.is_dir():
        return
    ensure_postgres()
    for name in (checkout.registries_db, checkout.test_db, checkout.codelist_db):
        drop_database(name)


def command_destroy(args):
    checkout = Checkout.current()
    log(f"This deletes the services, databases and slot of {checkout.id}.")
    if not args.yes:
        if not sys.stdin.isatty():
            raise StackError("stdin is not a terminal; re-run as dev stack destroy --yes")
        if input("Are you sure? (y/N): ").strip().lower() != "y":
            log("Stack destruction cancelled.")
            return
    stop_checkout(checkout)
    drop_checkout_databases(checkout)
    remove_test_env(checkout)
    shutil.rmtree(checkout.stack_dir, ignore_errors=True)
    render_context(checkout.root)
    log("Stack destruction complete.")


def command_list(args):
    log(f"Shared PostgreSQL: {'running on localhost:' + str(PG_PORT) if postgres_running() else 'stopped'}")
    admin_mock = read_process(SHARED_DIR / "admin-mock.json")
    log(f"Admin mock: {'running on :' + str(ADMIN_MOCK_GRAPHQL_PORT) + ' and :' + str(ADMIN_MOCK_GRPC_PORT) if admin_mock else 'stopped'}")
    log("")
    found = False
    for stack_dir in stack_dirs():
        running = [service for service in SERVICES if read_process(stack_dir / "pids" / f"{service}.json")]
        if not running:
            continue
        found = True
        slot_text = (stack_dir / "worktree-slot").read_text().strip() if (stack_dir / "worktree-slot").exists() else "0"
        ports = ports_for(int(slot_text))
        log(f"  Slot {slot_text}: {stack_dir.name} ({recorded_checkout(stack_dir)})")
        log(f"    Services: {', '.join(running)}")
        if "registries-frontend" in running:
            log(f"    Frontend: http://localhost:{ports['frontend']}/en/registries")
        if "registries" in running:
            log(f"    GraphQL:  http://localhost:{ports['registries']}/graphql")
    if not found:
        log("  No dev stacks running.")


def command_ps(args):
    checkout = Checkout.current()
    slot = checkout.saved_slot() if checkout.is_worktree else 0
    for service in SERVICES:
        record = read_process(checkout.pid_file(service))
        state = f"running (pid {record['pid']})" if record else "stopped"
        ports = "no slot yet" if slot is None else ", ".join(str(port) for port in service_ports(service, slot))
        log(f"{service:20} {state:24} ports {ports}  log {checkout.log_file(service)}")


def command_logs(args):
    checkout = Checkout.current()
    for service in args.services:
        if service not in SERVICES:
            raise StackError(f"unknown service: {service}")
    services = args.services or [service for service in SERVICES if checkout.log_file(service).exists()]
    paths = [str(checkout.log_file(service)) for service in services if checkout.log_file(service).exists()]
    if not paths:
        raise StackError("no logs for this checkout")
    command = ["tail", "-n", str(args.lines)]
    if args.follow:
        command.append("-F")
    os.execvp("tail", command + paths)


def command_restart(args):
    checkout = Checkout.current()
    slot = checkout.saved_slot() if checkout.is_worktree else 0
    if slot is None:
        raise StackError("this checkout has no stack yet; run dev stack up")
    services = args.services or checkout.running_services()
    if not services:
        raise StackError("no services are running; run dev stack up")
    for service in services:
        if service not in SERVICES:
            raise StackError(f"unknown service: {service}")
        stop_process(checkout.pid_file(service))
    ensure_postgres()
    if "registries" in services:
        ensure_admin_mock()
    start_services(checkout, slot, services)
    touch_activity(checkout)


def command_psql(args):
    checkout = Checkout.current()
    ensure_postgres()
    database = checkout.test_db if args.test else checkout.registries_db
    os.execvp(str(PG_BIN / "psql"), [str(PG_BIN / "psql"), postgres_url(database), *args.psql_args])


def established_connection(ports):
    if not ports:
        return False
    command = ["lsof", "-nP", "-sTCP:ESTABLISHED", "-t"]
    for port in ports:
        command.append(f"-iTCP:{port}")
    return bool(subprocess.run(command, capture_output=True, text=True).stdout.strip())


def live_checkouts():
    roots = set()
    result = subprocess.run(["git", "-C", str(MAIN_REPO), "worktree", "list", "--porcelain"],
                            capture_output=True, text=True)
    if result.returncode != 0:
        raise StackError(f"git worktree list failed in {MAIN_REPO}: {result.stderr.strip()}")
    for line in result.stdout.splitlines():
        if line.startswith("worktree "):
            roots.add(Path(line[len("worktree "):]))
    return {root for root in roots if root.is_dir()}


def command_reap(args):
    now = time.time()
    actions = []
    live = live_checkouts()
    for stack_dir in stack_dirs():
        root = recorded_checkout(stack_dir)
        if root is None:
            continue
        checkout = Checkout(root)
        if root not in live:
            actions.append(f"removed {stack_dir.name}: {root} no longer exists")
            if not args.dry_run:
                stop_checkout(checkout)
                drop_checkout_databases(checkout)
                shutil.rmtree(stack_dir, ignore_errors=True)
            continue
        running = checkout.running_services()
        if not running:
            continue
        slot = checkout.saved_slot() if checkout.is_worktree else 0
        ports = [port for service in running for port in service_ports(service, slot or 0)
                 if not port_is_grpc(port)]
        activity = stack_dir / "last-active"
        if established_connection(ports):
            if not args.dry_run:
                activity.touch()
            continue
        last_active = activity.stat().st_mtime if activity.exists() else 0
        if now - last_active > IDLE_LIMIT_SECONDS:
            idle_minutes = int((now - last_active) / 60)
            actions.append(f"stopped {stack_dir.name}: idle for {idle_minutes} minutes")
            if not args.dry_run:
                stop_checkout(checkout)
                render_context(root)
    if postgres_running():
        wanted = set()
        for root in live:
            if (root / "services" / "registries" / "prisma" / "migrations").is_dir():
                wanted.update(template_names(migrations_hash(root)))
        templates = psql(
            "SELECT datname FROM pg_database WHERE datname ~ '^registries_(tpl|seed)_[0-9a-f]{12}$'"
        ).splitlines()
        for name in templates:
            if name not in wanted:
                actions.append(f"dropped template {name}")
                if not args.dry_run:
                    with file_lock(f"template-{name[-12:]}"):
                        drop_database(name)
    actions += prune_dependency_cache(live, args.dry_run)
    stamp = time.strftime("%Y-%m-%d %H:%M:%S")
    for action in actions:
        log(f"{stamp} {'would have ' if args.dry_run else ''}{action}")


def port_is_grpc(port):
    return port >= 50000


def parse(argv):
    parser = argparse.ArgumentParser(prog="dev stack", add_help=False)
    commands = parser.add_subparsers(dest="command", required=True)
    up = commands.add_parser("up", add_help=False)
    up.add_argument("--slot", type=int, choices=range(1, 10))
    up.add_argument("--include-patient", action="store_true")
    up.add_argument("services", nargs=argparse.REMAINDER)
    for name in ("down", "stop"):
        commands.add_parser(name, add_help=False)
    destroy = commands.add_parser("destroy", add_help=False)
    destroy.add_argument("--yes", action="store_true")
    commands.add_parser("list", add_help=False)
    commands.add_parser("ps", add_help=False)
    logs = commands.add_parser("logs", add_help=False)
    logs.add_argument("-f", "--follow", action="store_true")
    logs.add_argument("-n", "--lines", type=int, default=100)
    logs.add_argument("services", nargs="*")
    restart = commands.add_parser("restart", add_help=False)
    restart.add_argument("services", nargs="*")
    psql_parser = commands.add_parser("psql", add_help=False)
    psql_parser.add_argument("--test", action="store_true")
    psql_parser.add_argument("psql_args", nargs=argparse.REMAINDER)
    reap = commands.add_parser("reap", add_help=False)
    reap.add_argument("--dry-run", action="store_true")
    return parser.parse_args(argv)


HANDLERS = {
    "up": command_up,
    "down": command_down,
    "stop": command_down,
    "destroy": command_destroy,
    "list": command_list,
    "ps": command_ps,
    "logs": command_logs,
    "restart": command_restart,
    "psql": command_psql,
    "reap": command_reap,
}


def main(argv):
    args = parse(argv)
    try:
        HANDLERS[args.command](args)
    except StackError as error:
        print(f"Error: {error}", file=sys.stderr)
        return 1
    except subprocess.CalledProcessError as error:
        print(f"Error: {' '.join(map(str, error.cmd))} exited with {error.returncode}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
