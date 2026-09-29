CREATE TABLE calendar_dates AS SELECT * FROM calendar_dates_raw;
DROP TABLE calendar_dates_raw;

ALTER TABLE calendar_dates ADD COLUMN IF NOT EXISTS service_id VARCHAR;
ALTER TABLE calendar_dates ADD COLUMN IF NOT EXISTS date VARCHAR;
ALTER TABLE calendar_dates ADD COLUMN IF NOT EXISTS exception_type INTEGER;

CREATE TEMP TABLE calendar_dates_temp AS SELECT * FROM calendar_dates;
DROP TABLE calendar_dates;

CREATE TABLE calendar_dates AS
SELECT
  CAST(ROW_NUMBER() OVER () AS INTEGER) AS row_id,
  TRY_CAST(service_id AS VARCHAR) AS service_id,
  TRY_CAST(date AS VARCHAR) AS date,
  TRY_CAST(exception_type AS INTEGER) AS exception_type
FROM calendar_dates_temp;

DROP TABLE IF EXISTS calendar_dates_temp;
