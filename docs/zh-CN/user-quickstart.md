# 用户快速接入

这份文档给 Lihan AI Relay 内测用户使用，目标是 5 分钟内完成第一次调用。

## 你需要准备

- 控制台：`https://api.lihan3238.com`
- API Base URL：`https://api.lihan3238.com/v1`
- 一个已经手动开通的 New API 账号。
- 支持 OpenAI-compatible API 的客户端，例如 Chatbox、Cherry Studio、Open WebUI、Cline，或者你自己的脚本。

## 五分钟配置

1. 登录 `https://api.lihan3238.com`。
2. 进入 token / API key 页面。
3. 创建一个新的 API Key。
4. 在客户端里选择 OpenAI-compatible provider。
5. Base URL 填 `https://api.lihan3238.com/v1`。
6. 粘贴 API Key。
7. 选择可用模型，发一条短测试消息。

## 使用规则

- 不共享账号和 API Key。
- 不要把 Key 发到群里。
- 不转售。
- 批量任务、高并发或生产用途先私聊确认。
- 站内额度是 relay 的 station quota，不是官方 USD 余额。

## 出问题时怎么反馈

按这个格式发给群里或维护者：

```text
时间：
客户端：
模型：
是否流式：是/否
错误信息：
request id，如果页面有显示：
你当时在做什么：
```

详细说明见 [docs/zh-CN/user-guide.md](user-guide.md)。
