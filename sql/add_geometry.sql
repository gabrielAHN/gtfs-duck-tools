ALTER TABLE stops ADD COLUMN IF NOT EXISTS geom GEOMETRY;
UPDATE stops SET geom = ST_Point(stop_lon, stop_lat) WHERE stop_lat IS NOT NULL AND stop_lon IS NOT NULL AND geom IS NULL;
ALTER TABLE shapes ADD COLUMN IF NOT EXISTS geom GEOMETRY;
UPDATE shapes SET geom = ST_Point(shape_pt_lon, shape_pt_lat) WHERE shape_pt_lat IS NOT NULL AND shape_pt_lon IS NOT NULL AND geom IS NULL;
