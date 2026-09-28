ALTER TABLE routes_raw ADD COLUMN IF NOT EXISTS route_id VARCHAR;
ALTER TABLE routes_raw ADD COLUMN IF NOT EXISTS agency_id VARCHAR;
ALTER TABLE routes_raw ADD COLUMN IF NOT EXISTS route_short_name VARCHAR;
ALTER TABLE routes_raw ADD COLUMN IF NOT EXISTS route_long_name VARCHAR;
ALTER TABLE routes_raw ADD COLUMN IF NOT EXISTS route_desc VARCHAR;
ALTER TABLE routes_raw ADD COLUMN IF NOT EXISTS route_type INTEGER;
ALTER TABLE routes_raw ADD COLUMN IF NOT EXISTS route_url VARCHAR;
ALTER TABLE routes_raw ADD COLUMN IF NOT EXISTS route_color VARCHAR;
ALTER TABLE routes_raw ADD COLUMN IF NOT EXISTS route_text_color VARCHAR;
ALTER TABLE routes_raw ADD COLUMN IF NOT EXISTS route_sort_order INTEGER;
ALTER TABLE routes_raw ADD COLUMN IF NOT EXISTS row_id INTEGER;
ALTER TABLE routes_raw ADD COLUMN IF NOT EXISTS route_name VARCHAR;
ALTER TABLE routes_raw ADD COLUMN IF NOT EXISTS route_type_name VARCHAR;
ALTER TABLE routes_raw ADD COLUMN IF NOT EXISTS route_color_hex VARCHAR;
ALTER TABLE routes_raw ADD COLUMN IF NOT EXISTS route_text_color_hex VARCHAR;

CREATE TABLE routes AS
WITH routes_with_casts AS (
  SELECT
    *,
    TRY_CAST(route_id AS VARCHAR) AS route_id_casted,
    TRY_CAST(agency_id AS VARCHAR) AS agency_id_casted,
    TRY_CAST(route_short_name AS VARCHAR) AS route_short_name_casted,
    TRY_CAST(route_long_name AS VARCHAR) AS route_long_name_casted,
    TRY_CAST(route_desc AS VARCHAR) AS route_desc_casted,
    COALESCE(TRY_CAST(route_type AS INTEGER), 3) AS route_type_coalesced,
    TRY_CAST(route_url AS VARCHAR) AS route_url_casted,
    TRY_CAST(route_color AS VARCHAR) AS route_color_casted,
    TRY_CAST(route_text_color AS VARCHAR) AS route_text_color_casted,
    TRY_CAST(route_sort_order AS INTEGER) AS route_sort_order_casted
  FROM routes_raw
)
SELECT
  CAST(ROW_NUMBER() OVER () AS INTEGER) AS row_id,
  COALESCE(route_id_casted, CAST(route_id AS VARCHAR)) AS route_id,
  agency_id_casted AS agency_id,
  route_short_name_casted AS route_short_name,
  route_long_name_casted AS route_long_name,
  route_desc_casted AS route_desc,
  route_type_coalesced AS route_type,
  route_url_casted AS route_url,
  route_color_casted AS route_color,
  route_text_color_casted AS route_text_color,
  route_sort_order_casted AS route_sort_order,
  * EXCLUDE (
    row_id, route_id, agency_id, route_short_name, route_long_name, route_desc,
    route_type, route_url, route_color, route_text_color, route_sort_order,
    route_name, route_type_name, route_color_hex, route_text_color_hex,
    route_id_casted, agency_id_casted, route_short_name_casted,
    route_long_name_casted, route_desc_casted, route_type_coalesced,
    route_url_casted, route_color_casted, route_text_color_casted,
    route_sort_order_casted
  ),
  COALESCE(NULLIF(route_short_name_casted, ''), NULLIF(route_long_name_casted, ''), COALESCE(route_id_casted, CAST(route_id AS VARCHAR))) AS route_name,
  route_type_to_name(route_type_coalesced) AS route_type_name,
  gtfs_color_to_hex(route_color_casted, '#4f46e5') AS route_color_hex,
  gtfs_color_to_hex(route_text_color_casted, '#ffffff') AS route_text_color_hex
FROM routes_with_casts;

DROP TABLE IF EXISTS routes_raw;
