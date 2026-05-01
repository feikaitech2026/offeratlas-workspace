# OfferAtlas Parallel Thread Guide

This file is the quick-start rulebook for running multiple coding agents or IDE threads in the same OfferAtlas workspace.

## Thread Ownership

| Thread | Directory | Owns | Must not own by default |
| --- | --- | --- | --- |
| B-side frontend | `OfferAtlas Pro/` | Consultant/admin frontend UI, routes, frontend API client | Core API implementation, ScholarGraph, DataAdmin |
| B-side backend | `offeratlas-core-api/` | Auth, tenants, RBAC, students, applications, Core API contracts | Pro UI, DataAdmin UI/API, direct crawler writes |
| Data platform frontend | `OfferAtlas DataAdmin/` | Data governance dashboard UI and DataAdmin frontend client | DataAdmin backend logic, Core API |
| Data platform backend | `offeratlas-data-admin-api/` | Data governance/report API, read-only aggregate access, `offeratlas_data_admin` state | Pro UI, Core business logic, Crawler writes |

Other services are supporting services:

- `OfferAtlas ScholarGraph/`: school/program knowledge service, matching, search, import from crawler exports.
- `OfferAtlas Crawler/`: public data collection and export.
- `OfferAtlas Docs/`: shared contracts and deployment/database documents.
- `OfferAtlas-Secrets/`: local secrets only, never commit.

## Hard Boundaries

- Frontends call only their own backend:
  - `OfferAtlas Pro -> offeratlas-core-api`
  - `OfferAtlas DataAdmin -> offeratlas-data-admin-api`
- Core API calls ScholarGraph through internal endpoints.
- DataAdmin API may read ScholarGraph/Crawler databases for reporting, but should write only its own DataAdmin database.
- Do not add frontend-to-ScholarGraph calls.
- Do not add Crawler-to-Core writes.
- Do not add shared tables across service databases.

## API Contract Rule

When a change crosses a frontend/backend boundary:

1. Update the contract first in the relevant README or docs note.
2. Implement the backend schema/controller change.
3. Implement the frontend client/UI change.
4. Verify both sides with their narrow checks.

If only one thread is working, it may do all four steps. If multiple threads are working, one thread owns the contract change and announces it before the other thread depends on it.

## Reserved Local Ports

| Service | Port |
| --- | --- |
| OfferAtlas Pro | `5173` |
| Core API | `18080` |
| OfferAtlas DataAdmin | `6173` |
| DataAdmin API | `8010` |
| ScholarGraph | `8000` |
| PostgreSQL | `15432` |
| Redis | `16379` |
| Meilisearch | `17700` |
| MinIO API / Console | `9100` / `9101` |

## Database Ownership

| Database | Owner |
| --- | --- |
| `offeratlas_core` | `offeratlas-core-api` |
| `offeratlas_scholar` | `OfferAtlas ScholarGraph` |
| `offeratlas_crawler` | `OfferAtlas Crawler` |
| `offeratlas_data_admin` | `offeratlas-data-admin-api` |

## Branch Names

Use thread-scoped branches:

- `pro/<topic>`
- `core/<topic>`
- `data-admin-ui/<topic>`
- `data-admin-api/<topic>`
- `scholargraph/<topic>`
- `crawler/<topic>`
- `docs/<topic>`

Avoid multiple threads committing directly to the same branch at the same time. If two threads must touch the same repo, split files clearly and coordinate before editing.

## Before You Edit

Run these in the repository you own:

```powershell
git status --short
git branch --show-current
```

Then check:

- Am I inside the directory owned by this thread?
- Does this task require a contract/doc update?
- Am I about to touch a file that belongs to another thread?
- Are there uncommitted changes I did not make?

If there are unrelated uncommitted changes, leave them alone.

## Verification By Thread

Core API:

```powershell
cd "D:\dev-env\workspace\OfferAtlas\offeratlas-core-api"
mvn test
```

Pro frontend:

```powershell
cd "D:\dev-env\workspace\OfferAtlas\OfferAtlas Pro"
npm run build
```

DataAdmin API:

```powershell
cd "D:\dev-env\workspace\OfferAtlas\offeratlas-data-admin-api"
.\.venv\Scripts\python.exe -m pytest
```

DataAdmin frontend:

```powershell
cd "D:\dev-env\workspace\OfferAtlas\OfferAtlas DataAdmin"
npm run build
```

ScholarGraph:

```powershell
cd "D:\dev-env\workspace\OfferAtlas\OfferAtlas ScholarGraph"
.\.venv\Scripts\python.exe -m compileall app
```

Crawler:

```powershell
cd "D:\dev-env\workspace\OfferAtlas\OfferAtlas Crawler"
.\.venv\Scripts\python.exe -m compileall src
```

## Merge Discipline

- Commit each repository separately.
- Push each repository separately.
- In the final handoff, list every repo changed, commit hash, and verification command.
- For cross-repo work, mention which commits depend on each other.
