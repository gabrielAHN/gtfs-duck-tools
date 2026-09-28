CREATE TABLE IF NOT EXISTS RouteShapeBandsTable (
  route_id VARCHAR, route_name VARCHAR, route_color_hex VARCHAR, route_text_color_hex VARCHAR,
  shape_id VARCHAR, shape_pt_sequence DOUBLE, shape_pt_lat DOUBLE, shape_pt_lon DOUBLE,
  band_index SMALLINT, band_count SMALLINT, slot FLOAT, turn_radius FLOAT);
CREATE TABLE IF NOT EXISTS RouteShapeLanesTable (
  route_id VARCHAR, shape_id VARCHAR, shape_pt_sequence DOUBLE, lat DOUBLE, lon DOUBLE,
  coslat DOUBLE, ux DOUBLE, uy DOUBLE, band_index BIGINT, band_count BIGINT,
  shift_s DOUBLE, slot_s DOUBLE, plat DOUBLE, plon DOUBLE, nlat DOUBLE, nlon DOUBLE);
CREATE TABLE IF NOT EXISTS RouteShapeMacroVersion (version VARCHAR);
