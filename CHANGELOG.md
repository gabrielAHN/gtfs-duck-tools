# Changelog

## 1.0.0

First release of the GTFS DuckDB Extension (`gtfs`).

- GTFS functions registered at `LOAD` (65 macros), with explicit `gtfs_prepare`, `gtfs_init` and `gtfs_refresh` lifecycle pragmas.
- Raw-file normalization, geometry, pathway shortest paths, trip editing and route-shape lane geometry used by GTFS Viz.
- Native builds against DuckDB v1.5.4 (Linux, macOS, Windows) and browser builds against DuckDB-WASM v1.4.3 (EH, MVP).
- GitHub Actions builds, tests and stages an unsigned development repository; signed distribution is through DuckDB community extensions.
