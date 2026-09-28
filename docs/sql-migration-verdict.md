# SQL migration verdict

Date: September 27, 2026.

## Implemented

All 65 macros from GTFS Viz's `packages/duckdb-extension/src/include/gtfs_sql.hpp` are embedded in the loadable extension. The extracted SQL blocks in `sql/load.sql`, `sql/init.sql`, and `sql/reroute.sql` are unchanged. Registration uses DuckDB's system catalog, including macros whose source tables do not exist yet.

`LOAD` registers functions only; it does not initialize datasets or reset pending edits.

The explicit lifecycle is:

```sql
LOAD 'path/to/gtfs_duck_tools.duckdb_extension';
```

Execute LOAD as its own query before calling extension pragmas. DuckDB may resolve pragmas before executing earlier statements in the same batch.

```sql
PRAGMA gtfs_prepare;
```

This creates missing edit tables without requiring a source dataset. Import the normalized source tables next: `stops`, `pathways`, `routes`, `trips`, `stop_times`, `shapes`, `calendar`, and `calendar_dates`.

```sql
PRAGMA gtfs_init;
```

This prepares edit tables and runs the original non-macro initialization statements: views, materialized tables, indexes, and empty route-band caches. It requires the normalized source-table contract illustrated in `test/fixtures/normalized.sql`. It is not a raw-GTFS importer.

```sql
PRAGMA gtfs_refresh;
```

This repeats the same materialization lifecycle after edits while preserving pending edit rows and original source data. Route-shape cache population remains explicit through the existing route-lane/band functions; this pragma does not automatically repopulate those caches.

Spatial route-geometry queries require the separate `spatial` extension to be installed and loaded. No automatic installation is performed by this extension.

## Verified

- Native DuckDB 1.5.4 / macOS arm64: **27 tests passed**.
- The suite includes all 65 macro names in the system catalog and exact extracted-SQL parity with the original header.
- Fourteen nonempty fixture result comparisons match the original SQL execution, including stations, stops, routes, trips, calendars, shortest paths, trip bounds, trimmed trip stops, and spatial route-band coordinates.
- Explicit prepare/init/refresh works; repeated refresh preserves pending edits and original source data.
- Native HTTP download/install, default unsigned rejection, no tables on LOAD, and repeated LOAD regressions pass.
- Chromium 147 / DuckDB-WASM 1.4.3: **EH and MVP development lifecycle tests pass**, each downloading its own real artifact from a separate loopback origin.
- Both browser bundles register all 65 macros, initialize the normalized fixture, find `E -> P -> Q`, round-trip `25:01:02`, and preserve a pending station rename through repeated refresh.
- No GTFS Viz tracked source was changed. No repository or release was published.

This does not prove every branch of every macro. The fixture is deliberately small; existing large-data/performance and application-rendering regressions remain separate gates.

## Reproduce native migration parity

First install a matching native `spatial` extension into your chosen dependency cache. Then:

```sh
cmake --build build/release --target gtfs_duck_tools_loadable_extension -j 4
DUCKDB_BIN=/absolute/path/to/duckdb-1.5.4 \
GTFS_EXTENSION="$PWD/build/release/extension/gtfs_duck_tools/gtfs_duck_tools.duckdb_extension" \
GTFS_DEPENDENCY_CACHE=/absolute/path/to/extension-cache \
GTFS_LEGACY_HEADER=/absolute/path/to/gtfs-viz/packages/duckdb-extension/src/include/gtfs_sql.hpp \
python3 -m unittest discover -s test -p 'test_*.py' -v
```

Without `GTFS_LEGACY_HEADER`, the 16 migration-parity checks are skipped and the 11 standalone tests remain. Browser reproduction is in the README.

## Compatibility findings

DuckDB 1.4.3 cannot serialize all CREATE TABLE statements with `SQLStatement::ToString()` (`FIXME: column definition to string`). Lifecycle extraction uses each parsed statement's `query` text instead. The parser resets statement offsets to zero after assigning per-statement query text, so slicing the original input with those offsets is incorrect. Both native and WASM builds verify the chosen approach.

Browser cases have bounded timeouts. HTTP test servers close active connections during teardown to avoid a passing suite waiting indefinitely on keep-alive connections.

## Still blocking release

The strict browser suite still exits 1: EH reports the expected unsigned-signature rejection; MVP reports `_setThrew is not defined`. Earlier baseline tests reproduced that MVP error before any extension was loaded. This remains unresolved; unsigned loading is limited to isolated development tests.

Other remaining work: normalized/raw ingestion boundary, web/CLI downloaded-extension integration, rendering-library extraction, runtime-version policy, cross-platform release CI, public repository creation, and signed distribution/community submission.

Logs: `build/native-test.log`, `build/wasm-build.log`, `build/wasm-unsigned-test.log`, and `build/wasm-full-test.log`.
