# 用户详细指南

Lihan AI Relay 是面向熟人小范围使用的 AI API relay。它提供 OpenAI-compatible API 地址，并通过人工支持接入多个模型。

## 服务边界

适合：

- 支持 OpenAI-compatible API 的 AI 客户端。
- 编程助手和本地自动化。
- 学习、测试、个人效率工具。
- 中低频的小脚本。

不适合：

- 共享账号或转售。
- 压测、爬取、异常高并发。
- 需要正式 SLA 的生产服务。
- 把站内额度当作官方上游 USD 余额。

## 账号和 Key

1. 打开 `https://api.lihan3238.com`。
2. 登录已开通账号。
3. 在控制台创建 API Key。
4. 把 Key 存进密码管理器或本地 secret store。
5. 不再使用的旧 Key 及时删除。

不要把 API Key 粘贴到公开聊天、截图、GitHub issue 或客户端日志里。

## 客户端配置

默认配置：

| 字段 | 值 |
| --- | --- |
| Provider 类型 | OpenAI-compatible |
| API Base URL | `https://api.lihan3238.com/v1` |
| API Key | 你的 New API token |
| Model | 从控制台或群公告里选择 |

有些客户端会自动追加 `/v1`。如果客户端要求只填主域名，可以填 `https://api.lihan3238.com`。

## API 测试命令

替换 `YOUR_KEY` 和模型名：

```bash
curl https://api.lihan3238.com/v1/chat/completions \
  -H "Authorization: Bearer YOUR_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "glm-5.1",
    "messages": [
      { "role": "user", "content": "Say hello in one sentence." }
    ]
  }'
```

## 额度和套餐

- 额度由本站管理。
- 套餐名和额度口径不等同于上游官方计费单位。
- 上游可用性、模型路由和价格可能变化。
- 生产任务或批量任务先和维护者确认。

## 常见问题

### 401 或 unauthorized

检查 API Key 是否复制完整，以及账号是否仍处于启用状态。

### model not found

使用控制台或最新群公告里的模型名。部分客户端会缓存模型列表，必要时重启客户端。

### 流式输出断开

先试一次非流式。如果非流式可用，反馈客户端、模型和流式设置。

### 额度和官方 USD 不一致

这是正常现象。本 relay 使用站内 station quota 和套餐规则，不展示官方 USD 余额。

## 故障反馈模板

```text
时间：
账号用户名：
客户端：
模型：
是否流式：是/否
错误信息：
request id，如果页面有显示：
大概输入长度：
是否能稳定复现：
```
