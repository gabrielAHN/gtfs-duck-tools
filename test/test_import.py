import os
import subprocess
import tempfile
import unittest
from pathlib import Path
import test_native

FEED = {
    "stops.txt": "stop_id,stop_name,stop_lat,stop_lon,location_type,parent_station\nS,Fixture Station,35,139,1,\nP,Fixture Platform,35.001,139,0,S\nB,Fixture Stop,35.01,139.01,0,\n",
    "routes.txt": "route_id,route_short_name,route_long_name,route_type,route_color\nR,R,Fixture Line,1,FF0000\n",
    "trips.txt": "route_id,service_id,trip_id,shape_id\nR,WK,T,SH\n",
    "stop_times.txt": "trip_id,arrival_time,departure_time,stop_id,stop_sequence\nT,08:00:00,08:00:00,P,1\n",
    "shapes.txt": "shape_id,shape_pt_lat,shape_pt_lon,shape_pt_sequence\nSH,35,139,1\nSH,35.001,139,2\n",
    "calendar.txt": "service_id,monday,tuesday,wednesday,thursday,friday,saturday,sunday,start_date,end_date\nWK,1,1,1,1,1,0,0,20260101,20261231\n",
}


class ImportTests(unittest.TestCase):
    query = test_native.NativeExtensionTests.query

    def feed(self, files):
        directory = Path(tempfile.mkdtemp(prefix="gtfs import '"))
        for name, body in files.items():
            (directory / name).write_text(body)
        return str(directory).replace("'", "''")

    def test_import_reads_a_feed_directory_and_initializes(self):
        path = self.feed(FEED)
        rows = self.query(
            f"PRAGMA gtfs_import('{path}'); SELECT stations, stops, routes, trips FROM get_gtfs_data_availability()"
        )
        self.assertEqual(rows, [{"stations": 1, "stops": 1, "routes": 1, "trips": 1}])

    def test_import_creates_empty_tables_for_missing_optional_files(self):
        path = self.feed({"stops.txt": FEED["stops.txt"]})
        rows = self.query(
            f"PRAGMA gtfs_import('{path}'); SELECT (SELECT count(*) FROM pathways) AS pathways, (SELECT count(*) FROM calendar_dates) AS dates, (SELECT count(*) FROM StationsTable) AS stations"
        )
        self.assertEqual(rows, [{"pathways": 0, "dates": 0, "stations": 1}])

    def test_import_keeps_pending_edits_when_reimported(self):
        path = self.feed(FEED)
        rows = self.query(
            f"""PRAGMA gtfs_import('{path}');
            INSERT INTO EditStopTable
              (row_id, stop_id, stop_name, stop_lat, stop_lon, location_type_name, parent_station, level_id, wheelchair_status, status)
            VALUES ('1', 'S', 'Renamed Station', 35.0, 139.0, 'Station', '', '', '🔵', 'edit');
            PRAGMA gtfs_import('{path}');
            SELECT stop_name, (SELECT count(*) FROM EditStopTable) AS pending FROM StationsTable WHERE stop_id='S'"""
        )
        self.assertEqual(rows, [{"stop_name": "Renamed Station", "pending": 1}])

    def test_import_requires_stops(self):
        path = self.feed({"routes.txt": FEED["routes.txt"]})
        extension = os.environ.get("GTFS_EXTENSION")
        commands = ["-cmd", f"LOAD '{Path(extension).resolve()}'"] if extension else []
        result = subprocess.run(
            [
                os.environ.get("DUCKDB_BIN", "duckdb"),
                "-unsigned",
                *commands,
                ":memory:",
                "-c",
                f"PRAGMA gtfs_import('{path}')",
            ],
            capture_output=True,
            text=True,
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("required file", result.stderr)
        self.assertIn("stops.txt", result.stderr)


if __name__ == "__main__":
    unittest.main()
