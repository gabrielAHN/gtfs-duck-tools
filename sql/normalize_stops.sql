ALTER TABLE stops_raw ADD COLUMN IF NOT EXISTS parent_station VARCHAR;
ALTER TABLE stops_raw ADD COLUMN IF NOT EXISTS level_id VARCHAR;
ALTER TABLE stops_raw ADD COLUMN IF NOT EXISTS location_type INTEGER DEFAULT 0;
ALTER TABLE stops_raw ADD COLUMN IF NOT EXISTS wheelchair_boarding INTEGER DEFAULT 0;
ALTER TABLE stops_raw ADD COLUMN IF NOT EXISTS row_id INTEGER;
ALTER TABLE stops_raw ADD COLUMN IF NOT EXISTS location_type_name VARCHAR;
ALTER TABLE stops_raw ADD COLUMN IF NOT EXISTS wheelchair_status VARCHAR;

CREATE TABLE stops AS
WITH stops_with_casts AS (
  SELECT
    *,
    TRY_CAST(stop_id AS VARCHAR) AS stop_id_casted,
    TRY_CAST(parent_station AS VARCHAR) AS parent_station_casted,
    TRY_CAST(stop_lat AS DOUBLE) AS stop_lat_casted,
    TRY_CAST(stop_lon AS DOUBLE) AS stop_lon_casted,
    COALESCE(TRY_CAST(location_type AS INTEGER), 0) AS location_type_coalesced,
    COALESCE(TRY_CAST(wheelchair_boarding AS INTEGER), 0) AS wheelchair_boarding_coalesced
  FROM stops_raw
)
SELECT
  CAST(ROW_NUMBER() OVER () AS INTEGER) AS row_id,
  COALESCE(stop_id_casted, CAST(stop_id AS VARCHAR)) AS stop_id,
  stop_name,
  stop_lat_casted AS stop_lat,
  stop_lon_casted AS stop_lon,
  COALESCE(parent_station_casted, TRY_CAST(parent_station AS VARCHAR)) AS parent_station,
  location_type_coalesced AS location_type,
  wheelchair_boarding_coalesced AS wheelchair_boarding,
  * EXCLUDE (
    row_id, stop_id, stop_name, stop_lat, stop_lon,
    parent_station, location_type, wheelchair_boarding,
    location_type_name, wheelchair_status,
    stop_id_casted, parent_station_casted, stop_lat_casted, stop_lon_casted,
    location_type_coalesced, wheelchair_boarding_coalesced
  ),
  location_type_to_name(location_type_coalesced, COALESCE(parent_station_casted, TRY_CAST(parent_station AS VARCHAR))) AS location_type_name,
  wheelchair_to_emoji(wheelchair_boarding_coalesced) AS wheelchair_status
FROM stops_with_casts;

DROP TABLE IF EXISTS stops_raw;
