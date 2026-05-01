# OfferAtlas 工作区总控仓库

这个根目录是 OfferAtlas 的总控工作区，用来管理多仓库协作规则、全局状态和本地辅助脚本。它不承载业务代码，也不合并各子项目的 Git 历史。

## 这个仓库管理什么

- 工作区规则：`AGENTS.md`、`THREADS.md`
- 项目总览：`PROJECT_STATUS.md`
- 本地辅助脚本：`tools/`
- 根目录忽略规则和总控说明

## 这个仓库不管理什么

下面这些目录都是独立 Git 仓库，需要进入各自目录单独提交和推送：

- `OfferAtlas Pro/`
- `OfferAtlas Student/`
- `offeratlas-core-api/`
- `OfferAtlas DataAdmin/`
- `offeratlas-data-admin-api/`
- `OfferAtlas ScholarGraph/`
- `OfferAtlas Crawler/`
- `OfferAtlas Docs/`

不要把这些子项目目录加入根仓库。根仓库只记录总控文件和辅助脚本。

## 日常命令

查看所有子仓库状态：

```powershell
.\tools\git-status-all.ps1
```

运行本地标准检查：

```powershell
.\tools\check-all.ps1
```

`check-all.ps1` 只运行构建和测试，不会启动服务、停止服务、执行数据库迁移，也不会修改数据库。

## 开工顺序

每次开新线程或新任务前，建议按顺序阅读：

1. `AGENTS.md`
2. `THREADS.md`
3. 当前负责子项目的 README 或接口文档

涉及前后端或跨服务联调时，先更新接口契约，再分别修改对应服务。
