ALTER TABLE trips_raw ADD COLUMN IF NOT EXISTS route_id VARCHAR;
ALTER TABLE trips_raw ADD COLUMN IF NOT EXISTS service_id VARCHAR;
ALTER TABLE trips_raw ADD COLUMN IF NOT EXISTS trip_id VARCHAR;
ALTER TABLE trips_raw ADD COLUMN IF NOT EXISTS trip_headsign VARCHAR;
ALTER TABLE trips_raw ADD COLUMN IF NOT EXISTS trip_short_name VARCHAR;
ALTER TABLE trips_raw ADD COLUMN IF NOT EXISTS direction_id INTEGER;
ALTER TABLE trips_raw ADD COLUMN IF NOT EXISTS block_id VARCHAR;
ALTER TABLE trips_raw ADD COLUMN IF NOT EXISTS shape_id VARCHAR;
ALTER TABLE trips_raw ADD COLUMN IF NOT EXISTS wheelchair_accessible INTEGER;
ALTER TABLE trips_raw ADD COLUMN IF NOT EXISTS bikes_allowed INTEGER;
ALTER TABLE trips_raw ADD COLUMN IF NOT EXISTS row_id INTEGER;

CREATE TABLE trips AS
WITH trips_with_casts AS (
  SELECT
    *,
    TRY_CAST(route_id AS VARCHAR) AS route_id_casted,
    TRY_CAST(service_id AS VARCHAR) AS service_id_casted,
    TRY_CAST(trip_id AS VARCHAR) AS trip_id_casted,
    TRY_CAST(trip_headsign AS VARCHAR) AS trip_headsign_casted,
    TRY_CAST(trip_short_name AS VARCHAR) AS trip_short_name_casted,
    TRY_CAST(direction_id AS INTEGER) AS direction_id_casted,
    TRY_CAST(block_id AS VARCHAR) AS block_id_casted,
    TRY_CAST(shape_id AS VARCHAR) AS shape_id_casted,
    TRY_CAST(wheelchair_accessible AS INTEGER) AS wheelchair_accessible_casted,
    TRY_CAST(bikes_allowed AS INTEGER) AS bikes_allowed_casted
  FROM trips_raw
)
SELECT
  CAST(ROW_NUMBER() OVER () AS INTEGER) AS row_id,
  COALESCE(route_id_casted, CAST(route_id AS VARCHAR)) AS route_id,
  service_id_casted AS service_id,
  COALESCE(trip_id_casted, CAST(trip_id AS VARCHAR)) AS trip_id,
  trip_headsign_casted AS trip_headsign,
  trip_short_name_casted AS trip_short_name,
  direction_id_casted AS direction_id,
  block_id_casted AS block_id,
  shape_id_casted AS shape_id,
  wheelchair_accessible_casted AS wheelchair_accessible,
  bikes_allowed_casted AS bikes_allowed,
  * EXCLUDE (
    row_id, route_id, service_id, trip_id, trip_headsign, trip_short_name,
    direction_id, block_id, shape_id, wheelchair_accessible, bikes_allowed,
    route_id_casted, service_id_casted, trip_id_casted, trip_headsign_casted,
    trip_short_name_casted, direction_id_casted, block_id_casted,
    shape_id_casted, wheelchair_accessible_casted, bikes_allowed_casted
  )
FROM trips_with_casts;

DROP TABLE IF EXISTS trips_raw;
