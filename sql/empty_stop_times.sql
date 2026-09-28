CREATE TABLE IF NOT EXISTS stop_times (
  row_id INTEGER, trip_id VARCHAR, arrival_time VARCHAR, departure_time VARCHAR,
  stop_id VARCHAR, stop_sequence INTEGER, stop_headsign VARCHAR,
  pickup_type INTEGER, drop_off_type INTEGER, shape_dist_traveled DOUBLE,
  timepoint INTEGER
);
