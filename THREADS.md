# OfferAtlas 多线程开发协作指南

这个文件是多个编码代理或多个 IDE 线程同时开发 OfferAtlas 时的快速规则表。目标是让每个线程只改自己负责的区域，避免互相踩代码、抢端口或改错数据库。

## 线程归属

| 线程 | 目录 | 负责内容 | 默认不要改 |
| --- | --- | --- | --- |
| B 端前端 | `OfferAtlas Pro/` | 顾问端/机构端界面、路由、前端 API client | Core API 实现、ScholarGraph、DataAdmin |
| B 端后端 | `offeratlas-core-api/` | 认证、租户、RBAC、学生、申请、Core API 契约 | Pro 界面、DataAdmin 前后端、Crawler 直写 |
| 数据平台前端 | `OfferAtlas DataAdmin/` | 数据治理看板界面、DataAdmin 前端 client | DataAdmin 后端逻辑、Core API |
| 数据平台后端 | `offeratlas-data-admin-api/` | 数据治理/报表 API、只读聚合查询、`offeratlas_data_admin` 状态 | Pro 界面、Core 业务逻辑、Crawler 写入 |

辅助服务：

- `OfferAtlas ScholarGraph/`：院校/专业知识服务，负责搜索、匹配和消费 Crawler 导出。
- `OfferAtlas Crawler/`：公开数据采集和导出。
- `OfferAtlas Docs/`：共享接口、数据库、架构和部署文档。
- `OfferAtlas-Secrets/`：本地密钥目录，禁止提交。

## 硬边界

- 前端只访问自己的后端：
- `OfferAtlas Pro -> offeratlas-core-api`
- `OfferAtlas DataAdmin -> offeratlas-data-admin-api`
- Core API 通过内部接口访问 ScholarGraph。
- DataAdmin API 可以读取 ScholarGraph/Crawler 数据库做报表，但只能写自己的 DataAdmin 数据库。
- 不要新增前端直连 ScholarGraph。
- 不要新增 Crawler 直写 Core 业务库。
- 不要在不同服务数据库之间新增共享表。

## 接口契约规则

跨前后端边界的改动按这个顺序做：

1. 先更新对应 README 或 docs 里的接口契约。
2. 再实现后端 controller/schema/持久化。
3. 再实现前端 client/UI。
4. 最后分别跑前后端的最小检查。

如果只有一个线程工作，可以一个线程完成四步。如果多个线程并行，一个线程负责先确认契约，另一个线程再基于契约实现。

## 本地端口

| 服务 | 端口 |
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

## 数据库归属

| 数据库 | 归属服务 |
| --- | --- |
| `offeratlas_core` | `offeratlas-core-api` |
| `offeratlas_scholar` | `OfferAtlas ScholarGraph` |
| `offeratlas_crawler` | `OfferAtlas Crawler` |
| `offeratlas_data_admin` | `offeratlas-data-admin-api` |

## 分支命名

建议按线程命名分支：

- `pro/<topic>`
- `core/<topic>`
- `data-admin-ui/<topic>`
- `data-admin-api/<topic>`
- `scholargraph/<topic>`
- `crawler/<topic>`
- `docs/<topic>`

尽量避免多个线程同时直接提交到同一个分支。如果两个线程必须改同一个仓库，先拆清楚文件范围，再开始编辑。

## 开始编辑前

在自己负责的仓库里先运行：

```powershell
git status --short
git branch --show-current
```

然后确认：

- 我现在是不是在本线程负责的目录里？
- 这个任务是否需要更新接口契约？
- 我是不是要改到别的线程负责的文件？
- 当前仓库里有没有别人留下的未提交改动？

如果看到无关的未提交改动，不要回滚，不要覆盖，先绕开。

## 各线程检查命令

Core API：

```powershell
cd "D:\dev-env\workspace\OfferAtlas\offeratlas-core-api"
mvn test
```

B 端前端：

```powershell
cd "D:\dev-env\workspace\OfferAtlas\OfferAtlas Pro"
npm run build
```

数据平台 API：

```powershell
cd "D:\dev-env\workspace\OfferAtlas\offeratlas-data-admin-api"
.\.venv\Scripts\python.exe -m pytest
```

数据平台前端：

```powershell
cd "D:\dev-env\workspace\OfferAtlas\OfferAtlas DataAdmin"
npm run build
```

ScholarGraph：

```powershell
cd "D:\dev-env\workspace\OfferAtlas\OfferAtlas ScholarGraph"
.\.venv\Scripts\python.exe -m compileall app
```

Crawler：

```powershell
cd "D:\dev-env\workspace\OfferAtlas\OfferAtlas Crawler"
.\.venv\Scripts\python.exe -m compileall src
```

## 合并和提交纪律

- 每个子仓库单独提交。
- 每个子仓库单独推送。
- 最终交付时列出改过的仓库、提交哈希和验证命令。
- 如果一次任务涉及多个仓库，要说明这些提交之间的依赖关系。
