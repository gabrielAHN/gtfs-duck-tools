# Changelog

## 1.0.0

First release of GTFS DuckDB, the `gtfs` DuckDB extension.

- GTFS functions registered at `LOAD` (89 functions), with explicit `gtfs_prepare`, `gtfs_init` and `gtfs_refresh` lifecycle pragmas.
- `PRAGMA gtfs_import(directory)` imports a whole GTFS folder in one call; GTFS Viz uses it for both the web app and the CLI.
- Raw-file normalization, geometry, pathway shortest paths, trip editing and route-shape lane geometry used by GTFS Viz.
- Native builds against DuckDB v1.5.4 (Linux, macOS, Windows) and browser builds against DuckDB-WASM v1.4.3 (EH, MVP).
- GitHub Actions builds, tests and stages an unsigned development repository; signed distribution is through DuckDB community extensions.
