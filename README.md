# 🗄️ Distributed DB Demo

A self-contained distributed database simulation built with **PostgreSQL**, **Node.js**, and **Docker Compose**. Demonstrates horizontal sharding, fault injection, live rebalancing, and a full observability stack — all running locally with a single command.

---

## 🏗️ Architecture

```
                        ┌─────────────────────────────────────┐
                        │           Backend (Node.js)          │
                        │        REST API  ·  Dashboard UI     │
                        └────────┬──────────────┬─────────────┘
                                 │              │
               ┌─────────────────┘              └──────────────────┐
               ▼                                                    ▼
      ┌─────────────────┐                               ┌─────────────────┐
      │    Master 1     │                               │    Master 2     │
      │ Food & Grocery  │                               │ Household/Non-  │
      │  (port 5432)    │                               │  Food (5433)    │
      └──┬───┬───┬──────┘                               └──┬───┬───┬──────┘
         │   │   │                                          │   │   │
    ┌────┘ ┌─┘ └─┐                                    ┌────┘ ┌─┘ └─┐
    ▼      ▼     ▼                                     ▼      ▼     ▼
 shard1  shard2 shard3                             shard4  shard5 shard6
 (5434)  (5435) (5436)                             (5437)  (5438) (5439)
```

| Layer | Stack |
|---|---|
| **Database** | PostgreSQL 15 (2 masters, 6 shards) |
| **Backend** | Node.js + Express |
| **Metrics** | Prometheus + cAdvisor + postgres-exporter |
| **Dashboards** | Grafana (auto-provisioned) |
| **Logging** | Loki + Promtail + Winston |
| **Orchestration** | Docker Compose |

---

## 🚀 Quick Start

### Prerequisites
- [Docker Desktop](https://www.docker.com/products/docker-desktop/) (with Compose)

### Run

```bash
git clone https://github.com/YOUR_USERNAME/distributed-db-demo.git
cd distributed-db-demo

# (Optional) configure credentials
cp .env.example .env

docker compose up -d
```

Wait ~30 seconds for all databases to initialize, then open:

| Service | URL |
|---|---|
| **Dashboard UI** | http://localhost:3000 |
| **Grafana** | http://localhost:3001 (admin / admin) |
| **Prometheus** | http://localhost:9090 |
| **Loki** | http://localhost:3100 |

---

## ✨ Features

### Data Management
- **Bulk insert** — generate N random items, auto-distributed across the least-loaded shards
- **Manual insert** — specify exact item name, ID, and stock count
- **Delete item** — remove a record from its master and all associated shards atomically
- **Live search** — filter the full row view by name or ID in real time

### Fault Simulation
- **Kill / Recover individual shards** via the dashboard UI or REST API
- **Kill all / Recover all** shards at once
- Shards remain **readable** even when their master is offline
- Writes fail gracefully when the master is unreachable

### Data Consistency
- **Sync** — re-inserts any master records missing from their target shards
- **Rebalance** — moves rows from the most-loaded to least-loaded shard within each master's domain

### Observability
- **Grafana dashboards** — CPU, memory, network, shard uptime timeline, container running time
- **Loki logs** — all insert/delete/error events shipped from the backend via Winston
- **Prometheus metrics** — custom `shard_online` and `shard_data_rows_total` gauges per shard
- **Event log / Sync log / Rebalance log** — viewable directly in the dashboard

---

## 📡 API Reference

| Method | Endpoint | Description |
|---|---|---|
| `GET` | `/api/health` | Health check |
| `GET` | `/api/status` | All node connectivity + row counts |
| `GET` | `/api/data` | All rows from every master and shard |
| `POST` | `/api/add-data` | Bulk insert `{ count, master }` |
| `POST` | `/api/insert-item` | Manual insert `{ id_barang?, nama_barang?, stok?, master? }` |
| `DELETE` | `/api/delete-item/:id` | Delete by ID from master + all shards |
| `GET` | `/api/lookup-item/:id` | Find which master owns an item |
| `POST` | `/api/kill-shard/:id` | Stop shard container (1–6) |
| `POST` | `/api/recover-shard/:id` | Start shard container and wait for readiness |
| `POST` | `/api/kill-all-shards` | Stop all 6 shards |
| `POST` | `/api/recover-all-shards` | Restart all 6 shards |
| `POST` | `/api/sync` | Re-sync master → shards |
| `POST` | `/api/rebalance` | Rebalance rows across shards |
| `GET` | `/api/events` | Event, sync, and rebalance logs |
| `GET` | `/metrics` | Prometheus metrics endpoint |

---

## 🔍 Checking Logs in Grafana

1. Open **http://localhost:3001** → **Explore** → select **Loki**
2. Switch to **Code** mode and use LogQL:

```logql
# All backend logs
{container="backend"}

# Manual inserts only
{container="backend"} |= "Manual insert"

# Deletions only
{container="backend"} |= "item_deleted"

# Specific item ID
{container="backend"} |= "9001"

# Parse as JSON and filter by field
{container="backend"} | json | event = "item_deleted"
```

---

## 📁 Project Structure

```
.
├── backend/
│   ├── server.js           # Express API + connection pools + metrics
│   ├── public/
│   │   └── index.html      # Dashboard SPA (vanilla JS)
│   ├── Dockerfile
│   └── package.json
├── dashboard/
│   ├── prometheus.yml       # Scrape config
│   ├── grafana-datasource.yml
│   ├── grafana-dashboards.yml
│   ├── db-dashboard.json    # Auto-provisioned Grafana dashboard
│   ├── loki-config.yml
│   └── promtail-config.yml
├── env/
│   ├── 01_master1_init.sql  # Schema + seed data for master1
│   ├── 02_master2_init.sql  # Schema + seed data for master2
│   └── 0[3-8]_shard*.sql   # Schema for each shard
├── docker-compose.yml
├── .env.example
└── README.md
```

---

## 🛠️ Tech Stack

- **PostgreSQL 15** — relational storage, one instance per node
- **Node.js 20 / Express 4** — REST API and static file serving
- **pg (node-postgres)** — connection pooling with per-node pools
- **prom-client** — custom Prometheus gauges and histograms
- **Winston + winston-loki** — structured logging shipped directly to Loki
- **Grafana / Loki / Promtail** — PLG observability stack
- **cAdvisor** — container resource metrics
- **postgres-exporter** — PostgreSQL-specific metrics

---

## ⚙️ Configuration

Copy `.env.example` to `.env` and edit before starting:

```env
POSTGRES_USER=postgres
POSTGRES_PASSWORD=your_secure_password
DB_USER=postgres
DB_PASS=your_secure_password
GF_SECURITY_ADMIN_USER=admin
GF_SECURITY_ADMIN_PASSWORD=your_secure_password
```

> **Note:** The default `docker-compose.yml` uses hardcoded values for simplicity. For any non-local deployment, switch to `.env` references.

---

## 📄 License

MIT
