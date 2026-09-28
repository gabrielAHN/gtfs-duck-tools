CREATE TABLE stops (
  row_id VARCHAR, stop_id VARCHAR, stop_name VARCHAR, stop_lat DOUBLE, stop_lon DOUBLE,
  location_type INTEGER, location_type_name VARCHAR, parent_station VARCHAR, level_id VARCHAR,
  wheelchair_status VARCHAR
);
INSERT INTO stops VALUES
  ('1', 'S', 'Fixture Station', 35.0, 139.0, 1, 'Station', '', '', '🔵'),
  ('2', 'E', 'Entrance', 35.0001, 139.0, 2, 'Exit/Entrance', 'S', '', '🔵'),
  ('3', 'P', 'Platform P', 35.0002, 139.0, 0, 'Platform', 'S', '', '🔵'),
  ('4', 'Q', 'Platform Q', 35.0003, 139.0, 0, 'Platform', 'S', '', '🔵'),
  ('5', 'O', 'Outside Stop', 35.001, 139.001, 0, 'Stop', '', '', '🔵');

CREATE TABLE pathways (
  row_id INTEGER, pathway_id VARCHAR, from_stop_id VARCHAR, to_stop_id VARCHAR,
  pathway_mode INTEGER, is_bidirectional INTEGER, length DOUBLE, traversal_time INTEGER,
  stair_count INTEGER, max_slope DOUBLE, min_width DOUBLE, signposted_as VARCHAR,
  reversed_signposted_as VARCHAR, pathway_mode_name VARCHAR, direction_type VARCHAR
);
INSERT INTO pathways VALUES
  (1, 'EP', 'E', 'P', 1, 0, 30, 30, 0, 0, 2, '', '', 'Walkway', 'directional'),
  (2, 'PQ', 'P', 'Q', 1, 0, 20, 20, 0, 0, 2, '', '', 'Walkway', 'directional');

CREATE TABLE routes (
  row_id INTEGER, route_id VARCHAR, agency_id VARCHAR, route_short_name VARCHAR,
  route_long_name VARCHAR, route_desc VARCHAR, route_type INTEGER, route_url VARCHAR,
  route_color VARCHAR, route_text_color VARCHAR, route_sort_order INTEGER,
  route_name VARCHAR, route_type_name VARCHAR, route_color_hex VARCHAR, route_text_color_hex VARCHAR
);
INSERT INTO routes VALUES (1, 'R', 'A', 'R', 'Fixture Route', '', 3, '', '112233', 'ffffff', 1, 'R', 'Bus', '#112233', '#ffffff');

CREATE TABLE trips (
  row_id INTEGER, route_id VARCHAR, service_id VARCHAR, trip_id VARCHAR,
  trip_headsign VARCHAR, trip_short_name VARCHAR, direction_id INTEGER,
  block_id VARCHAR, shape_id VARCHAR, wheelchair_accessible INTEGER, bikes_allowed INTEGER
);
INSERT INTO trips VALUES (1, 'R', 'WK', 'T', 'Fixture destination', '', 0, '', 'SH', 0, 0);

CREATE TABLE stop_times (
  row_id INTEGER, trip_id VARCHAR, arrival_time VARCHAR, departure_time VARCHAR,
  stop_id VARCHAR, stop_sequence INTEGER, stop_headsign VARCHAR, pickup_type INTEGER,
  drop_off_type INTEGER, shape_dist_traveled DOUBLE, timepoint INTEGER
);
INSERT INTO stop_times VALUES
  (1, 'T', '25:00:00', '25:00:00', 'P', 1, '', 0, 0, 0, 1),
  (2, 'T', '25:10:00', '25:10:00', 'Q', 2, '', 0, 0, 10, 1);

CREATE TABLE shapes (
  row_id INTEGER, shape_id VARCHAR, shape_pt_lat DOUBLE, shape_pt_lon DOUBLE,
  shape_pt_sequence INTEGER, shape_dist_traveled DOUBLE
);
INSERT INTO shapes VALUES (1, 'SH', 35.0002, 139.0, 1, 0), (2, 'SH', 35.0003, 139.0, 2, 10);

CREATE TABLE calendar (
  row_id INTEGER, service_id VARCHAR, monday INTEGER, tuesday INTEGER, wednesday INTEGER,
  thursday INTEGER, friday INTEGER, saturday INTEGER, sunday INTEGER, start_date VARCHAR, end_date VARCHAR
);
INSERT INTO calendar VALUES (1, 'WK', 1, 1, 1, 1, 1, 0, 0, '20260101', '20261231');

CREATE TABLE calendar_dates (row_id INTEGER, service_id VARCHAR, date VARCHAR, exception_type INTEGER);
