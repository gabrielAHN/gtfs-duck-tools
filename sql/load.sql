

-- Map zoom helper (scalar — no table references)
CREATE OR REPLACE MACRO fit_zoom(min_lon, max_lon, min_lat, max_lat) AS (
  GREATEST(4, LEAST(17,
    ROUND(LOG2(360.0 / GREATEST(
      GREATEST(ABS(max_lon - min_lon), 0.001),
      GREATEST(ABS(max_lat - min_lat), 0.001)
    )) - 0.3)
  ))
);

-- Enum helper macros (scalar — no table references)
CREATE OR REPLACE MACRO pathway_mode_to_name(mode) AS (
  CASE mode
    WHEN 1 THEN 'Walkway'
    WHEN 2 THEN 'Stairs'
    WHEN 3 THEN 'Moving sidewalk/travelator'
    WHEN 4 THEN 'Escalator'
    WHEN 5 THEN 'Elevator'
    WHEN 6 THEN 'Fare gate'
    WHEN 7 THEN 'Exit gate'
    ELSE '❓'
  END
);

CREATE OR REPLACE MACRO bidirectional_to_direction(is_bidirectional) AS (
  CASE is_bidirectional
    WHEN 0 THEN 'directional'
    WHEN 1 THEN 'bidirectional'
    ELSE 'unknown'
  END
);

CREATE OR REPLACE MACRO location_type_to_name(location_type, parent_station) AS (
  CASE
    WHEN location_type = 0 AND COALESCE(parent_station, '') != '' THEN 'Platform'
    WHEN location_type = 0 THEN 'Stop'
    WHEN location_type = 1 THEN 'Station'
    WHEN location_type = 2 THEN 'Exit/Entrance'
    WHEN location_type = 3 THEN 'Pathway Node'
    WHEN location_type = 4 THEN 'Boarding Area'
    ELSE 'Unknown'
  END
);

CREATE OR REPLACE MACRO wheelchair_to_emoji(wheelchair_boarding) AS (
  CASE wheelchair_boarding
    WHEN 0 THEN '🔵'
    WHEN 1 THEN '🟢'
    WHEN 2 THEN '🔴'
    ELSE '🟡'
  END
);

CREATE OR REPLACE MACRO route_type_to_name(route_type) AS (
  CASE route_type
    WHEN 0 THEN 'Tram, Streetcar, Light rail'
    WHEN 1 THEN 'Subway, Metro'
    WHEN 2 THEN 'Rail'
    WHEN 3 THEN 'Bus'
    WHEN 4 THEN 'Ferry'
    WHEN 5 THEN 'Cable tram'
    WHEN 6 THEN 'Aerial lift'
    WHEN 7 THEN 'Funicular'
    WHEN 11 THEN 'Trolleybus'
    WHEN 12 THEN 'Monorail'
    ELSE 'Other'
  END
);

CREATE OR REPLACE MACRO gtfs_color_to_hex(color_value, fallback_value) AS (
  CASE
    WHEN color_value IS NULL OR TRIM(CAST(color_value AS VARCHAR)) = '' THEN fallback_value
    WHEN LEFT(TRIM(CAST(color_value AS VARCHAR)), 1) = '#' THEN TRIM(CAST(color_value AS VARCHAR))
    ELSE '#' || TRIM(CAST(color_value AS VARCHAR))
  END
);

-- Edit tracking tables (no data dependency)
CREATE TABLE IF NOT EXISTS EditStopTable (
    row_id TEXT NOT NULL,
    stop_id TEXT NOT NULL,
    stop_name TEXT,
    stop_lat DOUBLE PRECISION,
    stop_lon DOUBLE PRECISION,
    location_type_name TEXT,
    parent_station TEXT,
    level_id TEXT,
    wheelchair_status TEXT,
    status TEXT
);
ALTER TABLE EditStopTable ADD COLUMN IF NOT EXISTS level_id TEXT;

CREATE TABLE IF NOT EXISTS EditPathwayTable (
    row_id INTEGER NOT NULL,
    pathway_id TEXT NOT NULL,
    from_stop_id TEXT NOT NULL,
    to_stop_id TEXT NOT NULL,
    pathway_mode INTEGER DEFAULT 1,
    is_bidirectional INTEGER DEFAULT 1,
    length DOUBLE,
    traversal_time INTEGER,
    stair_count INTEGER,
    max_slope DOUBLE,
    min_width DOUBLE,
    signposted_as TEXT,
    reversed_signposted_as TEXT,
    status TEXT
);

CREATE TABLE IF NOT EXISTS EditRouteTable (
    row_id TEXT NOT NULL,
    route_id TEXT NOT NULL,
    agency_id TEXT,
    route_short_name TEXT,
    route_long_name TEXT,
    route_desc TEXT,
    route_type INTEGER,
    route_url TEXT,
    route_color TEXT,
    route_text_color TEXT,
    route_sort_order INTEGER,
    shape_points_json TEXT,
    status TEXT
);
ALTER TABLE EditRouteTable ADD COLUMN IF NOT EXISTS shape_points_json TEXT;

CREATE TABLE IF NOT EXISTS EditStopTimesTable (
    row_id TEXT NOT NULL,
    trip_id TEXT NOT NULL,
    stop_sequence INTEGER,
    stop_id TEXT,
    arrival_time TEXT,
    departure_time TEXT,
    stop_headsign TEXT,
    pickup_type INTEGER,
    drop_off_type INTEGER,
    shape_dist_traveled DOUBLE,
    status TEXT
);
ALTER TABLE EditStopTimesTable ADD COLUMN IF NOT EXISTS edit_type TEXT;
ALTER TABLE EditStopTimesTable ADD COLUMN IF NOT EXISTS edit_source_trip_id TEXT;
ALTER TABLE EditStopTimesTable ADD COLUMN IF NOT EXISTS edit_from_stop_name TEXT;
ALTER TABLE EditStopTimesTable ADD COLUMN IF NOT EXISTS edit_to_stop_name TEXT;

CREATE TABLE IF NOT EXISTS EditCalendarTable (
    row_id TEXT NOT NULL,
    service_id TEXT NOT NULL,
    monday INTEGER,
    tuesday INTEGER,
    wednesday INTEGER,
    thursday INTEGER,
    friday INTEGER,
    saturday INTEGER,
    sunday INTEGER,
    start_date TEXT,
    end_date TEXT,
    status TEXT
);

CREATE TABLE IF NOT EXISTS EditTripsTable (
    row_id TEXT NOT NULL,
    route_id TEXT NOT NULL,
    service_id TEXT NOT NULL,
    trip_id TEXT NOT NULL,
    trip_headsign TEXT,
    trip_short_name TEXT,
    direction_id INTEGER,
    block_id TEXT,
    shape_id TEXT,
    wheelchair_accessible INTEGER,
    bikes_allowed INTEGER,
    status TEXT
);

CREATE TABLE IF NOT EXISTS EditCalendarDatesTable (
    row_id TEXT NOT NULL,
    service_id TEXT NOT NULL,
    date TEXT NOT NULL,
    exception_type INTEGER,
    status TEXT
);
