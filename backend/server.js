/**
 * Distributed DB Demo — Backend (v2)
 * Architecture: 2 masters × 3 shards each (6 shards total, no replicas)
 *   master1 → shard1, shard2, shard3
 *   master2 → shard4, shard5, shard6
 * Dashboard: http://localhost:3000
 */

'use strict';

const express    = require('express');
const cors       = require('cors');
const { Pool }   = require('pg');
const path       = require('path');
const http       = require('http');
const promClient = require('prom-client');
const winston    = require('winston');
const LokiTransport = require('winston-loki');

// ── Logger (Winston + Loki) ───────────────────────────────────────────────────────
const LOKI_HOST = process.env.LOKI_HOST || 'loki';

const transports = [
  new winston.transports.Console({
    format: winston.format.combine(
      winston.format.colorize(),
      winston.format.timestamp({ format: 'HH:mm:ss' }),
      winston.format.printf(({ timestamp, level, message, ...meta }) => {
        const extra = Object.keys(meta).length ? ' ' + JSON.stringify(meta) : '';
        return `[${timestamp}] ${level}: ${message}${extra}`;
      })
    ),
  }),
];

// Add Loki transport (non-blocking — errors are suppressed so the app starts
// even if Loki isn’t up yet)
try {
  transports.push(
    new LokiTransport({
      host: `http://${LOKI_HOST}:3100`,
      labels: { app: 'backend', project: 'distributed-db' },
      // Protobuf mode — json:true sends winston metadata as structured metadata,
      // which Loki 2.9 (boltdb-shipper) rejects and silently discards.
      json: false,
      batching: false,          // push each log immediately, no buffering
      onConnectionError: (err) =>
        console.error('[Loki] connection error:', err.message),
    })
  );
  console.log(`[Loki] transport registered → http://${LOKI_HOST}:3100`);
} catch (e) {
  console.warn('[Loki] transport init failed:', e.message);
}

const logger = winston.createLogger({
  level: 'info',
  defaultMeta: { service: 'backend' },
  transports,
});

// Safety net: prevent silent crashes from winston-loki or any other uncaught error
process.on('uncaughtException', (err) => {
  console.error('[uncaughtException]', err.message, err.stack);
  // Don't exit — let Docker restart policy handle truly fatal cases
});
process.on('unhandledRejection', (reason) => {
  console.error('[unhandledRejection]', reason);
});


const app = express();
app.use(cors());
app.use(express.json());

// ── Prometheus Metrics ─────────────────────────────────────────────────────────
const register = new promClient.Registry();
promClient.collectDefaultMetrics({ register });

const httpRequestDuration = new promClient.Histogram({
  name: 'http_request_duration_seconds',
  help: 'Duration of HTTP requests in seconds',
  labelNames: ['method', 'route', 'status_code'],
  registers: [register],
});

const httpRequestTotal = new promClient.Counter({
  name: 'http_requests_total',
  help: 'Total number of HTTP requests',
  labelNames: ['method', 'route', 'status_code'],
  registers: [register],
});

const shardDataRowsTotal = new promClient.Gauge({
  name: 'shard_data_rows_total',
  help: 'Total rows (barang) in each shard',
  labelNames: ['shard'],
  registers: [register],
});

const shardOnline = new promClient.Gauge({
  name: 'shard_online',
  help: 'Shard online status (1=online, 0=offline)',
  labelNames: ['shard'],
  registers: [register],
});

// Pre-seed all shard labels so they appear in /metrics from first scrape
for (let _i = 1; _i <= 6; _i++) {
  shardOnline.labels(`shard${_i}`).set(0);
  shardDataRowsTotal.labels(`shard${_i}`).set(0);
}

// Middleware: request metrics
app.use((req, res, next) => {
  const start = Date.now();
  res.on('finish', () => {
    const duration = (Date.now() - start) / 1000;
    const route    = req.route?.path || req.path;
    httpRequestDuration.labels(req.method, route, res.statusCode).observe(duration);
    httpRequestTotal.labels(req.method, route, res.statusCode).inc();
  });
  next();
});

// Metrics endpoint for Prometheus
app.get('/metrics', async (req, res) => {
  res.set('Content-Type', register.contentType);
  res.end(await register.metrics());
});

// ── Auto-seed & poll metrics so Prometheus always has data ───────────────────
// Track previous shard state so we only log on transitions
const _shardWasOnline = {};

async function refreshShardMetrics() {
  for (const shardNum of ALL_SHARDS) {
    const name = `shard${shardNum}`;
    try {
      const rows = await qry(name, 'SELECT COUNT(*) AS cnt FROM barang');
      const count = parseInt(rows[0].cnt) || 0;
      shardOnline.labels(name).set(1);
      shardDataRowsTotal.labels(name).set(count);

      // Log transition: offline → online
      if (_shardWasOnline[shardNum] === false) {
        logger.info(`${name} is back online`, { shard: shardNum, rows: count, event: 'shard_recovered' });
      }
      _shardWasOnline[shardNum] = true;
    } catch (e) {
      shardOnline.labels(name).set(0);
      shardDataRowsTotal.labels(name).set(0);

      // Log transition: online → offline
      if (_shardWasOnline[shardNum] !== false) {
        logger.warn(`${name} is offline`, { shard: shardNum, error: e.message, event: 'shard_offline' });
      }
      _shardWasOnline[shardNum] = false;
    }
  }
}

function startMetricsPoller(intervalMs = 15000) {
  // Run immediately, then repeat
  refreshShardMetrics();
  setInterval(refreshShardMetrics, intervalMs);
  // Heartbeat every 60s so Loki always has recent log volume
  setInterval(() => logger.info('Heartbeat', { uptime: Math.floor(process.uptime()) }), 60_000);
  logger.info(`Metrics poller started (every ${intervalMs / 1000}s)`);
}

// Static files
app.use(express.static(path.join(__dirname, 'public')));

// ── Connection Pools ──────────────────────────────────────────────────────────
const PG_USER = process.env.DB_USER || 'postgres';
const PG_PASS = process.env.DB_PASS || 'postgres';
const TIMEOUT  = 3000;

function makePool(host, database) {
  return new Pool({
    host, database,
    user: PG_USER, password: PG_PASS,
    port: 5432,
    connectionTimeoutMillis: TIMEOUT,
    idleTimeoutMillis: 10000,
    max: 5,
  });
}

const pools = {
  master1: makePool(process.env.MASTER1_HOST || 'master1', 'master_db'),
  master2: makePool(process.env.MASTER2_HOST || 'master2', 'master_db'),
  shard1:  makePool(process.env.SHARD1_HOST  || 'shard1',  'shard_db'),
  shard2:  makePool(process.env.SHARD2_HOST  || 'shard2',  'shard_db'),
  shard3:  makePool(process.env.SHARD3_HOST  || 'shard3',  'shard_db'),
  shard4:  makePool(process.env.SHARD4_HOST  || 'shard4',  'shard_db'),
  shard5:  makePool(process.env.SHARD5_HOST  || 'shard5',  'shard_db'),
  shard6:  makePool(process.env.SHARD6_HOST  || 'shard6',  'shard_db'),
};

// ── Low-level helpers ─────────────────────────────────────────────────────────
async function qry(node, sql, params = []) {
  const client = await pools[node].connect();
  try { return (await client.query(sql, params)).rows; }
  finally { client.release(); }
}

async function exec(node, sql, params = []) {
  const client = await pools[node].connect();
  try { await client.query(sql, params); }
  finally { client.release(); }
}

async function canConnect(node) {
  try {
    const client = await pools[node].connect();
    client.release();
    return true;
  } catch { return false; }
}

function sleep(ms) { return new Promise(r => setTimeout(r, ms)); }

// ── DB init: create log tables on master1 ────────────────────────────────────
async function initLogTables() {
  const MAX_RETRIES = 12;
  for (let attempt = 1; attempt <= MAX_RETRIES; attempt++) {
    try {
      await exec('master1', `
        CREATE TABLE IF NOT EXISTS event_log (
          event_id     SERIAL PRIMARY KEY,
          event_type   VARCHAR(50) NOT NULL,
          payload      TEXT,
          target_shard INT,
          status       VARCHAR(20) DEFAULT 'done',
          created_at   TIMESTAMP DEFAULT NOW()
        );
        CREATE TABLE IF NOT EXISTS sync_log (
          log_id       SERIAL PRIMARY KEY,
          event_type   VARCHAR(50) NOT NULL,
          target_shard INT,
          message      TEXT,
          created_at   TIMESTAMP DEFAULT NOW()
        );
        CREATE TABLE IF NOT EXISTS rebalance_log (
          log_id       SERIAL PRIMARY KEY,
          action       TEXT NOT NULL,
          from_shard   INT,
          to_shard     INT,
          rows_moved   INT DEFAULT 0,
          created_at   TIMESTAMP DEFAULT NOW()
        );
      `);
      logger.info('Log tables ready on master1.');
      return;
    } catch (e) {
      logger.warn(`initLogTables attempt ${attempt}/${MAX_RETRIES}`, { error: e.message });
      if (attempt < MAX_RETRIES) await sleep(2000);
    }
  }
  logger.error('initLogTables: gave up after max retries.');
}

// ── Architecture helpers ──────────────────────────────────────────────────────
// master1 owns shards 1–3, master2 owns shards 4–6
function masterForShard(shardNum) {
  return shardNum <= 3 ? 'master1' : 'master2';
}

// Shards 4-6 are numbered 1-3 inside master2's shard_status table
function localShardId(shardNum) {
  return shardNum <= 3 ? shardNum : shardNum - 3;
}

const MASTER1_SHARDS = [1, 2, 3];
const MASTER2_SHARDS = [4, 5, 6];
const ALL_SHARDS     = [1, 2, 3, 4, 5, 6];

// ── Docker control helpers ────────────────────────────────────────────────────
const DOCKER_SOCKET = process.env.DOCKER_SOCKET || '/var/run/docker.sock';

function dockerRequest(method, dockerPath) {
  return new Promise((resolve, reject) => {
    const req = http.request({
      socketPath: DOCKER_SOCKET,
      method,
      path: dockerPath,
    }, (res) => {
      let body = '';
      res.on('data', chunk => body += chunk);
      res.on('end', () => {
        if ([200, 201, 204, 304].includes(res.statusCode)) {
          resolve({ ok: true, statusCode: res.statusCode, body });
        } else {
          reject(new Error(`Docker API ${res.statusCode}: ${body || 'No body'}`));
        }
      });
    });
    req.on('error', err =>
      reject(new Error(`Cannot reach Docker socket at ${DOCKER_SOCKET}: ${err.message}`)));
    req.end();
  });
}

async function stopDockerContainer(name) {
  return dockerRequest('POST', `/containers/${encodeURIComponent(name)}/stop?t=2`);
}

async function startDockerContainer(name) {
  return dockerRequest('POST', `/containers/${encodeURIComponent(name)}/start`);
}

// ── Shard status helpers ──────────────────────────────────────────────────────
async function setShardStatus(shardNum, status) {
  const master  = masterForShard(shardNum);
  const localId = localShardId(shardNum);
  try {
    await exec(master, 'UPDATE shard_status SET status=$1 WHERE shard_id=$2', [status, localId]);
  } catch {}
}

async function isShardReadable(shardNum) {
  try {
    const rows = await qry(`shard${shardNum}`, 'SELECT COUNT(*) AS cnt FROM barang');
    return { readable: true, count: parseInt(rows[0].cnt) };
  } catch (e) {
    return { readable: false, count: null, error: e.message };
  }
}

async function getShardCount(shardNum) {
  try {
    const rows = await qry(`shard${shardNum}`, 'SELECT COUNT(*) AS cnt FROM barang');
    const cnt = parseInt(rows[0].cnt);
    shardDataRowsTotal.labels(`shard${shardNum}`).set(cnt);
    return cnt;
  } catch { return null; }
}

// Returns array of online shard numbers.
// masterNum=1 → only check shards 1-3; masterNum=2 → only 4-6; null → all
async function getOnlineShards(masterNum = null) {
  const shards = masterNum === 1 ? MASTER1_SHARDS
               : masterNum === 2 ? MASTER2_SHARDS
               : ALL_SHARDS;
  const online = [];
  for (const sn of shards) {
    const state = await isShardReadable(sn);
    if (state.readable) {
      online.push(sn);
      shardOnline.labels(`shard${sn}`).set(1);
      await setShardStatus(sn, 'online');
    } else {
      shardOnline.labels(`shard${sn}`).set(0);
      await setShardStatus(sn, 'offline');
    }
  }
  return online;
}

async function leastLoadedShard(onlineShards) {
  const counts = await Promise.all(onlineShards.map(async (n) => ({
    shard: n,
    count: (await getShardCount(n)) ?? Infinity,
  })));
  counts.sort((a, b) => a.count - b.count);
  return counts[0]?.shard ?? null;
}

// ── Routes ────────────────────────────────────────────────────────────────────

// GET /api/health
app.get('/api/health', (req, res) => {
  res.json({ success: true, message: 'Backend is running', timestamp: new Date() });
});

// GET /api/status — overview of all nodes
app.get('/api/status', async (req, res) => {
  try {
    // Master row counts
    const masterCounts = {};
    for (const m of ['master1', 'master2']) {
      try {
        const r = await qry(m, 'SELECT COUNT(*) AS cnt FROM barang');
        masterCounts[m] = parseInt(r[0].cnt);
      } catch { masterCounts[m] = null; }
    }

    // Shard states
    const shardStatuses = {};
    const counts        = {};
    const connectivity  = {
      master1: await canConnect('master1'),
      master2: await canConnect('master2'),
    };

    for (let i = 1; i <= 6; i++) {
      const state = await isShardReadable(i);
      connectivity[`shard${i}`]  = state.readable;
      shardStatuses[`shard${i}`] = state.readable ? 'online' : 'offline';
      counts[`shard${i}`]        = state.readable ? state.count : null;
      shardOnline.labels(`shard${i}`).set(state.readable ? 1 : 0);
      await setShardStatus(i, state.readable ? 'online' : 'offline');
    }

    res.json({
      success: true,
      masters: masterCounts,
      shards: shardStatuses,
      counts,
      connectivity,
    });
  } catch (e) {
    res.json({ success: false, message: e.message });
  }
});

// GET /api/data — sample rows from every node
app.get('/api/data', async (req, res) => {
  try {
    const masterRows = {};
    for (const m of ['master1', 'master2']) {
      try {
        masterRows[m] = await qry(m,
          'SELECT id_barang, nama_barang, stok, target_shard FROM barang ORDER BY id_barang ASC LIMIT 5000');
      } catch { masterRows[m] = null; }
    }

    const shardSamples = {};
    for (let i = 1; i <= 6; i++) {
      try {
        shardSamples[`shard${i}`] = await qry(`shard${i}`,
          'SELECT id_barang, nama_barang, stok FROM barang ORDER BY id_barang ASC LIMIT 5000');
      } catch { shardSamples[`shard${i}`] = null; }
    }

    res.json({ success: true, masterRows, shardSamples });
  } catch (e) {
    res.json({ success: false, message: e.message });
  }
});

// POST /api/add-data — insert new barang
// Body: { count: N, master: 1|2 }  (master defaults to 1)
app.post('/api/add-data', async (req, res) => {
  const count     = parseInt(req.body.count || req.body.number_of_data || 0);
  const masterNum = parseInt(req.body.master || 1);

  if (!count || count < 1 || count > 5000) {
    return res.json({ success: false, message: 'count must be 1–5000' });
  }
  if (masterNum !== 1 && masterNum !== 2) {
    return res.json({ success: false, message: 'master must be 1 or 2' });
  }

  const masterNode   = `master${masterNum}`;
  const readableShards = await getOnlineShards(masterNum);

  if (readableShards.length === 0) {
    return res.json({
      success: false,
      message: `No readable shards online for master${masterNum}.`,
      online_shards: [],
    });
  }

  try {
    const maxRow = await qry(masterNode, 'SELECT MAX(id_barang) AS mx FROM barang');
    let nextId   = (parseInt(maxRow[0].mx) || 0) + 1;

    const distributed = {};
    let inserted = 0;

    for (let i = 0; i < count; i++) {
      const id   = nextId + i;
      const nama = `Barang Baru ${id}`;
      const stok = Math.floor(Math.random() * 491) + 10;

      const shardNum = await leastLoadedShard(readableShards);
      if (!shardNum) continue;

      const localId = localShardId(shardNum);

      try {
        await exec(masterNode,
          'INSERT INTO barang (id_barang, nama_barang, stok, target_shard) VALUES ($1,$2,$3,$4) ON CONFLICT DO NOTHING',
          [id, nama, stok, localId]);

        await exec(`shard${shardNum}`,
          'INSERT INTO barang (id_barang, nama_barang, stok) VALUES ($1,$2,$3) ON CONFLICT DO NOTHING',
          [id, nama, stok]);

        distributed[`shard${shardNum}`] = (distributed[`shard${shardNum}`] || 0) + 1;
        inserted++;
      } catch (e) {
        logger.error(`Insert failed for id ${id}`, { error: e.message, master: masterNum });
      }
    }

    // Log event (best-effort — don't block the response)
    try {
      await exec('master1',
        `INSERT INTO event_log (event_type, payload, target_shard, status)
         VALUES ($1, $2, $3, 'done')`,
        ['INSERT', `Added ${inserted} item(s) to master${masterNum}`, masterNum]);
      await exec('master1',
        `INSERT INTO sync_log (event_type, target_shard, message)
         VALUES ($1, $2, $3)`,
        ['INSERT', masterNum,
          `${inserted} item(s) added to master${masterNum}. Distribution: ${JSON.stringify(distributed)}`]);
    } catch { /* ignore logging errors */ }

    res.json({
      success: true,
      message: `${inserted} item(s) added to master${masterNum} and distributed.`,
      inserted,
      distributed,
      online_shards: readableShards,
    });
  } catch (e) {
    res.json({ success: false, message: e.message });
  }
});

// POST /api/insert-item — manually insert a single item with custom fields
// Body: { id_barang?: number, nama_barang?: string, stok?: number, master?: 1|2 }
app.post('/api/insert-item', async (req, res) => {
  const masterNum = parseInt(req.body.master || 1);
  if (masterNum !== 1 && masterNum !== 2) {
    return res.json({ success: false, message: 'master must be 1 or 2' });
  }

  const masterNode = `master${masterNum}`;

  // Resolve id — use provided or auto-increment
  let id = parseInt(req.body.id_barang);
  if (!id || isNaN(id) || id < 1) {
    try {
      const maxRow = await qry(masterNode, 'SELECT MAX(id_barang) AS mx FROM barang');
      id = (parseInt(maxRow[0].mx) || 0) + 1;
    } catch (e) {
      return res.json({ success: false, message: `Cannot read master${masterNum}: ${e.message}` });
    }
  }

  const nama = (req.body.nama_barang || '').trim() || `Barang ${id}`;
  const stok = parseInt(req.body.stok);
  const finalStok = (!isNaN(stok) && stok >= 0) ? stok : Math.floor(Math.random() * 491) + 10;

  const onlineShards = await getOnlineShards(masterNum);
  if (onlineShards.length === 0) {
    return res.json({ success: false, message: `No online shards for master${masterNum}` });
  }

  const shardNum = await leastLoadedShard(onlineShards);
  const localId  = localShardId(shardNum);

  try {
    // Check for duplicate id on master
    const existing = await qry(masterNode, 'SELECT id_barang FROM barang WHERE id_barang=$1', [id]);
    if (existing.length > 0) {
      return res.json({ success: false, message: `id_barang ${id} already exists on master${masterNum}` });
    }

    await exec(masterNode,
      'INSERT INTO barang (id_barang, nama_barang, stok, target_shard) VALUES ($1,$2,$3,$4)',
      [id, nama, finalStok, localId]);

    await exec(`shard${shardNum}`,
      'INSERT INTO barang (id_barang, nama_barang, stok) VALUES ($1,$2,$3) ON CONFLICT DO NOTHING',
      [id, nama, finalStok]);

    // Log event (best-effort)
    try {
      await exec('master1',
        `INSERT INTO event_log (event_type, payload, target_shard, status) VALUES ($1,$2,$3,'done')`,
        ['MANUAL_INSERT', `Inserted id=${id} name="${nama}" stok=${finalStok} → shard${shardNum}`, masterNum]);
      await exec('master1',
        `INSERT INTO sync_log (event_type, target_shard, message) VALUES ($1,$2,$3)`,
        ['MANUAL_INSERT', masterNum, `id=${id}, name="${nama}", stok=${finalStok} → master${masterNum}/shard${shardNum}`]);
    } catch { /* ignore logging errors */ }

    logger.info('Manual insert', { id, nama, stok: finalStok, master: masterNum, shard: shardNum });

    res.json({
      success: true,
      message: `Item inserted → master${masterNum} / shard${shardNum}`,
      item: { id_barang: id, nama_barang: nama, stok: finalStok, target_shard: localId, shard: `shard${shardNum}` },
    });
  } catch (e) {
    logger.error('Manual insert failed', { error: e.message, id, master: masterNum });
    res.json({ success: false, message: e.message });
  }
});

// POST /api/kill-shard/:id  (id: 1–6)
app.post('/api/kill-shard/:id', async (req, res) => {
  const id = parseInt(req.params.id);
  if (id < 1 || id > 6) {
    return res.json({ success: false, message: 'Shard id must be 1–6' });
  }
  try {
    await stopDockerContainer(`shard${id}`);
    await setShardStatus(id, 'offline');
    shardOnline.labels(`shard${id}`).set(0);
    logger.info(`shard${id} stopped`, { action: 'kill', shard: id });
    res.json({ success: true, message: `shard${id} stopped and marked offline.` });
  } catch (e) {
    logger.error(`Failed to stop shard${id}`, { error: e.message });
    res.json({ success: false, message: `Failed to stop shard${id}: ${e.message}` });
  }
});

// POST /api/recover-shard/:id  (id: 1–6)
app.post('/api/recover-shard/:id', async (req, res) => {
  const id = parseInt(req.params.id);
  if (id < 1 || id > 6) {
    return res.json({ success: false, message: 'Shard id must be 1–6' });
  }
  try {
    await startDockerContainer(`shard${id}`);

    let state = { readable: false };
    for (let attempt = 0; attempt < 25; attempt++) {
      state = await isShardReadable(id);
      if (state.readable) break;
      await sleep(1000);
    }

    if (!state.readable) {
      await setShardStatus(id, 'offline');
      shardOnline.labels(`shard${id}`).set(0);
      return res.json({
        success: false,
        message: `shard${id} container started but not readable yet. Stays offline.`,
      });
    }

    await setShardStatus(id, 'online');
    shardOnline.labels(`shard${id}`).set(1);
    logger.info(`shard${id} recovered`, { action: 'recover', shard: id });
    res.json({ success: true, message: `shard${id} recovered and readable.` });
  } catch (e) {
    await setShardStatus(id, 'offline');
    shardOnline.labels(`shard${id}`).set(0);
    res.json({ success: false, message: `Failed to start shard${id}: ${e.message}` });
  }
});

// POST /api/kill-all-shards
app.post('/api/kill-all-shards', async (req, res) => {
  const stopped = [], failed = [];
  for (let i = 1; i <= 6; i++) {
    try {
      await stopDockerContainer(`shard${i}`);
      await setShardStatus(i, 'offline');
      shardOnline.labels(`shard${i}`).set(0);
      stopped.push(`shard${i}`);
    } catch (e) {
      failed.push({ shard: `shard${i}`, error: e.message });
    }
  }
  res.json({
    success: failed.length === 0,
    message: `Stopped: [${stopped.join(', ')}]` + (failed.length ? `, failed: ${failed.map(f => f.shard).join(', ')}` : ''),
    stopped,
    failed,
  });
});

// POST /api/recover-all-shards
app.post('/api/recover-all-shards', async (req, res) => {
  const recovered = [], failed = [];
  for (let i = 1; i <= 6; i++) {
    try {
      await startDockerContainer(`shard${i}`);
      let state = { readable: false };
      for (let attempt = 0; attempt < 25; attempt++) {
        state = await isShardReadable(i);
        if (state.readable) break;
        await sleep(1000);
      }
      if (!state.readable) throw new Error('container started but not readable');
      await setShardStatus(i, 'online');
      shardOnline.labels(`shard${i}`).set(1);
      recovered.push(`shard${i}`);
    } catch (e) {
      await setShardStatus(i, 'offline');
      shardOnline.labels(`shard${i}`).set(0);
      failed.push({ shard: `shard${i}`, error: e.message });
    }
  }
  res.json({
    success: failed.length === 0,
    message: `Recovered: [${recovered.join(', ')}]` + (failed.length ? `, failed: ${failed.map(f => f.shard).join(', ')}` : ''),
    recovered,
    failed,
  });
});

// GET /api/events — return event_log, sync_log, rebalance_log from master1
app.get('/api/events', async (req, res) => {
  try {
    const [events, syncLog, rebalLog] = await Promise.all([
      qry('master1', 'SELECT * FROM event_log   ORDER BY event_id DESC LIMIT 30'),
      qry('master1', 'SELECT * FROM sync_log    ORDER BY log_id   DESC LIMIT 30'),
      qry('master1', 'SELECT * FROM rebalance_log ORDER BY log_id DESC LIMIT 30'),
    ]);
    res.json({ success: true, events, syncLog, rebalLog });
  } catch (e) {
    // Tables may not exist yet — return empty arrays gracefully
    res.json({ success: true, events: [], syncLog: [], rebalLog: [], note: e.message });
  }
});

// POST /api/sync — verify every master item exists in its target shard, re-insert missing
app.post('/api/sync', async (req, res) => {
  const results  = [];
  let   totalFixed = 0;

  // master1 → shards 1, 2, 3  (target_shard 1/2/3 maps directly to shard1/2/3)
  try {
    const items = await qry('master1',
      'SELECT id_barang, nama_barang, stok, target_shard FROM barang');
    for (const item of items) {
      const shardNum = Math.max(1, Math.min(3, item.target_shard)); // clamp 1-3
      try {
        await exec(`shard${shardNum}`,
          'INSERT INTO barang (id_barang, nama_barang, stok) VALUES ($1,$2,$3) ON CONFLICT DO NOTHING',
          [item.id_barang, item.nama_barang, item.stok]);
        totalFixed++;
      } catch { /* shard offline */ }
    }
    results.push(`master1: verified ${items.length} items across shard1-3`);
  } catch (e) {
    results.push(`master1 error: ${e.message}`);
  }

  // master2 → shards 4, 5, 6  (target_shard 1→shard4, 2→shard5, 3→shard6)
  try {
    const items = await qry('master2',
      'SELECT id_barang, nama_barang, stok, target_shard FROM barang');
    for (const item of items) {
      const localId  = Math.max(1, Math.min(3, item.target_shard));
      const shardNum = localId + 3; // 1→4, 2→5, 3→6
      try {
        await exec(`shard${shardNum}`,
          'INSERT INTO barang (id_barang, nama_barang, stok) VALUES ($1,$2,$3) ON CONFLICT DO NOTHING',
          [item.id_barang, item.nama_barang, item.stok]);
        totalFixed++;
      } catch { /* shard offline */ }
    }
    results.push(`master2: verified ${items.length} items across shard4-6`);
  } catch (e) {
    results.push(`master2 error: ${e.message}`);
  }

  const message = results.join(' | ');

  // Write to sync_log (best-effort)
  try {
    await exec('master1',
      `INSERT INTO sync_log (event_type, message) VALUES ('SYNC', $1)`, [message]);
  } catch {}

  res.json({ success: true, message, totalFixed });
});

// POST /api/rebalance — move rows from the most-loaded to the least-loaded shard
//   within each master's domain, then update master target_shard accordingly
app.post('/api/rebalance', async (req, res) => {
  const summary    = [];
  let   totalMoved = 0;

  const domains = [
    { masterNode: 'master1', shardNums: [1, 2, 3] },
    { masterNode: 'master2', shardNums: [4, 5, 6] },
  ];

  for (const { masterNode, shardNums } of domains) {
    try {
      // Gather counts for this domain's shards
      const counts = {};
      for (const sn of shardNums) {
        counts[sn] = (await getShardCount(sn)) ?? 0;
      }

      const sorted  = Object.entries(counts).sort((a, b) => b[1] - a[1]);
      const maxEntry = sorted[0];   // [shardNum, count]
      const minEntry = sorted[sorted.length - 1];
      const maxShard = parseInt(maxEntry[0]);
      const minShard = parseInt(minEntry[0]);
      const diff     = maxEntry[1] - minEntry[1];

      if (diff <= 10) {
        summary.push(`${masterNode}: balanced (diff=${diff})`);
        continue;
      }

      const toMove = Math.floor(diff / 2);
      const rows   = await qry(`shard${maxShard}`,
        'SELECT id_barang, nama_barang, stok FROM barang ORDER BY id_barang DESC LIMIT $1',
        [toMove]);

      let moved = 0;
      for (const row of rows) {
        try {
          // Insert into the less-loaded shard
          await exec(`shard${minShard}`,
            'INSERT INTO barang (id_barang, nama_barang, stok) VALUES ($1,$2,$3) ON CONFLICT DO NOTHING',
            [row.id_barang, row.nama_barang, row.stok]);

          // Remove from overloaded shard
          await exec(`shard${maxShard}`,
            'DELETE FROM barang WHERE id_barang=$1', [row.id_barang]);

          // Update master's target_shard (use local shard id)
          const newLocalId = localShardId(minShard);
          await exec(masterNode,
            'UPDATE barang SET target_shard=$1 WHERE id_barang=$2',
            [newLocalId, row.id_barang]);

          moved++;
        } catch { /* skip row on error */ }
      }

      // Log rebalance operation
      try {
        await exec('master1',
          `INSERT INTO rebalance_log (action, from_shard, to_shard, rows_moved)
           VALUES ($1,$2,$3,$4)`,
          [`Rebalance ${masterNode}`, maxShard, minShard, moved]);
      } catch {}

      totalMoved += moved;
      summary.push(
        `${masterNode}: moved ${moved} rows from shard${maxShard}(${maxEntry[1]}) → shard${minShard}(${minEntry[1]})`);
    } catch (e) {
      summary.push(`${masterNode} error: ${e.message}`);
    }
  }

  // Final counts after rebalance
  const finalCounts = {};
  for (let i = 1; i <= 6; i++) {
    finalCounts[`shard${i}`] = await getShardCount(i);
  }

  res.json({
    success: true,
    message: summary.join(' | '),
    totalMoved,
    final_counts: finalCounts,
  });
});

// GET /api/lookup-item/:id — quick lookup across both masters (used by delete preview)
app.get('/api/lookup-item/:id', async (req, res) => {
  const id = parseInt(req.params.id);
  if (!id || isNaN(id)) return res.json({ success: false });
  for (const m of ['master1', 'master2']) {
    try {
      const rows = await qry(m, 'SELECT id_barang, nama_barang, stok, target_shard FROM barang WHERE id_barang=$1', [id]);
      if (rows.length > 0) return res.json({ success: true, item: rows[0], master: m });
    } catch { /* skip offline master */ }
  }
  res.json({ success: false, message: 'Not found' });
});

// DELETE /api/delete-item/:id
// Removes the item from the owning master + all its shards (searches all masters)
app.delete('/api/delete-item/:id', async (req, res) => {
  const id = parseInt(req.params.id);
  if (!id || isNaN(id) || id < 1) {
    return res.json({ success: false, message: 'Invalid id_barang' });
  }

  let foundOnMaster = null;
  let itemInfo      = null;

  // Find which master owns this id
  for (const m of ['master1', 'master2']) {
    try {
      const rows = await qry(m, 'SELECT id_barang, nama_barang, stok, target_shard FROM barang WHERE id_barang=$1', [id]);
      if (rows.length > 0) {
        foundOnMaster = m;
        itemInfo      = rows[0];
        break;
      }
    } catch { /* master offline — skip */ }
  }

  if (!foundOnMaster) {
    logger.warn('Delete attempted but item not found', { id, event: 'delete_not_found' });
    return res.json({ success: false, message: `id_barang ${id} not found on any master` });
  }

  const masterNum  = foundOnMaster === 'master1' ? 1 : 2;
  const shardNums  = masterNum === 1 ? MASTER1_SHARDS : MASTER2_SHARDS;
  const deletedFrom = [];
  const errors      = [];

  // Delete from master
  try {
    await exec(foundOnMaster, 'DELETE FROM barang WHERE id_barang=$1', [id]);
    deletedFrom.push(foundOnMaster);
  } catch (e) {
    errors.push(`${foundOnMaster}: ${e.message}`);
  }

  // Delete from all shards in this master's domain
  for (const sn of shardNums) {
    try {
      const r = await qry(`shard${sn}`, 'DELETE FROM barang WHERE id_barang=$1 RETURNING id_barang', [id]);
      if (r.length > 0) deletedFrom.push(`shard${sn}`);
    } catch (e) {
      errors.push(`shard${sn}: ${e.message}`);
    }
  }

  const msg = `Deleted id=${id} ("${itemInfo.nama_barang}") from [${deletedFrom.join(', ')}]` +
              (errors.length ? ` | errors: ${errors.join('; ')}` : '');

  // Log to event_log + sync_log (best-effort)
  try {
    await exec('master1',
      `INSERT INTO event_log (event_type, payload, target_shard, status) VALUES ($1,$2,$3,'done')`,
      ['DELETE', msg, masterNum]);
    await exec('master1',
      `INSERT INTO sync_log (event_type, target_shard, message) VALUES ($1,$2,$3)`,
      ['DELETE', masterNum, msg]);
  } catch { /* ignore if master1 is down */ }

  logger.info('Item deleted', {
    id,
    nama: itemInfo.nama_barang,
    stok: itemInfo.stok,
    master: foundOnMaster,
    deletedFrom,
    event: 'item_deleted',
  });

  res.json({
    success: errors.length === 0,
    message: msg,
    deleted_from: deletedFrom,
    errors,
    item: itemInfo,
  });
});

// Fallback — serve SPA
app.get('*', (req, res) => {
  res.sendFile(path.join(__dirname, 'public', 'index.html'));
});

const PORT = parseInt(process.env.PORT || 3000);
app.listen(PORT, () => {
  logger.info(`Distributed DB backend running`, { port: PORT, lokiHost: LOKI_HOST });
  logger.info('Architecture: master1→[shard1,shard2,shard3]  master2→[shard4,shard5,shard6]');
  // Give DBs 5s to be ready, then seed metrics immediately and poll every 15s
  setTimeout(() => {
    startMetricsPoller(15000);
    initLogTables();
  }, 5000);
});

