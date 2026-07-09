-- ============================================================
-- SHARD / REPLICA INIT
-- Shared schema for shard1-5 and replica1-5
-- ============================================================

CREATE TABLE IF NOT EXISTS data_items (
    id            SERIAL PRIMARY KEY,
    item_code     VARCHAR(50)  NOT NULL UNIQUE,
    payload       TEXT         NOT NULL,
    current_shard INT          NOT NULL,
    created_at    TIMESTAMP    DEFAULT NOW(),
    updated_at    TIMESTAMP    DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_data_items_shard ON data_items(current_shard);
CREATE INDEX IF NOT EXISTS idx_data_items_code  ON data_items(item_code);
