# 服务器购买指南

## 推荐起步规格

先购买一台海外 Linux VPS。推荐基线：

- 2 vCPU。
- 4 GB RAM。
- 60-80 GB SSD/NVMe 磁盘。
- 每月 2 TB 或更多流量。
- Ubuntu 24.04 LTS。
- 公网 IPv4。
- 支持 provider firewall。
- 支持 snapshot 或 backup。

这足够运行 New API、PostgreSQL、Redis、Caddy 或 Cloudflare Tunnel、可选 CPA 和小范围私用流量。除非只是短暂 smoke test，不建议用 1 GB RAM 实例；PostgreSQL、Docker 和镜像升级都会吃掉余量。

## 生产拓扑

面向中国大陆用户时使用两个角色：

- **Origin server**：运行 New API、PostgreSQL、Redis、Caddy 或 Cloudflare Tunnel、可选 CPA、本地备份和所有 secrets。当前 Hostinger 2 vCPU / 8 GB / 100 GB 服务器，如果出站 API 连接稳定，可以作为初始 origin。
- **Edge VPS**：可选中国优化反向代理，只运行 `docker-compose.edge.yml` 中的 Caddy。它不应保存 PostgreSQL、Redis、New API token、上游 provider key 或 `.env.production`。

小范围试用可以先只用 origin；只有国内延迟成为主要问题时再加 edge。

## 地区

早期优先地区：

- 香港、新加坡、日本或美国西海岸，如果价格和稳定性合适。
- 香港太贵时，新加坡通常是实用默认选项。
- V1 不建议使用中国大陆服务器，除非你已经准备好 ICP 备案、本地合规和更复杂的海外 API 连接。

## 最低可接受规格

只适合临时测试：

- 1 vCPU。
- 2 GB RAM。
- 40 GB 磁盘。
- 1 TB 流量。

不要长期承载公开付费流量。拉镜像、备份或流量尖峰时，内存压力会让服务不稳定。

## 升级触发

出现任一情况时，升级到 4 vCPU / 8 GB RAM：

- 活跃付费用户超过 50。
- PostgreSQL 内存或 CPU 长期偏高。
- 上游响应正常但本地 New API 延迟变慢。
- 备份影响 API 流量。
- 增加自动支付、更丰富分析或本地二开服务。

对于只做 edge 的 VPS，线路质量比 CPU/RAM 更重要。1-2 vCPU / 1-2 GB RAM 的中国优化节点足够轻量反代；优先买更好的带宽。

## 购买清单

- 直连 Caddy 模式可以开放 80 和 443。
- Tunnel 模式允许出站连接 Cloudflare。
- 可以运行 Docker Compose。
- 有 Ubuntu 24.04 LTS 镜像。
- 有 snapshot 或 backup 产品。
- 有 SSH、HTTP、HTTPS firewall 规则。
- 服务条款允许 API relay/proxy 类服务。
- 出站 HTTPS 到你选择的上游模型供应商稳定。
- 流量超额价格可预期。

## Origin 和 Edge 布局

面向中国大陆用户：

- Origin：New API、PostgreSQL、Redis、Caddy 或 Cloudflare Tunnel、可选 CPA、本地备份。
- Edge：只做 Caddy 反向代理，没有数据库，也没有上游 API key。

当前 Hostinger 服务器如果上游 API 连通稳定，足够支撑早期私用流量。如果国内延迟差，先购买中国优化 edge VPS，把公网 API 域名指向 edge。

部署 edge 见 `docs/zh-CN/edge-proxy-runbook.md`；如果后续 edge 升级为新 origin，按 `docs/zh-CN/migration-runbook.md`。
