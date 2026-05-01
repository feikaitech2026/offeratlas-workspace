# OfferAtlas 项目状态总览

最后更新：2026-05-01

这个文件是本地多仓库工作区的轻量总控板，只记录当前状态、优先级和运行约定。更详细的产品、接口、数据库和部署设计，仍然放在 `OfferAtlas Docs/` 或对应服务文档里。

## 服务快照

| 服务 | 仓库目录 | 当前本地信号 | 备注 |
| --- | --- | --- | --- |
| B 端前端 | `OfferAtlas Pro/` | `npm run build` 通过 | 只访问 Core API。 |
| C 端前端 | `OfferAtlas Student/` | `npm run build` 通过 | 已完成学生端前端脚手架。 |
| Core API | `offeratlas-core-api/` | `mvn test` 通过 | 负责认证、租户、RBAC、学生和申请业务数据。 |
| 数据平台前端 | `OfferAtlas DataAdmin/` | `npm run build` 通过，有大包体积提示 | 只访问 DataAdmin API。 |
| DataAdmin API | `offeratlas-data-admin-api/` | `pytest` 通过 | 负责数据平台报表和 `offeratlas_data_admin` 状态。 |
| ScholarGraph | `OfferAtlas ScholarGraph/` | `compileall app` 通过 | 负责院校/专业知识库、搜索和匹配。 |
| Crawler | `OfferAtlas Crawler/` | `compileall src` 通过 | 负责公开数据采集和导出。 |
| 文档仓库 | `OfferAtlas Docs/` | 手动维护 | 架构、接口、数据库和部署文档的事实来源。 |

## 当前优先级

1. 四个活跃开发线程严格遵守 `THREADS.md` 里的目录边界。
2. 每次开工前和收工前运行 `tools\git-status-all.ps1`。
3. 每个子项目提交前先跑自己的最小检查命令。
4. 前后端联调前先更新接口契约文件。
5. 本地全链路跑稳定前，不急着购买或配置阿里云资源。

## 本地待办

- DataAdmin 前端构建包较大，后续可以做路由级拆包。
- 根目录 meta 仓库已经配置远程：`git@github.com:feikaitech2026/offeratlas-workspace.git`。
- `AGENTS.md` 中有中文内容，如果 PowerShell 代码页不对，终端里可能显示乱码；文件本身仍作为根目录代理规则。

## 本地端口表

| 组件 | 端口 |
| --- | --- |
| OfferAtlas Pro | `5173` |
| OfferAtlas Student | 建议 `5174`，便于和 Pro 同时运行 |
| Core API | `18080` |
| OfferAtlas DataAdmin | `6173` |
| DataAdmin API | `8010` |
| ScholarGraph | `8000` |
| PostgreSQL | `15432` |
| Redis | `16379` |
| Meilisearch | `17700` |
| MinIO API / Console | `9100` / `9101` |
