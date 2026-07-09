-- ============================================================
-- MASTER / COORDINATOR INIT
-- ============================================================

-- 1. master_data: holds ALL rows (2000 initial + inserted)
CREATE TABLE IF NOT EXISTS master_data (
    id            SERIAL PRIMARY KEY,
    item_code     VARCHAR(50)  NOT NULL UNIQUE,
    payload       TEXT         NOT NULL,
    target_shard  INT          NOT NULL,
    current_shard INT,
    status        VARCHAR(20)  DEFAULT 'distributed',
    created_at    TIMESTAMP    DEFAULT NOW(),
    updated_at    TIMESTAMP    DEFAULT NOW()
);

-- 2. event_queue: event-driven log
CREATE TABLE IF NOT EXISTS event_queue (
    event_id     SERIAL PRIMARY KEY,
    event_type   VARCHAR(50)  NOT NULL,
    payload      TEXT,
    target_shard INT,
    status       VARCHAR(20)  DEFAULT 'pending',
    retry_count  INT          DEFAULT 0,
    created_at   TIMESTAMP    DEFAULT NOW(),
    processed_at TIMESTAMP
);

-- 3. shard_status: tracks online/offline per shard
CREATE TABLE IF NOT EXISTS shard_status (
    shard_id       INT PRIMARY KEY,
    shard_name     VARCHAR(20)  NOT NULL,
    status         VARCHAR(10)  DEFAULT 'online',
    last_checked_at TIMESTAMP   DEFAULT NOW()
);

INSERT INTO shard_status (shard_id, shard_name, status) VALUES
    (1, 'shard1', 'online'),
    (2, 'shard2', 'online'),
    (3, 'shard3', 'online'),
    (4, 'shard4', 'online'),
    (5, 'shard5', 'online')
ON CONFLICT (shard_id) DO NOTHING;

-- 4. sync_log
CREATE TABLE IF NOT EXISTS sync_log (
    log_id       SERIAL PRIMARY KEY,
    event_type   VARCHAR(50)  NOT NULL,
    target_shard INT,
    record_id    INT,
    message      TEXT,
    created_at   TIMESTAMP    DEFAULT NOW()
);

-- 5. rebalance_log
CREATE TABLE IF NOT EXISTS rebalance_log (
    log_id       SERIAL PRIMARY KEY,
    action       TEXT         NOT NULL,
    from_shard   INT,
    to_shard     INT,
    rows_moved   INT          DEFAULT 0,
    created_at   TIMESTAMP    DEFAULT NOW()
);

-- ── Seed 2000 initial rows ────────────────────────────────────────────────────
-- Distributed evenly: shard = ((id-1) % 5) + 1  →  400 per shard
INSERT INTO master_data (item_code, payload, target_shard, current_shard, status)
SELECT
    'ITEM-' || LPAD(gs::text, 4, '0'),
    'Initial dummy data item ' || gs,
    ((gs - 1) % 5) + 1,
    ((gs - 1) % 5) + 1,
    'distributed'
FROM generate_series(1, 2000) AS gs
ON CONFLICT (item_code) DO NOTHING;

-- Seed event
INSERT INTO event_queue (event_type, payload, status)
VALUES ('INIT', 'System initialized with 2000 seed rows', 'done');

INSERT INTO sync_log (event_type, message)
VALUES ('INIT', 'Master initialized: 2000 rows seeded across 5 shards');
