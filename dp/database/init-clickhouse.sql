-- ClickHouse Initialization for QiCore Crypto Data Platform
-- This script sets up analytics tables for historical analysis and aggregations

-- Create database
CREATE DATABASE IF NOT EXISTS crypto_analytics;

-- Use the database
USE crypto_analytics;

-- OHLCV Historical Data (optimized for analytics)
CREATE TABLE ohlcv_historical (
    timestamp DateTime64(3) CODEC(Delta, ZSTD),
    symbol LowCardinality(String) CODEC(ZSTD),
    exchange LowCardinality(String) CODEC(ZSTD),
    open Decimal64(8) CODEC(ZSTD),
    high Decimal64(8) CODEC(ZSTD),
    low Decimal64(8) CODEC(ZSTD),
    close Decimal64(8) CODEC(ZSTD),
    volume Decimal64(8) CODEC(ZSTD),
    created_at DateTime DEFAULT now() CODEC(ZSTD)
) ENGINE = MergeTree()
PARTITION BY toYYYYMM(timestamp)
ORDER BY (symbol, timestamp)
SETTINGS index_granularity = 8192;

-- Market Analysis Results (for ML training and backtesting)
CREATE TABLE market_analysis_historical (
    timestamp DateTime64(3) CODEC(Delta, ZSTD),
    symbol LowCardinality(String) CODEC(ZSTD),
    agent_id LowCardinality(String) CODEC(ZSTD),
    trend LowCardinality(String) CODEC(ZSTD),
    pattern String CODEC(ZSTD),
    indicators String CODEC(ZSTD), -- JSON string
    ai_analysis String CODEC(ZSTD),
    signal_strength Decimal32(2) CODEC(ZSTD),
    confidence Decimal32(2) CODEC(ZSTD),
    created_at DateTime DEFAULT now() CODEC(ZSTD)
) ENGINE = MergeTree()
PARTITION BY toYYYYMM(timestamp)
ORDER BY (symbol, agent_id, timestamp)
SETTINGS index_granularity = 8192;

-- Agent Performance Metrics
CREATE TABLE agent_performance (
    timestamp DateTime64(3) CODEC(Delta, ZSTD),
    agent_id LowCardinality(String) CODEC(ZSTD),
    symbol LowCardinality(String) CODEC(ZSTD),
    signal_type LowCardinality(String) CODEC(ZSTD),
    predicted_direction LowCardinality(String) CODEC(ZSTD),
    actual_direction LowCardinality(String) CODEC(ZSTD),
    accuracy Decimal32(4) CODEC(ZSTD),
    response_time_ms UInt32 CODEC(ZSTD),
    model_used LowCardinality(String) CODEC(ZSTD),
    created_at DateTime DEFAULT now() CODEC(ZSTD)
) ENGINE = MergeTree()
PARTITION BY toYYYYMM(timestamp)
ORDER BY (agent_id, timestamp)
SETTINGS index_granularity = 8192;

-- Trading Signals Archive (for backtesting)
CREATE TABLE trading_signals_archive (
    timestamp DateTime64(3) CODEC(Delta, ZSTD),
    agent_id LowCardinality(String) CODEC(ZSTD),
    symbol LowCardinality(String) CODEC(ZSTD),
    signal_type LowCardinality(String) CODEC(ZSTD),
    strength Decimal32(2) CODEC(ZSTD),
    confidence Decimal32(2) CODEC(ZSTD),
    reasoning String CODEC(ZSTD),
    metadata String CODEC(ZSTD), -- JSON string
    price_at_signal Decimal64(8) CODEC(ZSTD),
    created_at DateTime DEFAULT now() CODEC(ZSTD)
) ENGINE = MergeTree()
PARTITION BY toYYYYMM(timestamp)
ORDER BY (symbol, timestamp)
SETTINGS index_granularity = 8192;

-- Create materialized views for common aggregations

-- Daily OHLCV aggregation
CREATE MATERIALIZED VIEW ohlcv_daily_mv
ENGINE = AggregatingMergeTree()
PARTITION BY toYYYYMM(day)
ORDER BY (symbol, day)
AS SELECT
    toDate(timestamp) as day,
    symbol,
    exchange,
    argMinState(open, timestamp) as open_state,
    maxState(high) as high_state,
    minState(low) as low_state,
    argMaxState(close, timestamp) as close_state,
    sumState(volume) as volume_state,
    countState() as count_state
FROM ohlcv_historical
GROUP BY day, symbol, exchange;

-- Hourly agent performance
CREATE MATERIALIZED VIEW agent_performance_hourly_mv
ENGINE = AggregatingMergeTree()
PARTITION BY toYYYYMM(hour)
ORDER BY (agent_id, hour)
AS SELECT
    toStartOfHour(timestamp) as hour,
    agent_id,
    avgState(accuracy) as avg_accuracy_state,
    avgState(response_time_ms) as avg_response_time_state,
    countState() as signal_count_state,
    countIfState(predicted_direction = actual_direction) as correct_predictions_state
FROM agent_performance
GROUP BY hour, agent_id;

-- Symbol volatility analysis
CREATE MATERIALIZED VIEW symbol_volatility_mv
ENGINE = AggregatingMergeTree()
PARTITION BY toYYYYMM(hour)
ORDER BY (symbol, hour)
AS SELECT
    toStartOfHour(timestamp) as hour,
    symbol,
    avgState(close) as avg_price_state,
    stddevSampState(close) as price_stddev_state,
    maxState(high) as max_high_state,
    minState(low) as min_low_state,
    sumState(volume) as total_volume_state
FROM ohlcv_historical
GROUP BY hour, symbol;

-- Create useful views for analytics queries

-- Daily OHLCV View
CREATE VIEW ohlcv_daily AS
SELECT
    day,
    symbol,
    exchange,
    argMinMerge(open_state) as open,
    maxMerge(high_state) as high,
    minMerge(low_state) as low,
    argMaxMerge(close_state) as close,
    sumMerge(volume_state) as volume,
    countMerge(count_state) as tick_count
FROM ohlcv_daily_mv
GROUP BY day, symbol, exchange
ORDER BY day DESC, symbol;

-- Agent Performance Summary View
CREATE VIEW agent_performance_summary AS
SELECT
    hour,
    agent_id,
    avgMerge(avg_accuracy_state) as avg_accuracy,
    avgMerge(avg_response_time_state) as avg_response_time_ms,
    countMerge(signal_count_state) as total_signals,
    countMerge(correct_predictions_state) as correct_predictions,
    countMerge(correct_predictions_state) / countMerge(signal_count_state) as success_rate
FROM agent_performance_hourly_mv
GROUP BY hour, agent_id
ORDER BY hour DESC, agent_id;

-- Symbol Volatility View
CREATE VIEW symbol_volatility AS
SELECT
    hour,
    symbol,
    avgMerge(avg_price_state) as avg_price,
    stddevSampMerge(price_stddev_state) as price_volatility,
    maxMerge(max_high_state) as period_high,
    minMerge(min_low_state) as period_low,
    sumMerge(total_volume_state) as total_volume,
    (maxMerge(max_high_state) - minMerge(min_low_state)) / avgMerge(avg_price_state) as volatility_ratio
FROM symbol_volatility_mv
GROUP BY hour, symbol
ORDER BY hour DESC, volatility_ratio DESC;

-- Create indexes for faster queries
-- ClickHouse doesn't have traditional indexes, but we can create skipping indexes

-- Skip index for faster symbol searches
ALTER TABLE ohlcv_historical ADD INDEX idx_symbol symbol TYPE set(0) GRANULARITY 1;
ALTER TABLE market_analysis_historical ADD INDEX idx_symbol symbol TYPE set(0) GRANULARITY 1;
ALTER TABLE trading_signals_archive ADD INDEX idx_symbol symbol TYPE set(0) GRANULARITY 1;

-- Skip index for agent_id searches
ALTER TABLE market_analysis_historical ADD INDEX idx_agent_id agent_id TYPE set(0) GRANULARITY 1;
ALTER TABLE agent_performance ADD INDEX idx_agent_id agent_id TYPE set(0) GRANULARITY 1;
ALTER TABLE trading_signals_archive ADD INDEX idx_agent_id agent_id TYPE set(0) GRANULARITY 1;

-- Bloom filter index for text searches in reasoning
ALTER TABLE trading_signals_archive ADD INDEX idx_reasoning_bloom reasoning TYPE bloom_filter() GRANULARITY 1;
ALTER TABLE market_analysis_historical ADD INDEX idx_analysis_bloom ai_analysis TYPE bloom_filter() GRANULARITY 1;