CREATE TABLE shapes AS SELECT * FROM shapes_raw;
DROP TABLE shapes_raw;

ALTER TABLE shapes ADD COLUMN IF NOT EXISTS shape_id VARCHAR;
ALTER TABLE shapes ADD COLUMN IF NOT EXISTS shape_pt_lat DOUBLE;
ALTER TABLE shapes ADD COLUMN IF NOT EXISTS shape_pt_lon DOUBLE;
ALTER TABLE shapes ADD COLUMN IF NOT EXISTS shape_pt_sequence INTEGER;
ALTER TABLE shapes ADD COLUMN IF NOT EXISTS shape_dist_traveled DOUBLE;
ALTER TABLE shapes ADD COLUMN IF NOT EXISTS row_id INTEGER;

CREATE TEMP TABLE shapes_temp AS SELECT * FROM shapes;
DROP TABLE shapes;

CREATE TABLE shapes AS
WITH shapes_with_casts AS (
  SELECT
    *,
    TRY_CAST(shape_id AS VARCHAR) AS shape_id_casted,
    TRY_CAST(shape_pt_lat AS DOUBLE) AS shape_pt_lat_casted,
    TRY_CAST(shape_pt_lon AS DOUBLE) AS shape_pt_lon_casted,
    TRY_CAST(shape_pt_sequence AS INTEGER) AS shape_pt_sequence_casted,
    TRY_CAST(shape_dist_traveled AS DOUBLE) AS shape_dist_traveled_casted
  FROM shapes_temp
)
SELECT
  CAST(ROW_NUMBER() OVER () AS INTEGER) AS row_id,
  COALESCE(shape_id_casted, CAST(shape_id AS VARCHAR)) AS shape_id,
  shape_pt_lat_casted AS shape_pt_lat,
  shape_pt_lon_casted AS shape_pt_lon,
  COALESCE(shape_pt_sequence_casted, 0) AS shape_pt_sequence,
  shape_dist_traveled_casted AS shape_dist_traveled,
  * EXCLUDE (
    row_id, shape_id, shape_pt_lat, shape_pt_lon, shape_pt_sequence,
    shape_dist_traveled, shape_id_casted, shape_pt_lat_casted,
    shape_pt_lon_casted, shape_pt_sequence_casted, shape_dist_traveled_casted
  )
FROM shapes_with_casts;

DROP TABLE IF EXISTS shapes_temp;
