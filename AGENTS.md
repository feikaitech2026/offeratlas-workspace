# OfferAtlas Agent Guide

本文件用于给 Codex、Claude Code、Copilot Agent 等编码代理提供根目录级工作约定。修改代码前优先阅读本文件，再阅读对应子项目 README 和 `OfferAtlas Docs/` 下的接口、数据库、部署文档。

## Project Map

- `OfferAtlas Pro/`: B 端前端，面向留学机构顾问、文书老师、申请老师和机构管理员。
- `OfferAtlas Student/`: C 端前端，面向学生和家长。
- `offeratlas-core-api/`: Java Spring Boot 核心业务后端，负责认证、租户、RBAC、学生、申请、文书、文件、消息、套餐、审计和平台后台。
- `OfferAtlas ScholarGraph/`: Python FastAPI 院校知识服务，负责正式院校库、专业库、搜索索引、智能匹配、推荐解释和院校事实数据。
- `OfferAtlas Crawler/`: Python 数据采集器，负责公开院校/项目/录取要求采集、暂存、解析和导出。
- `OfferAtlas Docs/`: 产品、接口、数据库、架构、部署与迁移文档。
- `OfferAtlas-Secrets/`: 本地密钥备份目录，禁止提交到 Git。
- `tools/`: 本地辅助脚本。

## Source Of Truth

- 架构与服务边界以 `OfferAtlas Docs/OfferAtlas技术架构与阿里云部署方案.docx` 为准。
- Core API 接口以 `OfferAtlas Docs/OfferAtlas Core API接口定义文档.docx` 为准。
- ScholarGraph 接口以 `OfferAtlas Docs/OfferAtlas ScholarGraph接口定义文档.docx` 为准。
- Core 数据库以 `OfferAtlas Docs/OfferAtlas Core数据库表结构设计文档.docx` 和 `offeratlas-core-api/src/main/resources/db/migration/` 为准。
- ScholarGraph 数据库以 `OfferAtlas Docs/OfferAtlas ScholarGraph数据库表结构设计文档.docx` 和 `OfferAtlas ScholarGraph/migrations/` 为准。
- 数据库部署与迁移以 `OfferAtlas Docs/OfferAtlas数据库配置与阿里云迁移方案.docx` 为准。

如果文档、README 和代码不一致，先确认当前实现，再尽量让代码、迁移和文档同步更新。

## Service Boundaries

- 前端只访问 Core API，不直接访问 ScholarGraph。
- Core API 通过内部接口调用 ScholarGraph 获取院校搜索、智能匹配和推荐解释。
- ScholarGraph 不处理租户权限，不创建申请，不直接保存 B/C 端业务数据。
- Crawler 不直接写 Core 业务库；采集数据经清洗、审核、导出后由 ScholarGraph 消费。
- `applications` 需要保存院校/专业 snapshot，避免 ScholarGraph 后续更新影响历史申请。
- 匹配第一版采用规则引擎打分；AI 只负责解释、建议和文案增强，不直接决定 `match_score`。

## Databases

本地和生产均按一个 PostgreSQL 实例、多个 database 规划：

- `offeratlas_core`: Core API 业务数据，所有机构业务表必须包含 `tenant_id`，平台级配置可不带。
- `offeratlas_scholar`: ScholarGraph 正式院校、专业、排名、申请要求、搜索文档和匹配特征。
- `offeratlas_crawler`: Crawler 采集原始数据、暂存表、抓取页、采集日志和导出数据。

迁移归属：

- Core API 使用 Flyway，迁移目录为 `offeratlas-core-api/src/main/resources/db/migration/`。
- ScholarGraph 使用 Alembic，迁移目录为 `OfferAtlas ScholarGraph/migrations/`。
- Crawler 当前由 CLI 初始化采集表，避免混入 Core 或 ScholarGraph 的正式迁移。

## Secrets And Config

- 真实密钥、数据库密码、API Key、DeepSeek/OpenAI Key 只能放在 `OfferAtlas-Secrets/`、本地 `.env` 或生产密钥管理系统中。
- Git 只保存 `.env.example`，不要把真实 `.env`、私钥、证书或生产连接串写入代码、README、docx 或提交信息。
- AI 配置使用 OpenAI-compatible 变量：`AI_BASE_URL`、`AI_API_KEY`、`AI_MODEL`、`AI_PROVIDER`。
- AI 调用结果需要落库到 `ai_tasks` / `ai_results`，记录调用场景、模型、token、成本、发起人和审计信息。

## Common Commands

Core API:

```powershell
cd "D:\dev-env\workspace\OfferAtlas\offeratlas-core-api"
mvn test
mvn spring-boot:run
```

ScholarGraph:

```powershell
cd "D:\dev-env\workspace\OfferAtlas\OfferAtlas ScholarGraph"
python -m venv .venv
.\.venv\Scripts\activate
pip install -r requirements.txt
python -m alembic upgrade head
uvicorn app.main:app --reload
```

Crawler:

```powershell
cd "D:\dev-env\workspace\OfferAtlas\OfferAtlas Crawler"
python -m venv .venv
.\.venv\Scripts\activate
pip install -r requirements.txt
python -m src.main init-db
python -m src.main export
```

Local Docker Compose from Core API:

```powershell
cd "D:\dev-env\workspace\OfferAtlas\offeratlas-core-api"
docker compose -f docker-compose.local.yml up -d postgres redis minio meilisearch
docker compose -f docker-compose.local.yml up -d scholargraph-api core-api
```

## Coding Guidance

- Keep changes inside the relevant service unless the contract requires coordinated updates.
- When changing an API, update controller/schema code, persistence changes, and the matching API document or README notes.
- When changing database shape, add a migration in the owning service instead of editing existing historical migrations unless the project has not shipped and the user explicitly wants a reset.
- Preserve multi-tenant isolation in Core API. Any tenant business query should be scoped by `tenant_id`.
- Preserve source traceability in ScholarGraph: keep `source_id`, `source_url`, `source_updated_at` or equivalent fields when adding formal data.
- Preserve low-confidence extraction evidence in Crawler and ScholarGraph; do not discard raw text, source URL, hashes, or confidence fields casually.
- Use structured parsers and existing CLI/service patterns instead of ad hoc string manipulation where practical.
- Do not introduce direct frontend-to-ScholarGraph calls, direct Crawler-to-Core writes, or shared tables across service databases.

## Parallel Thread Rules / 并行线程规则

本工作区通常会由多个编码线程同时推进。除非用户明确要求跨服务联调，否则每个线程必须只待在自己的职责边界内。

线程归属：

- `OfferAtlas Pro/`：B 端前端，只改顾问端/机构端 UI、路由、前端 API client 和临时 mock。
- `offeratlas-core-api/`：B/C 端业务后端，负责认证、租户、RBAC、学生、申请业务数据，以及对 ScholarGraph 的内部调用。
- `OfferAtlas DataAdmin/`：数据平台前端，只改数据治理看板 UI 和 DataAdmin API client。
- `offeratlas-data-admin-api/`：数据平台后端，负责数据治理/报表 API 和自己的 `offeratlas_data_admin` 状态。

默认不要跨线程改动：

- Pro 前端线程不要改 Core API 代码，除非用户明确要求同步接口实现。
- Core API 线程不要改 Pro 或 DataAdmin UI，除非用户明确要求前后端联调。
- DataAdmin 前端线程不要改 DataAdmin API，除非用户明确要求同步接口实现。
- DataAdmin API 线程不要改 Core API、ScholarGraph、Crawler 或前端代码，除非契约要求且用户确认范围。

不要靠猜字段协作，要靠接口契约：

- Pro 和 Core API 的改动，需要同步更新 Core API 契约文档或明确的 README 说明。
- DataAdmin 和 DataAdmin API 的改动，需要同步更新 DataAdmin API 契约文档或 README 说明。
- 前端可以在自己项目内加临时 mock，但必须标清楚是临时数据。

本地端口约定：

- `OfferAtlas Pro`：`5173`
- `offeratlas-core-api`：`18080`
- `OfferAtlas DataAdmin`：`6173`
- `offeratlas-data-admin-api`：`8010`
- `OfferAtlas ScholarGraph`：`8000`
- PostgreSQL：`15432`
- Redis：`16379`
- Meilisearch：`17700`
- MinIO：`9100` 和 `9101`

数据库边界：

- Core API 只写 `offeratlas_core`。
- ScholarGraph 只写 `offeratlas_scholar`。
- Crawler 只写 `offeratlas_crawler`。
- DataAdmin API 可以读取 ScholarGraph/Crawler 数据库，但只能写自己的 `offeratlas_data_admin` 数据库。
- 不要在不同服务数据库之间新增共享表。

分支建议：

- 优先使用线程命名分支，例如 `pro/<topic>`、`core/<topic>`、`data-admin-ui/<topic>`、`data-admin-api/<topic>`。
- 合并到 `main` 前，先跑当前服务自己的最小验证命令。
- 如果一次改动涉及多个仓库，每个仓库单独提交和推送，并在交付说明里写清楚跨仓库依赖。

线程开工前：

- 先读本文件，再读 `THREADS.md`，再读当前负责服务的 README。
- 在负责仓库里执行 `git status --short`，不要覆盖用户或其他线程留下的无关改动。
- 编辑前先确认这是单服务任务还是跨服务任务。

## Verification Checklist

Before handing work back:

- Run the narrowest useful tests or startup checks for the changed service.
- For Core API changes, prefer `mvn test`.
- For ScholarGraph changes, prefer import checks, Alembic upgrade checks, or endpoint smoke tests.
- For Crawler changes, prefer the relevant `python -m src.main ...` command with a small limit when possible.
- Confirm no secrets or generated local data were added.
- Mention any tests or checks that could not be run.
