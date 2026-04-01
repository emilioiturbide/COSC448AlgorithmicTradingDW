-- Query to retrieve data from the data warehouse
-- Schema: dw



-- Group fact table by year and symbol to get annual OHLCV (First Open, Max High, Min Low, Last Close) and total volume, along with VWAP
-- Query description: Retrieves annual stock market data including OHLCV metrics for each stock symbol, grouped by year.
SELECT
  d.month_name,
  d.year,
  i.symbol,
    MAX(f.open_price) AS open_price,
    MAX(f.high_price) AS high_price,
    MIN(f.low_price) AS low_price,
    MAX(f.close_price) AS close_price,
    SUM(f.volume) AS total_volume
FROM dw.fact_15min_stock_price f
JOIN dw.dim_date d ON f.fk_date_id = d.sk_date_id
JOIN dw.dim_instrument i ON f.fk_instrument_id = i.sk_instrument_id
GROUP BY d.month_name, d.year, i.symbol
ORDER BY d.year, i.symbol;



