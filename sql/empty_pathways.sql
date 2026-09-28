CREATE TABLE IF NOT EXISTS pathways (
  row_id INTEGER, pathway_id VARCHAR,
  from_stop_id VARCHAR, to_stop_id VARCHAR,
  pathway_mode INTEGER, is_bidirectional INTEGER,
  length DOUBLE, traversal_time INTEGER, stair_count INTEGER,
  max_slope DOUBLE, min_width DOUBLE,
  signposted_as VARCHAR, reversed_signposted_as VARCHAR,
  pathway_mode_name VARCHAR, direction_type VARCHAR
);
