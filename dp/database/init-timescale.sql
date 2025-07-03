-- TimescaleDB Initialization for QiCore Crypto Data Platform
-- This script sets up the time-series tables for real-time crypto data

-- Enable TimescaleDB extension
CREATE EXTENSION IF NOT EXISTS timescaledb CASCADE;

-- Create schemas
CREATE SCHEMA IF NOT EXISTS market_data;
CREATE SCHEMA IF NOT EXISTS agent_data;
CREATE SCHEMA IF NOT EXISTS analysis;

-- OHLCV Data Table (main market data)
CREATE TABLE market_data.ohlcv (
    time TIMESTAMPTZ NOT NULL,
    symbol VARCHAR(20) NOT NULL,
    exchange VARCHAR(50),
    open DECIMAL(20,8) NOT NULL,
    high DECIMAL(20,8) NOT NULL,
    low DECIMAL(20,8) NOT NULL,
    close DECIMAL(20,8) NOT NULL,
    volume DECIMAL(20,8) NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Convert to hypertable (time-series optimization)
SELECT create_hypertable('market_data.ohlcv', 'time', chunk_time_interval => INTERVAL '1 hour');

-- Market Ticks Table (real-time price updates)
CREATE TABLE market_data.ticks (
    time TIMESTAMPTZ NOT NULL,
    symbol VARCHAR(20) NOT NULL,
    price DECIMAL(20,8) NOT NULL,
    volume DECIMAL(20,8) NOT NULL,
    side VARCHAR(4) CHECK (side IN ('buy', 'sell')),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

SELECT create_hypertable('market_data.ticks', 'time', chunk_time_interval => INTERVAL '15 minutes');

-- Order Book Data Table
CREATE TABLE market_data.order_book (
    time TIMESTAMPTZ NOT NULL,
    symbol VARCHAR(20) NOT NULL,
    side VARCHAR(4) NOT NULL CHECK (side IN ('bid', 'ask')),
    price DECIMAL(20,8) NOT NULL,
    quantity DECIMAL(20,8) NOT NULL,
    level_index INTEGER NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

SELECT create_hypertable('market_data.order_book', 'time', chunk_time_interval => INTERVAL '5 minutes');

-- Agent Signals Table
CREATE TABLE agent_data.signals (
    time TIMESTAMPTZ NOT NULL,
    agent_id VARCHAR(100) NOT NULL,
    signal_type VARCHAR(20) NOT NULL CHECK (signal_type IN ('buy', 'sell', 'hold', 'alert')),
    symbol VARCHAR(20) NOT NULL,
    strength DECIMAL(3,2) NOT NULL CHECK (strength >= 0 AND strength <= 1),
    confidence DECIMAL(3,2) NOT NULL CHECK (confidence >= 0 AND confidence <= 1),
    reasoning TEXT,
    metadata JSONB,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

SELECT create_hypertable('agent_data.signals', 'time', chunk_time_interval => INTERVAL '1 hour');

-- Market Analysis Table
CREATE TABLE analysis.market_analysis (
    time TIMESTAMPTZ NOT NULL,
    symbol VARCHAR(20) NOT NULL,
    agent_id VARCHAR(100) NOT NULL,
    trend VARCHAR(20) CHECK (trend IN ('up', 'down', 'sideways')),
    pattern VARCHAR(100),
    indicators JSONB,
    ai_analysis TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

SELECT create_hypertable('analysis.market_analysis', 'time', chunk_time_interval => INTERVAL '2 hours');

-- Create indexes for better query performance
CREATE INDEX idx_ohlcv_symbol_time ON market_data.ohlcv (symbol, time DESC);
CREATE INDEX idx_ticks_symbol_time ON market_data.ticks (symbol, time DESC);
CREATE INDEX idx_signals_agent_time ON agent_data.signals (agent_id, time DESC);
CREATE INDEX idx_signals_symbol_time ON agent_data.signals (symbol, time DESC);
CREATE INDEX idx_analysis_symbol_time ON analysis.market_analysis (symbol, time DESC);

-- Create continuous aggregates for common queries
CREATE MATERIALIZED VIEW market_data.ohlcv_1m
WITH (timescaledb.continuous) AS
SELECT 
    time_bucket('1 minute', time) AS bucket,
    symbol,
    exchange,
    FIRST(open, time) AS open,
    MAX(high) AS high,
    MIN(low) AS low,
    LAST(close, time) AS close,
    SUM(volume) AS volume,
    COUNT(*) AS tick_count
FROM market_data.ohlcv
GROUP BY bucket, symbol, exchange;

CREATE MATERIALIZED VIEW market_data.ohlcv_5m
WITH (timescaledb.continuous) AS
SELECT 
    time_bucket('5 minutes', time) AS bucket,
    symbol,
    exchange,
    FIRST(open, time) AS open,
    MAX(high) AS high,
    MIN(low) AS low,
    LAST(close, time) AS close,
    SUM(volume) AS volume,
    COUNT(*) AS tick_count
FROM market_data.ohlcv
GROUP BY bucket, symbol, exchange;

-- Add refresh policies for continuous aggregates
SELECT add_continuous_aggregate_policy('market_data.ohlcv_1m',
    start_offset => INTERVAL '1 hour',
    end_offset => INTERVAL '1 minute',
    schedule_interval => INTERVAL '1 minute');

SELECT add_continuous_aggregate_policy('market_data.ohlcv_5m',
    start_offset => INTERVAL '2 hours',
    end_offset => INTERVAL '5 minutes', 
    schedule_interval => INTERVAL '5 minutes');

-- Create data retention policies (optional)
-- Keep raw tick data for 7 days
SELECT add_retention_policy('market_data.ticks', INTERVAL '7 days');

-- Keep order book data for 3 days  
SELECT add_retention_policy('market_data.order_book', INTERVAL '3 days');

-- Create users and permissions
CREATE USER qicore_app WITH PASSWORD 'qicore_password';
GRANT USAGE ON SCHEMA market_data TO qicore_app;
GRANT USAGE ON SCHEMA agent_data TO qicore_app;
GRANT USAGE ON SCHEMA analysis TO qicore_app;
GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA market_data TO qicore_app;
GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA agent_data TO qicore_app;
GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA analysis TO qicore_app;