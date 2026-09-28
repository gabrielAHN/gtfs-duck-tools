CREATE TABLE stop_times AS SELECT * FROM stop_times_raw;
DROP TABLE stop_times_raw;

ALTER TABLE stop_times ADD COLUMN IF NOT EXISTS trip_id VARCHAR;
ALTER TABLE stop_times ADD COLUMN IF NOT EXISTS arrival_time VARCHAR;
ALTER TABLE stop_times ADD COLUMN IF NOT EXISTS departure_time VARCHAR;
ALTER TABLE stop_times ADD COLUMN IF NOT EXISTS stop_id VARCHAR;
ALTER TABLE stop_times ADD COLUMN IF NOT EXISTS stop_sequence INTEGER;
ALTER TABLE stop_times ADD COLUMN IF NOT EXISTS stop_headsign VARCHAR;
ALTER TABLE stop_times ADD COLUMN IF NOT EXISTS pickup_type INTEGER;
ALTER TABLE stop_times ADD COLUMN IF NOT EXISTS drop_off_type INTEGER;
ALTER TABLE stop_times ADD COLUMN IF NOT EXISTS shape_dist_traveled DOUBLE;
ALTER TABLE stop_times ADD COLUMN IF NOT EXISTS timepoint INTEGER;
ALTER TABLE stop_times ADD COLUMN IF NOT EXISTS row_id INTEGER;

CREATE TEMP TABLE stop_times_temp AS SELECT * FROM stop_times;
DROP TABLE stop_times;

CREATE TABLE stop_times AS
WITH stop_times_with_casts AS (
  SELECT
    *,
    TRY_CAST(trip_id AS VARCHAR) AS trip_id_casted,
    TRY_CAST(arrival_time AS VARCHAR) AS arrival_time_casted,
    TRY_CAST(departure_time AS VARCHAR) AS departure_time_casted,
    TRY_CAST(stop_id AS VARCHAR) AS stop_id_casted,
    TRY_CAST(stop_sequence AS INTEGER) AS stop_sequence_casted,
    TRY_CAST(stop_headsign AS VARCHAR) AS stop_headsign_casted,
    TRY_CAST(pickup_type AS INTEGER) AS pickup_type_casted,
    TRY_CAST(drop_off_type AS INTEGER) AS drop_off_type_casted,
    TRY_CAST(shape_dist_traveled AS DOUBLE) AS shape_dist_traveled_casted,
    TRY_CAST(timepoint AS INTEGER) AS timepoint_casted
  FROM stop_times_temp
)
SELECT
  CAST(ROW_NUMBER() OVER () AS INTEGER) AS row_id,
  COALESCE(trip_id_casted, CAST(trip_id AS VARCHAR)) AS trip_id,
  arrival_time_casted AS arrival_time,
  departure_time_casted AS departure_time,
  COALESCE(stop_id_casted, CAST(stop_id AS VARCHAR)) AS stop_id,
  COALESCE(stop_sequence_casted, 0) AS stop_sequence,
  stop_headsign_casted AS stop_headsign,
  pickup_type_casted AS pickup_type,
  drop_off_type_casted AS drop_off_type,
  shape_dist_traveled_casted AS shape_dist_traveled,
  timepoint_casted AS timepoint,
  * EXCLUDE (
    row_id, trip_id, arrival_time, departure_time, stop_id, stop_sequence,
    stop_headsign, pickup_type, drop_off_type, shape_dist_traveled, timepoint,
    trip_id_casted, arrival_time_casted, departure_time_casted,
    stop_id_casted, stop_sequence_casted, stop_headsign_casted,
    pickup_type_casted, drop_off_type_casted, shape_dist_traveled_casted,
    timepoint_casted
  )
FROM stop_times_with_casts;

DROP TABLE IF EXISTS stop_times_temp;
