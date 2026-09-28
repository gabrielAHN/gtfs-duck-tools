import unittest
from pathlib import Path
import test_native

FIXTURE = (Path(__file__).parent / "fixtures" / "normalized.sql").read_text()


class LifecycleTests(unittest.TestCase):
    query = test_native.NativeExtensionTests.query

    def test_refresh_rebuilds_materialized_tables_and_preserves_pending_edits(self):
        rows = self.query(
            FIXTURE
            + """
            PRAGMA gtfs_init;
            INSERT INTO EditStopTable
              (row_id, stop_id, stop_name, stop_lat, stop_lon, location_type_name, parent_station, level_id, wheelchair_status, status)
            VALUES ('1', 'S', 'Renamed Station', 35.0, 139.0, 'Station', '', '', '🔵', 'edit');
            PRAGMA gtfs_refresh;
            PRAGMA gtfs_refresh;
            SELECT stop_name,
              (SELECT count(*) FROM EditStopTable) AS pending,
              (SELECT stop_name FROM stops WHERE stop_id='S') AS source_name
            FROM StationsTable WHERE stop_id='S';
        """
        )
        self.assertEqual(rows, [{"stop_name": "Renamed Station", "pending": 1, "source_name": "Fixture Station"}])

    def test_init_materializes_fixture_and_reports_availability(self):
        rows = self.query(FIXTURE + "PRAGMA gtfs_init; SELECT * FROM get_gtfs_data_availability()")
        self.assertEqual(
            rows,
            [
                {
                    "stations": 1,
                    "stops": 1,
                    "pathways": 2,
                    "routes": 1,
                    "trips": 1,
                    "has_stations": True,
                    "has_stops": True,
                    "has_routes": True,
                    "has_trips": True,
                }
            ],
        )

    def test_prepare_creates_edit_tables_without_source_data(self):
        rows = self.query("PRAGMA gtfs_prepare; SELECT table_name FROM information_schema.tables ORDER BY table_name")
        self.assertEqual(
            [row["table_name"] for row in rows],
            [
                "EditCalendarDatesTable",
                "EditCalendarTable",
                "EditPathwayTable",
                "EditRouteTable",
                "EditStopTable",
                "EditStopTimesTable",
                "EditTripsTable",
            ],
        )

    def test_gtfs_time_round_trip_preserves_after_midnight_hours(self):
        self.assertEqual(
            self.query("SELECT seconds_to_gtfs_time(gtfs_time_to_seconds('25:01:02')) AS time"),
            [{"time": "25:01:02"}],
        )


if __name__ == "__main__":
    unittest.main()
