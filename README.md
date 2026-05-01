# OfferAtlas Workspace Control

This root directory is the OfferAtlas meta workspace. It exists to coordinate the
independent service repositories below it without mixing their Git histories.

## What This Repo Owns

- Workspace rules: `AGENTS.md`, `THREADS.md`
- Overall status: `PROJECT_STATUS.md`
- Local orchestration helpers: `tools/`
- Root ignore rules and workspace notes

## What This Repo Does Not Own

The service directories are independent Git repositories:

- `OfferAtlas Pro/`
- `OfferAtlas Student/`
- `offeratlas-core-api/`
- `OfferAtlas DataAdmin/`
- `offeratlas-data-admin-api/`
- `OfferAtlas ScholarGraph/`
- `OfferAtlas Crawler/`
- `OfferAtlas Docs/`

Do not add those directories to the root repository. Commit and push each service
inside its own repository.

## Daily Commands

Show all service repository states:

```powershell
.\tools\git-status-all.ps1
```

Run the standard local verification checks:

```powershell
.\tools\check-all.ps1
```

The check script runs builds/tests only. It does not start services, stop
services, run database migrations, or modify databases.

## Working Rules

Before assigning a coding thread, read:

1. `AGENTS.md`
2. `THREADS.md`
3. The owned service README or docs

For cross-service work, update the API contract first, then implement each side
inside its own repository.
