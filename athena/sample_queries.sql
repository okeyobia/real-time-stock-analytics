-- ============================================
-- Athena Sample Queries for Stock Market Analytics
-- ============================================
-- These queries demonstrate the analytical capabilities
-- of the data pipeline using AWS Athena.

-- ============================================
-- Query 1: Daily Trading Summary
-- ============================================
-- Get comprehensive daily statistics for each stock

SELECT
  symbol,
  AVG(price) AS avg_price
FROM stock_market_data
WHERE year = 2026 AND month = 1 AND day = 18
GROUP BY symbol;

-- ============================================
-- Intraday price trend for a single stock
-- Query 2: Intraday Price Trend for AAPL

SELECT
  event_time,
  price
FROM stock_market_data
WHERE symbol = 'AAPL'
  AND year = 2026
  AND month = 1
  AND day = 18
ORDER BY event_time;

-- ============================================
-- Query 3: Top 5 Stocks by Volume
-- Identify the top 5 stocks with the highest trading volume for a specific day
SELECT
  symbol,
  SUM(volume) AS total_volume
FROM stock_market_data
WHERE year = 2026
GROUP BY symbol
ORDER BY total_volume DESC
LIMIT 5;

-- ============================================
-- Query 4: Price Volatility Analysis
-- Calculate the price volatility for each stock over a week
SELECT
  symbol,
  MAX(price) - MIN(price) AS price_volatility
FROM stock_market_data
WHERE year = 2026 AND month = 1 AND day BETWEEN 11 AND 18
GROUP BY symbol
ORDER BY price_volatility DESC; 

-- ============================================
-- Query 5: Moving Average Calculation
-- Calculate the 5-day moving average for a specific stock

SELECT
  symbol,
  event_time,
  price,
  AVG(price) OVER (
    PARTITION BY symbol
    ORDER BY event_time
    ROWS BETWEEN 4 PRECEDING AND CURRENT ROW
  ) AS moving_avg_5
FROM stock_market_data
WHERE year = 2026 AND month = 1 AND day = 18;
-- Note: Adjust the date filters as needed to match your data
-- ============================================