

CREATE OR REPLACE MACRO gtfs_time_to_seconds(t) AS (
  CASE WHEN NULLIF(CAST(t AS VARCHAR), '') IS NULL THEN NULL
    ELSE COALESCE(TRY_CAST(SPLIT_PART(CAST(t AS VARCHAR), ':', 1) AS BIGINT), 0) * 3600
       + COALESCE(TRY_CAST(SPLIT_PART(CAST(t AS VARCHAR), ':', 2) AS BIGINT), 0) * 60
       + COALESCE(TRY_CAST(SPLIT_PART(CAST(t AS VARCHAR), ':', 3) AS BIGINT), 0)
  END
);

CREATE OR REPLACE MACRO seconds_to_gtfs_time(s) AS (
  CASE WHEN s IS NULL THEN NULL
    ELSE lpad(CAST(CAST(s AS BIGINT) // 3600 AS VARCHAR), 2, '0') || ':' ||
         lpad(CAST((CAST(s AS BIGINT) % 3600) // 60 AS VARCHAR), 2, '0') || ':' ||
         lpad(CAST(CAST(s AS BIGINT) % 60 AS VARCHAR), 2, '0')
  END
);

CREATE OR REPLACE MACRO get_trip_reroute_routes(p_trip_id) AS TABLE (
  WITH affected_trip AS MATERIALIZED (
    SELECT route_id
    FROM TripsView
    WHERE trip_id = p_trip_id
    LIMIT 1
  ),
  affected_stops AS MATERIALIZED (
    SELECT ROW_NUMBER() OVER (ORDER BY st.stop_sequence) AS affected_position,
           st.stop_id, sv.stop_name AS station_name
    FROM StopTimesView st
    JOIN StopsView sv ON sv.stop_id = st.stop_id
    WHERE st.trip_id = p_trip_id
      AND sv.stop_name IS NOT NULL
  ),
  affected_pattern AS MATERIALIZED (
    SELECT LIST(stop_id ORDER BY affected_position) AS stop_ids
    FROM affected_stops
  ),
  donor_representatives AS MATERIALIZED (
    SELECT t.route_id, t.direction_id,
           COALESCE(NULLIF(t.shape_id, ''), 'headsign:' || COALESCE(t.trip_headsign, '')) AS pattern_id,
           MIN(t.trip_id) AS donor_trip_id
    FROM TripsView t
    CROSS JOIN affected_trip
    WHERE t.trip_id != p_trip_id
      AND t.route_id != affected_trip.route_id
    GROUP BY t.route_id, t.direction_id,
             COALESCE(NULLIF(t.shape_id, ''), 'headsign:' || COALESCE(t.trip_headsign, ''))
  ),
  donor_stop_rows AS MATERIALIZED (
    SELECT edits.trip_id, edits.stop_sequence, edits.stop_id
    FROM donor_representatives representatives
    JOIN EditStopTimesTable edits ON edits.trip_id = representatives.donor_trip_id
    WHERE edits.status IN ('new', 'edit', 'new edit')
    UNION ALL
    SELECT st.trip_id, st.stop_sequence, st.stop_id
    FROM donor_representatives representatives
    JOIN stop_times st ON st.trip_id = representatives.donor_trip_id
    WHERE NOT EXISTS (
      SELECT 1
      FROM EditStopTimesTable edits
      WHERE edits.row_id = CAST(st.row_id AS TEXT)
        AND edits.status IN ('deleted', 'edit')
    )
      AND NOT EXISTS (
        SELECT 1
        FROM EditStopTimesTable edits
        WHERE edits.trip_id = st.trip_id
          AND edits.status = 'new edit'
      )
  ),
  donor_stops AS MATERIALIZED (
    SELECT representatives.route_id, representatives.donor_trip_id,
           ROW_NUMBER() OVER (
             PARTITION BY representatives.donor_trip_id
             ORDER BY st.stop_sequence
           ) AS donor_position,
           st.stop_id, sv.stop_name AS station_name
    FROM donor_representatives representatives
    JOIN donor_stop_rows st ON st.trip_id = representatives.donor_trip_id
    JOIN StopsView sv ON sv.stop_id = st.stop_id
    WHERE sv.stop_name IS NOT NULL
  ),
  donor_patterns AS MATERIALIZED (
    SELECT route_id, donor_trip_id,
           LIST(stop_id ORDER BY donor_position) AS stop_ids
    FROM donor_stops
    GROUP BY route_id, donor_trip_id
  ),
  shared_stations AS MATERIALIZED (
    SELECT donors.route_id, donors.donor_trip_id,
           affected.station_name,
           affected.affected_position,
           donors.donor_position
    FROM donor_stops donors
    JOIN affected_stops affected ON affected.station_name = donors.station_name
  ),
  candidate_stats AS MATERIALIZED (
    SELECT route_id, donor_trip_id,
           COUNT(DISTINCT station_name) AS shared_station_count
    FROM shared_stations
    GROUP BY route_id, donor_trip_id
    HAVING COUNT(DISTINCT station_name) >= 2
  ),
  pattern_pairs AS MATERIALIZED (
    SELECT candidates.route_id, candidates.donor_trip_id,
           candidates.shared_station_count,
           starts.affected_position AS affected_from_position,
           ends.affected_position AS affected_to_position,
           starts.donor_position AS donor_from_position,
           ends.donor_position AS donor_to_position
    FROM candidate_stats candidates
    JOIN shared_stations starts USING (route_id, donor_trip_id)
    JOIN shared_stations ends USING (route_id, donor_trip_id)
    WHERE ends.affected_position > starts.affected_position
      AND ends.donor_position > starts.donor_position
  ),
  changed_candidates AS MATERIALIZED (
    SELECT DISTINCT pairs.route_id, pairs.donor_trip_id,
           pairs.shared_station_count
    FROM pattern_pairs pairs
    JOIN donor_patterns donor USING (route_id, donor_trip_id)
    CROSS JOIN affected_pattern affected
    WHERE LIST_SLICE(
            affected.stop_ids,
            pairs.affected_from_position + 1,
            pairs.affected_to_position - 1
          ) <> LIST_SLICE(
            donor.stop_ids,
            pairs.donor_from_position + 1,
            pairs.donor_to_position - 1
          )
  ),
  ranked AS (
    SELECT *, ROW_NUMBER() OVER (
      PARTITION BY route_id
      ORDER BY shared_station_count DESC, donor_trip_id
    ) AS route_rank
    FROM changed_candidates
  )
  SELECT r.route_id, r.route_name, r.route_short_name, r.route_type_name,
         r.route_color_hex, ranked.donor_trip_id, ranked.shared_station_count
  FROM ranked
  JOIN RoutesView r ON r.route_id = ranked.route_id
  WHERE ranked.route_rank = 1
  ORDER BY r.route_sort_order NULLS LAST, r.route_name, r.route_id
);

CREATE OR REPLACE MACRO get_trip_reroute_boundary_pairs(p_trip_id, p_donor_trip_id) AS TABLE (
  WITH affected_stops AS MATERIALIZED (
    SELECT st.stop_sequence AS affected_sequence,
           ROW_NUMBER() OVER (ORDER BY st.stop_sequence) AS affected_position,
           st.stop_id, sv.stop_name AS station_name
    FROM StopTimesView st
    JOIN StopsView sv ON sv.stop_id = st.stop_id
    WHERE st.trip_id = p_trip_id
      AND sv.stop_name IS NOT NULL
  ),
  donor_stops AS MATERIALIZED (
    SELECT st.stop_sequence AS donor_sequence,
           ROW_NUMBER() OVER (ORDER BY st.stop_sequence) AS donor_position,
           st.stop_id, sv.stop_name AS station_name
    FROM StopTimesView st
    JOIN StopsView sv ON sv.stop_id = st.stop_id
    WHERE st.trip_id = p_donor_trip_id
      AND sv.stop_name IS NOT NULL
  ),
  affected AS MATERIALIZED (
    SELECT station_name, MIN(affected_sequence) AS affected_sequence,
           MIN(affected_position) AS affected_position
    FROM affected_stops
    GROUP BY station_name
  ),
  donor AS MATERIALIZED (
    SELECT station_name, MIN(donor_sequence) AS donor_sequence,
           MIN(donor_position) AS donor_position
    FROM donor_stops
    GROUP BY station_name
  ),
  affected_pattern AS MATERIALIZED (
    SELECT LIST(stop_id ORDER BY affected_position) AS stop_ids
    FROM affected_stops
  ),
  donor_pattern AS MATERIALIZED (
    SELECT LIST(stop_id ORDER BY donor_position) AS stop_ids
    FROM donor_stops
  ),
  shared AS MATERIALIZED (
    SELECT affected.station_name, affected.affected_sequence, affected.affected_position,
           donor.donor_sequence, donor.donor_position
    FROM affected
    JOIN donor USING (station_name)
  ),
  pairs AS (
    SELECT start_station.station_name AS from_station,
           end_station.station_name AS to_station,
           start_station.affected_sequence AS affected_from_sequence,
           end_station.affected_sequence AS affected_to_sequence,
           start_station.donor_sequence AS donor_from_sequence,
           end_station.donor_sequence AS donor_to_sequence,
           start_station.affected_position AS affected_from_position,
           end_station.affected_position AS affected_to_position,
           start_station.donor_position AS donor_from_position,
           end_station.donor_position AS donor_to_position
    FROM shared start_station
    JOIN shared end_station
      ON end_station.affected_position > start_station.affected_position
     AND end_station.donor_position > start_station.donor_position
  )
  SELECT from_station, to_station,
         affected_from_sequence, affected_to_sequence,
         donor_from_sequence, donor_to_sequence
  FROM pairs
  CROSS JOIN affected_pattern
  CROSS JOIN donor_pattern
  WHERE LIST_SLICE(
          affected_pattern.stop_ids,
          pairs.affected_from_position + 1,
          pairs.affected_to_position - 1
        ) <> LIST_SLICE(
          donor_pattern.stop_ids,
          pairs.donor_from_position + 1,
          pairs.donor_to_position - 1
        )
  ORDER BY affected_from_sequence, affected_to_sequence
);

-- Reroute p_trip_id via p_donor_trip_id between the two shared boundary stops (by stop name).
-- Pick a donor trip in the SAME direction as the affected trip. Returns the merged stop list:
-- affected stops up to the first boundary + donor stops between (donor stop_ids, donor timing
-- scaled into the affected trip's boundary window) + affected stops from the second boundary on.
CREATE OR REPLACE MACRO get_reroute_stop_times(p_trip_id, p_donor_trip_id, p_from_name, p_to_name) AS TABLE (
  WITH aff AS (
    SELECT st.stop_sequence AS seq, st.stop_id, s.stop_name, st.arrival_time, st.departure_time,
           gtfs_time_to_seconds(st.arrival_time) AS arr, gtfs_time_to_seconds(st.departure_time) AS dep
    FROM StopTimesView st JOIN StopsView s ON s.stop_id = st.stop_id
    WHERE st.trip_id = p_trip_id
  ),
  don AS (
    SELECT st.stop_sequence AS seq, st.stop_id, s.stop_name,
           gtfs_time_to_seconds(st.arrival_time) AS arr, gtfs_time_to_seconds(st.departure_time) AS dep
    FROM StopTimesView st JOIN StopsView s ON s.stop_id = st.stop_id
    WHERE st.trip_id = p_donor_trip_id
  ),
  b AS (
    SELECT
      (SELECT seq FROM aff WHERE stop_name = p_from_name ORDER BY seq LIMIT 1) AS a1,
      (SELECT seq FROM aff WHERE stop_name = p_to_name   ORDER BY seq LIMIT 1) AS a2,
      (SELECT seq FROM don WHERE stop_name = p_from_name ORDER BY seq LIMIT 1) AS d1,
      (SELECT seq FROM don WHERE stop_name = p_to_name   ORDER BY seq LIMIT 1) AS d2
  ),
  -- Normalize boundary order so --from/--to work regardless of the trip's direction
  -- (northbound trips have the "from" stop at a higher stop_sequence than the "to" stop).
  bounds AS (
    SELECT LEAST(a1, a2) AS a_lo, GREATEST(a1, a2) AS a_hi,
           LEAST(d1, d2) AS d_lo, GREATEST(d1, d2) AS d_hi
    FROM b
  ),
  anchors AS (
    SELECT bd.a_lo, bd.a_hi, bd.d_lo, bd.d_hi,
      (SELECT dep FROM aff WHERE seq = bd.a_lo) AS a_lo_dep,
      (SELECT arr FROM aff WHERE seq = bd.a_hi) AS a_hi_arr,
      (SELECT dep FROM don WHERE seq = bd.d_lo) AS d_lo_dep,
      (SELECT arr FROM don WHERE seq = bd.d_hi) AS d_hi_arr
    FROM bounds bd
  ),
  k AS (
    SELECT *,
      CASE WHEN (d_hi_arr - d_lo_dep) > 0
           THEN (a_hi_arr - a_lo_dep)::DOUBLE / (d_hi_arr - d_lo_dep) ELSE 1 END AS scale
    FROM anchors
  ),
  parts AS (
    SELECT 0 AS part, aff.seq AS ord, aff.stop_id, aff.arrival_time, aff.departure_time
    FROM aff, k WHERE aff.seq <= k.a_lo
    UNION ALL
    SELECT 1 AS part, don.seq AS ord, don.stop_id,
      seconds_to_gtfs_time(CAST(round(k.a_lo_dep + (don.arr - k.d_lo_dep) * k.scale) AS BIGINT)),
      seconds_to_gtfs_time(CAST(round(k.a_lo_dep + (don.dep - k.d_lo_dep) * k.scale) AS BIGINT))
    FROM don, k WHERE don.seq > k.d_lo AND don.seq < k.d_hi
    UNION ALL
    SELECT 2 AS part, aff.seq AS ord, aff.stop_id, aff.arrival_time, aff.departure_time
    FROM aff, k WHERE aff.seq >= k.a_hi
  )
  SELECT row_number() OVER (ORDER BY part, ord) AS stop_sequence, stop_id, arrival_time, departure_time
  FROM parts
);

-- Unified stop selection for a trip: keep the stops in [p_first_name .. p_last_name] (inclusive;
-- NULL/'' = open end) minus any whose name is in p_remove_names (pass [] to remove none). This is the
-- single code path behind remove_stops (skip/express, bypass = full range, remove names),
-- truncate_trip (short-turn = remove nothing, restrict range), and each half of split_trip.
CREATE OR REPLACE MACRO get_trip_stops(p_trip_id, p_remove_names, p_first_name, p_last_name) AS TABLE (
  WITH t AS (
    SELECT st.stop_sequence AS seq, st.stop_id, s.stop_name, st.arrival_time, st.departure_time
    FROM stop_times st JOIN StopsView s ON s.stop_id = st.stop_id
    WHERE st.trip_id = p_trip_id
  ),
  bounds AS (
    SELECT
      COALESCE((SELECT MIN(seq) FROM t WHERE p_first_name IS NOT NULL AND p_first_name <> '' AND stop_name = p_first_name),
               (SELECT MIN(seq) FROM t)) AS lo,
      COALESCE((SELECT MIN(seq) FROM t WHERE p_last_name IS NOT NULL AND p_last_name <> '' AND stop_name = p_last_name),
               (SELECT MAX(seq) FROM t)) AS hi
  )
  SELECT row_number() OVER (ORDER BY t.seq) AS stop_sequence, t.stop_id, t.arrival_time, t.departure_time
  FROM t, bounds
  WHERE t.seq >= bounds.lo AND t.seq <= bounds.hi
    AND NOT list_contains(p_remove_names, t.stop_name)
);
