# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Ledidi Main Frontend — a React 19 application for a medical data registry and research platform. Part of the `ledidi-monorepo`. Built with TypeScript, Vite, Tailwind CSS 4, and Apollo Client (GraphQL).

## Common Commands

```bash
# Development (runs codegen watcher + Vite on port 3001)
npm run dev

# Build (codegen + tsc + vite build)
npm run build

# Type checking only
npm run build-ts

# Lint (prettier check + eslint)
npm run lint
npm run lint:fix

# Unit tests (vitest with happy-dom)
npm test                          # all unit tests
npx vitest run src/path/to/file   # single test file
npx vitest --watch                # watch mode

# Storybook component tests (browser-based via Playwright)
npm run test:storybook

# E2E tests (Playwright, requires dev server running on :3001)
npm run test:e2e
npx playwright test src/app/path/to/test.spec.tsx  # single e2e test

# GraphQL codegen (regenerate types from schema)
npm run generate

# Storybook
npm run storybook
```

## Architecture

### Provider Hierarchy

The app nests providers in this order (see `src/app/`):

```
BrowserRouter → ThemeProvider → LanguageProvider → CommunicationBridgeProvider
  → QueryClientProvider → AppRouter
    → ApolloProvider → AuthProvider → FeatureFlagProvider → TrackingProvider
```

Unauthenticated routes (surveys, PROM) use `UnauthenticatedApolloProvider` and skip auth/feature-flag providers entirely.

### Routing

React Router v7 with language prefix: `/:lang/registries/...`, `/:lang/auth/...`, etc.

Routes are split into sub-routers in `src/app/AppRouter/`:
- `auth-router.tsx` — sign-in, sign-up, MFA, password reset
- `registries-router.tsx` — main authenticated area (patients, episodes, registry design, dashboard, collaborators, jobs)
- `studies.tsx` — surveys
- `admin-router.tsx` — admin controls

Pages live under `src/app/[lang]/` following a file-system-like convention (`page.tsx` for pages, `layout.tsx` for layouts). Routes use `React.lazy` + `Suspense` for code splitting.

### Data Layer

- **GraphQL via Apollo Client** is the primary data-fetching mechanism. All server communication goes through GraphQL.
- **Codegen**: `npm run generate` reads `.graphql` schema files from `../../services/{studies,admin,registries}/api/` and inline GraphQL in `src/` to produce `src/generated/graphql.ts` with typed hooks.
- **React Query** (`@tanstack/react-query`) is also available but secondary to Apollo.
- Write GraphQL operations inline in component files or in `.graphql` files — codegen picks up both.

### Styling

- **Tailwind CSS 4** with Vite plugin (no PostCSS config needed in most cases).
- Custom color scales defined in `src/styles/globals.css`: `baseline`, `primary`, `error`, `success`, `warning` (each 50-950).
- shadcn/ui semantic tokens: `--background`, `--foreground`, `--card`, `--popover`, `--muted`, `--accent`, `--destructive`, `--border`, `--ring`, etc. — set as CSS variables in `:root`.
- Alternative theme available via `.v1-theme` class.
- Use the `cn()` utility from `~/lib/utils` for merging Tailwind classes.
- Dark mode via `data-theme="dark"` attribute (custom variant, not Tailwind's default `dark:` prefix).

### Component Library

- **`src/components/ui/`** — shadcn/ui components (Radix UI + Tailwind). These are the base primitives (Button, Dialog, Select, Table, etc.).
- **`src/components/`** — project-specific reusable components built on top of the ui primitives.
- **`src/smart-components/`** — components with business logic or data fetching (e.g., ApolloErrorAlert, StudySiteSelect).
- Icons: Lucide React (`lucide-react`).

### Key Integrations

- **Auth**: AWS Amplify (Cognito) — see `src/features/auth/`
- **Feature flags**: LaunchDarkly — see `src/features/FeatureFlagProvider.tsx`
- **Analytics**: Segment — see `src/features/segment/`
- **Monitoring**: Datadog RUM + Logs
- **Iframe embedding**: `CommunicationBridgeProvider` handles PostMessage communication

## Code Conventions

### Path Aliases

`~` maps to `./src/` (configured in tsconfig.json and vite.config.ts). Always use `~/` imports for source files.

### TypeScript

- Strict mode with `noUncheckedIndexedAccess` enabled.
- `verbatimModuleSyntax` is on — use `import type { ... }` for type-only imports.
- ESLint enforces `consistent-type-imports` (prefer inline type imports: `import { type Foo } from ...`).
- Unused vars must be prefixed with `_` (ESLint rule).
- `no-console` is an error — use `console.warn` or `console.error` only.
- `eqeqeq: "smart"` — use strict equality.

### Testing

- Unit tests: `*.test.tsx` files next to source, run with Vitest + happy-dom.
- E2E tests: `*.spec.tsx` files in `src/app/`, run with Playwright against `localhost:3001`.
- Storybook tests: `*.stories.tsx` files, run via `npm run test:storybook` (browser-based).
- Use `testRender()` from `test-util/testRender.tsx` for unit tests — wraps components in MemoryRouter, ApolloProvider, LanguageProvider, and CommunicationBridgeProvider.
- Use `createTestClient()` and `TEST_GRAPHQL_API` from `test-util/testApolloClient.ts` for mocking GraphQL.
- MSW server from `test-util/mswServer.ts` for API mocking.

### Generated Code

`src/generated/` is auto-generated by GraphQL codegen. Never edit these files directly. ESLint ignores this directory.

### Forms

React Hook Form + Zod for validation (`@hookform/resolvers`).
