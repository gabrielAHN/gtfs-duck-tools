ALTER TABLE pathways_raw ADD COLUMN IF NOT EXISTS pathway_mode INTEGER DEFAULT 1;
ALTER TABLE pathways_raw ADD COLUMN IF NOT EXISTS is_bidirectional INTEGER DEFAULT 1;
ALTER TABLE pathways_raw ADD COLUMN IF NOT EXISTS length DOUBLE;
ALTER TABLE pathways_raw ADD COLUMN IF NOT EXISTS traversal_time INTEGER;
ALTER TABLE pathways_raw ADD COLUMN IF NOT EXISTS stair_count INTEGER;
ALTER TABLE pathways_raw ADD COLUMN IF NOT EXISTS max_slope DOUBLE;
ALTER TABLE pathways_raw ADD COLUMN IF NOT EXISTS min_width DOUBLE;
ALTER TABLE pathways_raw ADD COLUMN IF NOT EXISTS signposted_as VARCHAR;
ALTER TABLE pathways_raw ADD COLUMN IF NOT EXISTS reversed_signposted_as VARCHAR;
ALTER TABLE pathways_raw ADD COLUMN IF NOT EXISTS row_id INTEGER;
ALTER TABLE pathways_raw ADD COLUMN IF NOT EXISTS pathway_mode_name VARCHAR;
ALTER TABLE pathways_raw ADD COLUMN IF NOT EXISTS direction_type VARCHAR;

CREATE TABLE pathways AS
WITH pathways_with_casts AS (
  SELECT
    *,
    TRY_CAST(pathway_id AS VARCHAR) AS pathway_id_casted,
    TRY_CAST(from_stop_id AS VARCHAR) AS from_stop_id_casted,
    TRY_CAST(to_stop_id AS VARCHAR) AS to_stop_id_casted,
    COALESCE(TRY_CAST(pathway_mode AS INTEGER), 1) AS pathway_mode_coalesced,
    COALESCE(TRY_CAST(is_bidirectional AS INTEGER), 1) AS is_bidirectional_coalesced,
    TRY_CAST(length AS DOUBLE) AS length_casted,
    TRY_CAST(traversal_time AS INTEGER) AS traversal_time_casted,
    TRY_CAST(stair_count AS INTEGER) AS stair_count_casted,
    TRY_CAST(max_slope AS DOUBLE) AS max_slope_casted,
    TRY_CAST(min_width AS DOUBLE) AS min_width_casted
  FROM pathways_raw
)
SELECT
  CAST(ROW_NUMBER() OVER () AS INTEGER) AS row_id,
  COALESCE(pathway_id_casted, CAST(pathway_id AS VARCHAR)) AS pathway_id,
  COALESCE(from_stop_id_casted, CAST(from_stop_id AS VARCHAR)) AS from_stop_id,
  COALESCE(to_stop_id_casted, CAST(to_stop_id AS VARCHAR)) AS to_stop_id,
  pathway_mode_coalesced AS pathway_mode,
  is_bidirectional_coalesced AS is_bidirectional,
  length_casted AS length,
  traversal_time_casted AS traversal_time,
  stair_count_casted AS stair_count,
  max_slope_casted AS max_slope,
  min_width_casted AS min_width,
  * EXCLUDE (
    row_id, pathway_id, from_stop_id, to_stop_id,
    pathway_mode, is_bidirectional, length, traversal_time, stair_count,
    max_slope, min_width, pathway_mode_name, direction_type,
    pathway_id_casted, from_stop_id_casted, to_stop_id_casted,
    pathway_mode_coalesced, is_bidirectional_coalesced, length_casted,
    traversal_time_casted, stair_count_casted, max_slope_casted,
    min_width_casted
  ),
  pathway_mode_to_name(pathway_mode_coalesced) AS pathway_mode_name,
  bidirectional_to_direction(is_bidirectional_coalesced) AS direction_type
FROM pathways_with_casts;

DROP TABLE IF EXISTS pathways_raw;
