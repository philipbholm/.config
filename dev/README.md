# Dev Scripts

Development utility scripts for the monorepo.

## Available Commands

| Command | Description |
|---------|-------------|
| `dev` | Smart docker compose wrapper — auto-detects main vs worktree |
| `check` | Run linting, formatting, and build on changed files |
| `tests` | Run tests (unit, integration, e2e) on changed files |
| `tunnel` | Start cloudflared tunnels for remote access |

## `dev` — Unified Dev Stack Manager

`dev` wraps `docker compose` with automatic environment detection. It determines whether you're in the main checkout or a git worktree, generates the correct compose override file (port offsets, networking, volumes), and forwards your command to `docker compose`.

```bash
# These are equivalent:
dev restart registries
docker compose -f docker-compose.yml -f <override> restart registries
```

### Commands

| Command | Description |
|---------|-------------|
| `dev up` | Full init: generate override, start services, and when `registries` is started also seed DB and sync context files |
| `dev up --build <service>` | Rebuild a specific service (replaces old `rebuild` command) |
| `dev down` | Stop and remove containers |
| `dev nuke` | Full teardown: containers, volumes, images, slot, tmp dir |
| `dev start [services...]` | Start stopped containers (reconnects admin-mock networking) |
| `dev status` | Show all running stacks (main + worktrees) |
| `dev <anything else>` | Pure passthrough to `docker compose` |

### Passthrough Examples

Any docker compose command works — `dev` just injects the right `-f` flags:

```bash
dev restart registries       # Restart a service
dev logs -f registries       # Tail logs
dev exec registries sh       # Shell into container
dev ps                       # List containers
dev build registries         # Build image without starting
dev stop                     # Stop without removing
```

### Mode Detection

`dev` auto-detects the environment by checking the `.git` entry at the repo root:

- **Main checkout** (`.git` is a directory) → slot 0, default ports, shared admin-mock networking
- **Worktree** (`.git` is a file) → slots 1–9, ports offset by `slot × 100`, isolated network

### Port Mapping (Worktrees)

Each worktree gets a unique slot (1–9). Ports are offset by `slot × 100`:

| Service | Main (slot 0) | Slot 1 | Slot 2 |
|---------|--------------|--------|--------|
| Frontend | 3003 | 3103 | 3203 |
| Router | 4000 | 4100 | 4200 |
| Postgres | 5432 | 5532 | 5632 |
| Codelist | 4005 | 4105 | 4205 |
| Registries | 4006 | 4106 | 4206 |
| patient-frontend | 3015 | 3115 | 3215 |
| **patient-bff** | **4010** | **4010 (pinned)** | **4010 (pinned)** |

`patient-bff` is the one exception to the offset rule — see [Helsenorge / patient-bff demo setup](#helsenorge--patient-bff-demo-setup) below.

### Override Files

`dev` writes a generated compose override to:

```
~/work/.dev-stacks/<workspace-id>/docker-compose.stack.yml
```

This file is regenerated on every command. The `DEV_STACKS_DIR` env var controls the base directory. Worktree IDs are derived from the branch name and include a stable hash so similarly named branches do not collide.

## Helsenorge / patient-bff demo setup

The patient-bff stack (introduced with the PROM patient flow) talks to NHN's Helsenorge HN2 test environment via real OIDC + HelseID, so a few things have to line up before `/uthopp` works end-to-end. The defaults in `dev.sh` and `.env.local` are wired for this, but knowing the moving pieces helps when something fails.

### Why patient-bff is pinned to port 4010

NHN's Helsenorge OIDC client (`HELSENORGE_CLIENT_ID=3a17b005-…`) only has `http://localhost:4010/uthopp/callback` on its `redirect_uri` allow-list. Anything else — `localhost:4110`, `localhost:4510`, a per-developer ngrok subdomain — fails the Pushed Authorization Request with FHIR error `204019 - Fant ingen match på RedirectUri`. So `dev.sh` ignores the worktree offset for this one service and always binds host port 4010.

**Trade-off:** only one worktree can run `patient-bff` at a time. Switching worktrees requires `dev down` on the old one first. If two worktrees compete for 4010, the second `dev up patient-bff` will fail with a port-already-allocated error.

### `.env.local` — per-developer overrides

`dev.sh` sources `~/.config/dev/.env.local` at startup and `set -a`'s every variable so docker-compose's `${VAR}` interpolation can see them.

Required keys for the Helsenorge flow:

```bash
# Your reserved ngrok subdomain. Helsenorge stamps PATIENT_BFF_PUBLIC_URL
# into the oppgave's Task.instantiatesUri, which must be HTTPS-reachable
# from the public internet (FHIR code 2174 rejects http://).
NGROK_PATIENT_BFF_URL=https://<your-reserved-subdomain>.ngrok-free.dev

# NHN test env. Always HN2 — HN1's citizen portal (tjenester.hn.test.nhn.no)
# has been observed serving "Tjenesten er midlertidig ikke tilgjengelig"
# while the API still accepts oppgaves, so sends silently don't reach the
# patient.
HELSENORGE_OPPGAVE_BASE_URL=https://eksternapi.hn2.test.nhn.no
```

### ngrok tunnel

Your reserved subdomain has to forward to the pinned host port 4010:

```bash
ngrok http --url=<your-reserved-subdomain>.ngrok-free.dev 4010
```

Keep it running in a terminal while you're testing `/uthopp`. The tunnel is what lets Helsenorge call back into the BFF from the public internet — without it, the oppgave creation succeeds but the patient's task link points nowhere.

**One-time NHN registration:** your specific ngrok subdomain has to be added to the Helsenorge OIDC client's allow-list (alongside `localhost:4010`) by whoever owns the NHN test client. Without that, the OIDC discovery happens on `localhost:4010` but stamp-into-oppgave uses the ngrok URL, which is fine as long as the bff bounces the user from ngrok host → localhost before starting OIDC (handled in `services/patient-bff/src/http/routes/uthopp.ts`).

### MSW disabled

The patient-frontend ships with Mock Service Worker on by default in dev (`apps/patient-frontend/src/main.tsx` — "until the patient-bff PROM endpoints land"). Those endpoints have landed, but the default was never flipped, so the React app intercepts `/api/prom` and shows canned "Smerteskala uke 3 / Symptomer denne uka / Bakgrunnsopplysninger" mock data instead of the real PROM.

`dev.sh` sets `VITE_USE_MSW=false` on the `patient-frontend` container to bypass this. If you ever see "Smerteskala uke 3" forms when you expect your real PROM, your container was started without that env var — recreate with `dev up -d patient-frontend`.

### Sanity checklist when `/uthopp` misbehaves

1. **PAR rejected with `204019 - Fant ingen match på RedirectUri`** → patient-bff isn't on port 4010, or NHN doesn't have your ngrok subdomain on the allow-list. Verify `docker inspect <bff> --format='{{range .Config.Env}}{{println .}}{{end}}' | grep HELSENORGE_REDIRECT_URI`.
2. **`getaddrinfo ENOTFOUND eksternapi.…`** → `HELSENORGE_OPPGAVE_BASE_URL` is wrong. Only `eksternapi.hn.test.nhn.no` (HN1) and `eksternapi.hn2.test.nhn.no` (HN2) exist; `eksternapi.test.nhn.no` is NXDOMAIN. Use HN2.
3. **ngrok returns 502** → tunnel is forwarding to a stale port. Kill it (`pkill -f 'ngrok http'`) and restart against 4010.
4. **Mock "Smerteskala uke 3" PROM showing** → MSW is on. Confirm `VITE_USE_MSW=false` in the patient-frontend container and hard-reload (Shift-Cmd-R) so the service worker re-fetches `main.tsx`. May need to manually unregister the SW via DevTools → Application → Service Workers.
5. **Session cookie missing on localhost** → the OIDC callback was processed on the ngrok host (cookie set on that domain) instead of localhost. Check `PATIENT_BFF_LOCAL_URL=http://localhost:4010` in the bff env so the host-bounce in `/uthopp/start` runs.
6. **HN2 portal at `tjenester.hn2.test.nhn.no` shows "Vi beklager!"** → you're not logged in as the patient. Citizen portals require BankID auth as that specific fnr; can't be inspected unauthenticated.
7. **`ERR_NGROK_3200 — endpoint <sub>.ngrok-free.dev is offline`** → you opened a **stale oppgave** whose link was frozen with an old ngrok subdomain. The patient link is stamped at send time by **`services/registries`** (not patient-bff): `send-prom-through-helsenorge.ts` builds `${PATIENT_BFF_PUBLIC_URL}/uthopp/start?prom_entry_id=…` into the oppgave's `instantiatesUri`, and that value lives in HN2 forever. The request dies at ngrok's edge and never reaches your stack, so no config change fixes it — **re-send the PROM and open the new task.** When the subdomain looks wrong, confirm all four agree: the **registries** container env (`PATIENT_BFF_PUBLIC_URL`), the patient-bff container env, `.env.local` (`NGROK_PATIENT_BFF_URL`), and the live agent (`curl -s localhost:4040/api/tunnels`). If only the running ngrok agent is on the wrong name, restart it on your reserved subdomain.
8. **`Blocked request. This host ("patient-frontend") is not allowed`** (Vite) → the patient-bff catch-all proxies non-API routes to the Vite dev server (`@fastify/http-proxy` → `patient-frontend:3015`), and via ngrok the Host arrives as `patient-frontend`. Vite 6 denies hosts not in `server.allowedHosts`. `apps/patient-frontend/vite.config.ts` allow-lists `patient-frontend` and `.ngrok-free.dev` (the dot-prefix matches any rotated subdomain). Direct `localhost:3115` is always allowed, so this only shows through the tunnel/proxy. **Only `src/` is bind-mounted** into the patient-frontend container — `vite.config.ts` lives in the image, so config edits need `dev build patient-frontend` + recreate, not just a restart.

## Setup

Scripts in this directory are made available as commands via symlinks in `~/bin`.

To add a new command:

```bash
ln -sf ~/.config/dev/<script>.sh ~/bin/<command>
```

For example:
```bash
ln -sf ~/.config/dev/check.sh ~/bin/check
```

## Current Symlinks

```bash
~/bin/dev     -> ~/.config/dev/dev.sh
~/bin/check   -> ~/.config/dev/check.sh
~/bin/tests   -> ~/.config/dev/tests.sh
~/bin/tunnel  -> ~/.config/dev/tunnel.sh
```

## Why Symlinks?

Symlinks in `~/bin` ensure commands work in all shell contexts, including:
- Interactive terminal sessions
- Non-interactive shells (e.g., Claude Code, scripts)
- IDE integrated terminals
