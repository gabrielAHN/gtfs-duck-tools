import json
import os
from pathlib import Path
import subprocess
import unittest


class TransportTests(unittest.TestCase):
    def test_raw_stops_normalization_is_extension_owned(self):
        extension = str(Path(os.environ['GTFS_EXTENSION']).resolve()).replace("'", "''")
        sql = """PRAGMA gtfs_prepare;
CREATE TEMP TABLE stops_raw AS SELECT 'S' AS stop_id, 'Station' AS stop_name, '35' AS stop_lat, '139' AS stop_lon, '1' AS location_type;
PRAGMA gtfs_normalize_stops;
SELECT stop_id, stop_lat, location_type_name FROM stops;
"""
        result = subprocess.run(
            [os.environ['DUCKDB_BIN'], '-unsigned', '-json', '-cmd', f"LOAD '{extension}'", ':memory:', '-c', sql],
            capture_output=True,
            text=True,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(
            json.loads(result.stdout), [{'stop_id': 'S', 'stop_lat': 35.0, 'location_type_name': 'Station'}]
        )

    def test_route_cache_schema_and_version_are_extension_owned(self):
        extension = str(Path(os.environ['GTFS_EXTENSION']).resolve()).replace("'", "''")
        sql = "PRAGMA gtfs_prepare_route_cache; INSERT INTO RouteShapeMacroVersion VALUES ('old'); PRAGMA gtfs_reset_route_cache; SELECT count(*) AS n FROM RouteShapeMacroVersion;"
        args = [os.environ['DUCKDB_BIN'], '-unsigned', '-json', '-cmd', f"LOAD '{extension}'", ':memory:', '-c']
        result = subprocess.run(args + [sql], capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(result.stdout), [{'n': 0}])
        result = subprocess.run(args + ['PRAGMA gtfs_route_cache_version'], capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertRegex(json.loads(result.stdout)[0]['version'], r'^[a-f0-9]{64}$')
