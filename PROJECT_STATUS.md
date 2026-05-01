# OfferAtlas Project Status

Last updated: 2026-05-01

This is a lightweight control board for the local multi-repo workspace. Keep it
short and operational. Detailed design belongs in `OfferAtlas Docs/` or the
owning service docs.

## Service Snapshot

| Service | Repository | Current local signal | Notes |
| --- | --- | --- | --- |
| B-side frontend | `OfferAtlas Pro/` | `npm run build` passes | Calls Core API only. |
| Student frontend | `OfferAtlas Student/` | `npm run build` passes | Newly scaffolded C-side app. |
| Core API | `offeratlas-core-api/` | `mvn test` passes | Owns auth, tenants, RBAC, student/application data. |
| DataAdmin frontend | `OfferAtlas DataAdmin/` | `npm run build` passes with a large chunk warning | Calls DataAdmin API only. |
| DataAdmin API | `offeratlas-data-admin-api/` | `pytest` passes | Owns data platform reporting and `offeratlas_data_admin` state. |
| ScholarGraph | `OfferAtlas ScholarGraph/` | `compileall app` passes | Owns school/program knowledge and matching. |
| Crawler | `OfferAtlas Crawler/` | `compileall src` passes | Owns public data collection and exports. |
| Docs | `OfferAtlas Docs/` | Manual docs repo | Source of truth for architecture, API, database, deployment notes. |

## Current Priorities

1. Keep the four active coding threads inside the ownership boundaries in
   `THREADS.md`.
2. Run `tools\git-status-all.ps1` before and after each work session.
3. Run the narrow service check before committing a service repository.
4. Keep API contract files updated before frontend/backend integration.
5. Do not buy or configure cloud infrastructure until the local full chain is
   stable.

## Known Local Follow-Ups

- DataAdmin frontend bundle is large; consider route-level code splitting later.
- Root meta repo has no remote configured yet.
- `AGENTS.md` contains Chinese text that may display incorrectly in some
  PowerShell code pages; the file itself remains the root agent guide.

## Local Port Map

| Component | Port |
| --- | --- |
| OfferAtlas Pro | `5173` |
| OfferAtlas Student | `5174` suggested if run together with Pro |
| Core API | `18080` |
| OfferAtlas DataAdmin | `6173` |
| DataAdmin API | `8010` |
| ScholarGraph | `8000` |
| PostgreSQL | `15432` |
| Redis | `16379` |
| Meilisearch | `17700` |
| MinIO API / Console | `9100` / `9101` |
