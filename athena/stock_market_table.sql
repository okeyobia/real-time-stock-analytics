CREATE EXTERNAL TABLE IF NOT EXISTS stock_market_data (
  symbol     STRING,
  price      DOUBLE,
  volume     BIGINT,
  event_time TIMESTAMP
)
PARTITIONED BY (
  year  INT,
  month INT,
  day   INT
)
STORED AS PARQUET
LOCATION 's3://stock-historical-data/'
TBLPROPERTIES (
  'parquet.compression' = 'SNAPPY'
);
