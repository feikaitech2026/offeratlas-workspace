# OfferAtlas Workspace

这是 `OfferAtlas` 的根目录总控仓库，用来管理多仓库协作规则、本地联调脚本、项目状态说明和工作区级文档。

它**不承载业务代码**，也**不合并**各子项目自己的 Git 历史。业务代码仍然分别放在下面 8 个独立仓库里。

## 根仓库职责

- 工作区规则：`AGENTS.md`
- 并行线程边界：`THREADS.md`
- 项目状态板：`PROJECT_STATUS.md`
- 本地辅助脚本：`tools/`
- 一键启动 / 暂停 / 状态入口

## 8 个子仓库入口

当前统一使用 GitHub 账号 `feikaitech2026`。

1. `OfferAtlas Pro/`
   - 仓库：[`offeratlas-pro`](https://github.com/feikaitech2026/offeratlas-pro)
   - 作用：B 端前端，顾问/机构工作台

2. `OfferAtlas Student/`
   - 仓库：[`offeratlas-student`](https://github.com/feikaitech2026/offeratlas-student)
   - 作用：C 端前端，学生/家长门户

3. `offeratlas-core-api/`
   - 仓库：[`offeratlas-core-api`](https://github.com/feikaitech2026/offeratlas-core-api)
   - 作用：核心业务后端，认证、租户、RBAC、学生、申请等

4. `OfferAtlas ScholarGraph/`
   - 仓库：[`offeratlas-scholargraph`](https://github.com/feikaitech2026/offeratlas-scholargraph)
   - 作用：院校/项目知识库、搜索、匹配、解释

5. `OfferAtlas Crawler/`
   - 仓库：[`offeratlas-crawler`](https://github.com/feikaitech2026/offeratlas-crawler)
   - 作用：公开院校与项目数据采集、解析、导出

6. `OfferAtlas DataAdmin/`
   - 仓库：[`offeratlas-data-admin`](https://github.com/feikaitech2026/offeratlas-data-admin)
   - 作用：数据平台前端

7. `offeratlas-data-admin-api/`
   - 仓库：[`offeratlas-data-admin-api`](https://github.com/feikaitech2026/offeratlas-data-admin-api)
   - 作用：数据平台后端、报表与治理接口

8. `OfferAtlas Docs/`
   - 仓库：[`offeratlas-docs`](https://github.com/feikaitech2026/offeratlas-docs)
   - 作用：架构、接口、数据库、部署与迁移文档

## 本地一键联调

根目录已经提供一套统一的本地控制脚本：

- [一键启动.cmd](/d:/dev-env/workspace/OfferAtlas/一键启动.cmd)
- [一键暂停.cmd](/d:/dev-env/workspace/OfferAtlas/一键暂停.cmd)
- [一键状态.cmd](/d:/dev-env/workspace/OfferAtlas/一键状态.cmd)

对应 PowerShell 脚本在：

- [tools/start-local-stack.ps1](/d:/dev-env/workspace/OfferAtlas/tools/start-local-stack.ps1)
- [tools/stop-local-stack.ps1](/d:/dev-env/workspace/OfferAtlas/tools/stop-local-stack.ps1)
- [tools/status-local-stack.ps1](/d:/dev-env/workspace/OfferAtlas/tools/status-local-stack.ps1)

### 启动顺序

一键启动会按依赖顺序执行：

1. 启动基础设施容器
   - PostgreSQL
   - Redis
   - Meilisearch
   - MinIO

2. 确保 `offeratlas_data_admin` 数据库存在

3. 执行 `ScholarGraph` 迁移并启动服务

4. 启动 `Core API`

5. 执行 `DataAdmin API` 迁移并启动服务

6. 启动三个前端
   - Pro
   - Student
   - DataAdmin

### 暂停行为

一键暂停会：

1. 先停止本地应用进程
2. 再停止 `offeratlas-*` 基础设施容器
3. 同时清理旧的 `scholargraph-*` 独立容器残留
4. 清空 PID 记录

### 状态查看

一键状态会显示：

- 当前受管应用端口是否在线
- 当前受管 Docker 容器状态
- 历史 `scholargraph-*` 容器是否残留
- PID 文件记录

## 本地端口约定

| 组件 | 端口 |
| --- | --- |
| OfferAtlas Pro | `5173` |
| OfferAtlas Student | `5174` |
| OfferAtlas DataAdmin | `6173` |
| Core API | `18080` |
| ScholarGraph | `8000` |
| DataAdmin API | `8010` |
| PostgreSQL | `15432` |
| Redis | `16379` |
| Meilisearch | `17700` |
| MinIO API / Console | `9100` / `9101` |

## 日常命令

查看所有子仓库状态：

```powershell
.\tools\git-status-all.ps1
```

运行统一最小检查：

```powershell
.\tools\check-all.ps1
```

## 开工顺序

每次开新线程或接新任务，建议先看：

1. `AGENTS.md`
2. `THREADS.md`
3. 当前负责服务自己的 `README.md`
4. 如涉及接口或数据库，再看 `OfferAtlas Docs/`

## GitHub 账号资料补齐建议

你可以在新账号里顺手补这几项，后面协作会更干净：

1. `Settings -> Public profile`
   - 补 `Name`
   - 补 `Bio`
   - 选一个稳定头像

2. `Settings -> Emails`
   - 添加常用邮箱
   - 设为主邮箱
   - 勾选需要的通知邮箱设置

3. `Settings -> Password and authentication`
   - 开启 2FA

4. `Settings -> SSH and GPG keys`
   - 保留当前正在用的新 SSH key
   - 如果旧账号 key 以后彻底不用，就不要再加回去
