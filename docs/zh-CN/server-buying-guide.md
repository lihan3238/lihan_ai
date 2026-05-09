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

这足够运行 New API、PostgreSQL、Redis、Caddy、Uptime Kuma 和轻量流量。除非只是短暂 smoke test，不建议用 1 GB RAM 实例；PostgreSQL、Docker 和镜像升级会让内存余量太小。

## 生产拓扑

面向中国大陆用户时，使用两个角色：

- **Origin server**：运行 New API、PostgreSQL、Redis、Caddy、Uptime Kuma、备份和所有 secrets。你当前 Hostinger 2 vCPU / 8 GB / 100 GB 服务器，如果出站 API 连接稳定，可以作为初始 origin。
- **Edge VPS**：可选中国优化反向代理，只运行 `docker-compose.edge.yml` 中的 Caddy。它不应保存 PostgreSQL、Redis、New API tokens、上游 provider keys 或 `.env.production`。

这样未来迁移 origin 时，不必每次更换公开 edge IP。小范围试用可以先只用 origin；如果国内延迟是主要问题，再增加 edge。

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

不要长期在这个规格上跑公开收费流量。拉镜像、备份或流量波动时，内存压力可能导致服务不稳定。

## 升级触发条件

满足以下任一情况时，升级到 4 vCPU / 8 GB RAM：

- 超过 50 个活跃付费用户。
- PostgreSQL 内存或 CPU 长期偏高。
- 上游响应正常，但本地 New API 延迟变高。
- 备份或日志处理影响 API 流量。
- 增加自动支付、更丰富分析或本地自定义开发服务。

edge-only VPS 更看重线路质量而不是 CPU/RAM。1-2 vCPU / 1-2 GB RAM 的 CN2 GIA、CMI 或其他中国优化节点足够反代轻量 API 流量；优先购买更好的带宽，而不是更多 CPU。

## 购买检查清单

- 可开放 80 和 443 端口。
- 可运行 Docker Compose。
- 有 Ubuntu 24.04 LTS 镜像。
- 有 snapshots 或 backup 产品。
- 有 SSH、HTTP、HTTPS 的 firewall rules。
- 服务条款允许 API relay/proxy 类服务。
- 到 OpenAI、Anthropic、DeepSeek、Zhipu 和你选择的聚合商出站 HTTPS 稳定。
- 带宽超额价格可预测。

## Provider Notes

- Hetzner Cloud 在欧洲、美国和新加坡性价比较高。Hetzner 将 shared plans 描述为适合 development、小型数据库和中低流量，dedicated vCPU plans 适合持续高负载。
- Akamai/Linode 提供 2 GB 和 4 GB shared CPU plans，并有明确流量配额，便于成本规划。
- DigitalOcean 强调可预测月费、低价 Droplets、免费 cloud firewalls，以及从 500 GiB/month 起的出站流量。
- Vultr 可关注香港、新加坡、日本库存，但购买前要确认当前价格和地区库存。

本项目建议先买香港或新加坡最便宜的可靠 2 vCPU / 4 GB 机器。升级前和 New API 版本变更前启用 one-click snapshots。

Sources checked on 2026-05-08:

- Hetzner Cloud: https://www.hetzner.com/cloud/
- Akamai Cloud pricing: https://www.linode.com/pricing/
- DigitalOcean pricing: https://www.digitalocean.com/pricing
- Vultr pricing: https://www.vultr.com/pricing/
