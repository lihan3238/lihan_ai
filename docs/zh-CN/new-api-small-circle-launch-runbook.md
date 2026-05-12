# New API Small Circle Launch Runbook

中文标题：New API 小范围宣传与套餐配置 Runbook

本文档用于朋友小范围内测上线。第一阶段保持配置优先：不做落地页、不接在线支付、不新增计费表、不大改 New API 前端。

## 定位

公开表达：

- 稳定安全，API 供应尽量来自官方正价购买渠道。
- 可以自由选择多家优秀模型，不被单一厂商限制。
- 朋友小范围使用，人工支持，fair use，不转售。

避免这些表达：

- 不限量。
- 全网最低价。
- 把 station quota 说成官方真实美元余额。
- 在 Linux.do 发宣传帖。Linux.do 只作为市场调研来源；正式文案用于 WeChat Moments 和私聊。

## 后台配置

上线前在 New API 后台配置：

- 系统名、Logo、公开地址、文档链接、About、FAQ、公告。
- 额度显示使用自定义口径，统一叫 station quota / 站内额度。
- 页面必须写清楚：station quota is not official USD balance。
- 用户组保持简单：普通朋友用 `default`，高频或高优先级用户手动授予 `vip`。

建议公告：

```text
这是朋友小范围使用的 AI API relay。供应尽量来自官方 API 渠道，稳定性优先于最低价。用量按 station quota / 站内额度计，不是官方真实美元余额。请不要转售、共享账号或进行异常高并发使用。
```

## 套餐

第一阶段使用 New API 订阅计划并手动开通，收款放在微信外部完成。

| 套餐 | 价格 | station quota | 重置 / 有效期 | 分组 |
| --- | ---: | ---: | --- | --- |
| 体验 | 5 元 | 20 | 1 天 | `default` |
| Basic | 50 元 | 30 | 每周重置 | `default` |
| Plus | 100 元 | 100 | 每周重置 | `default` |
| Pro | 200 元 | 250 | 每周重置 | `default` |
| Heavy | 1000 元 | 150 | 每天重置 | `vip` |

manual activation 流程：

1. 微信收款。
2. 在 New API 找到或创建用户。
3. 设置 `default` 或 `vip`。
4. 绑定对应订阅计划。
5. 发给用户 API base URL、创建 token 的方法和 fair use 说明。

## 前端补丁策略

生产默认使用官方镜像：

```env
NEW_API_IMAGE=calciumion/new-api:latest
DEPLOY_INCLUDE_LOCAL_NEW_API_BUILD=0
```

上游 PR #4787 已合入 New API `v1.0.0-rc.5`，`calciumion/new-api:latest`
现在包含 dropdown `onSelect` 修复。生产 promote 前先拉取官方镜像，并在本机恢复栈上跑同一套 E2E。
如果官方 latest 仍未通过后台 E2E，才把临时补丁镜像作为 rollback 路径：

```env
DEPLOY_INCLUDE_LOCAL_NEW_API_BUILD=1
DEPLOY_LOCAL_NEW_API_BUILD_MODE=pull
LOCAL_NEW_API_IMAGE=ghcr.io/lihan3238/new-api:f80e8ea6-dropdown
```

历史阻塞点在新前端：Users 页面行菜单里的 `Manage Bindings` 和 `Manage Subscriptions`
依赖 `DropdownMenuItem onSelect`，如果没有兼容处理，按钮会失效。临时本地修复是来自
`lihan3238/new-api` 的 submodule commit `f80e8ea6`；它包含 `5741c359` dropdown
`onSelect` 修复和 Docker build context 清理。保留上游 issue #4692 和 PR #4787 作为
release notes 背景，方便追溯 rollback 决策。

临时 rollback 镜像规则：

- 正常生产路径保持 `DEPLOY_INCLUDE_LOCAL_NEW_API_BUILD=0`。
- 只有 admin E2E 证明官方镜像仍失效时，才设置 `DEPLOY_INCLUDE_LOCAL_NEW_API_BUILD=1` 使用临时镜像。
- 生产优先使用 `DEPLOY_LOCAL_NEW_API_BUILD_MODE=pull`：在本地工作站或 CI 构建并推送补丁镜像，生产只拉取。只有内存足够的机器才用 `build` 在服务器上编译 New API 前端。
- `LOCAL_NEW_API_IMAGE` 使用非官方补丁 tag，例如 `ghcr.io/lihan3238/new-api:f80e8ea6-dropdown`；不要改成 `calciumion/new-api:latest`。现在 runtime check 会检查实际 `relay-new-api` 镜像；如果开了本地构建但仍在跑官方镜像，会直接失败。
- 临时镜像只能包含 dropdown `onSelect` 修复。
- 不把套餐、品牌、支付、计费逻辑混进这个前端补丁。

## Admin 前端 E2E

上线前执行：

```bash
NEW_API_BASE_URL=https://api.lihan3238.com \
NEW_API_ADMIN_USERNAME=<admin> \
NEW_API_ADMIN_PASSWORD=<password> \
bash ops/check-new-api-admin-frontend.sh
```

验证临时本地补丁时执行：

```bash
CHECK_LOCAL_NEW_API_PATCH=1 \
NEW_API_BASE_URL=http://localhost:3100 \
NEW_API_ADMIN_USERNAME=<admin> \
NEW_API_ADMIN_PASSWORD=<password> \
bash ops/check-new-api-admin-frontend.sh
```

预期结果：

- Users 页面能打开。
- 行操作菜单能打开。
- `Manage Bindings` 能打开账号绑定管理弹窗。
- `Manage Subscriptions` 能打开用户订阅管理弹窗。
- `CHECK_LOCAL_NEW_API_PATCH=1` 时，会对 `vendor/new-api/web/default` 跑 `npm run typecheck`、`npm run build`，并检查 dropdown-menu.test.tsx 补丁文件。

## WeChat Moments 文案

```text
我最近把自己的 AI API 中转站整理稳定了，准备小范围给朋友用。

主打两个点：
1. 供应尽量走官方正价 API 渠道，优先稳定和安全。
2. 不绑定单一厂商模型，OpenAI / Claude / Gemini / GLM 等模型可以按场景自由选。

适合：写代码、接 AI 客户端、做小工具、学习测试。
不适合：转售、共享刷量、超高并发薅额度、追求最低价无限用。

目前先做熟人小范围：
5 元体验：20 station quota / 1 天
50 元：30 station quota / 每周重置
100 元：100 station quota / 每周重置
200 元：250 station quota / 每周重置
1000 元：150 station quota / 每天重置，高频用户

station quota 是本站内部站内额度，不是官方真实美元余额。
想试的微信私聊我，我手动开通。
```

## 验收清单

- 页面文案使用 station quota / 站内额度，并说明 not official USD balance。
- 当前业务分组只保留 `default` 和 `vip`。
- 五个订阅套餐都按上表配置。
- manual activation 流程对运营者和用户都讲清楚。
- `ops/check-new-api-admin-frontend.sh` 对目标环境通过。
- `DEPLOY_INCLUDE_LOCAL_NEW_API_BUILD` 要么是 `0` 使用官方镜像，要么明确记录为 `1` 使用 dropdown 修复的临时自定义镜像。
