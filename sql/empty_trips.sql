CREATE TABLE IF NOT EXISTS trips (
  row_id INTEGER, route_id VARCHAR, service_id VARCHAR, trip_id VARCHAR,
  trip_headsign VARCHAR, trip_short_name VARCHAR, direction_id INTEGER,
  block_id VARCHAR, shape_id VARCHAR, wheelchair_accessible INTEGER,
  bikes_allowed INTEGER
);
