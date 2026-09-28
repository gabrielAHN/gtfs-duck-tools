# GTFS DuckDB Extension

This repository is based on https://github.com/duckdb/extension-template, check it out if you want to build and ship your own DuckDB extension.

---

`gtfs` adds GTFS transit functions to DuckDB: stop/pathway/route normalization, station and route analysis, pathway shortest paths, trip editing and route-shape lane geometry. It is used by [GTFS Viz](https://github.com/gabrielAHN/gtfs-viz) in the browser (DuckDB-WASM) and in its CLI.

```sql
INSTALL gtfs FROM '<repository>';
LOAD gtfs;
SELECT route_type_to_name(3);  -- Bus
```

`LOAD` only registers functions. Datasets are managed explicitly:

```sql
PRAGMA gtfs_prepare;                 -- create edit tables
-- import stops, pathways, routes, trips, stop_times, shapes, calendar, calendar_dates
PRAGMA gtfs_init;                    -- build views, materialized tables and indexes
PRAGMA gtfs_refresh;                 -- rebuild after edits, keeping pending edits
```

Raw CSV staging tables (`<table>_raw`) are normalized with `PRAGMA gtfs_normalize_<table>`; missing optional files use `PRAGMA gtfs_empty_<table>`. Route-shape caches use `gtfs_prepare_route_cache`, `gtfs_reset_route_cache` and `gtfs_route_cache_version`. Spatial geometry functions need the `spatial` extension loaded. See [docs/functions.md](docs/functions.md) for the full function reference.

The extension is not yet in the DuckDB community repository, so `INSTALL gtfs FROM community` does not work yet. See [Releasing](#releasing).

## Layout

- `sql/*.sql`: function and lifecycle SQL, embedded at build time through `src/include/gtfs_sql.hpp.in`.
- `src/gtfs_extension.cpp`: registers macros in the system catalog and the lifecycle pragmas.
- `test/sql/gtfs.test`: SQLLogicTests run by `make test`.
- `test/test_*.py`, `test/*.mjs`: native, parity, lifecycle, staging and browser tests against built artifacts.
- `community/description.yml`: descriptor for the DuckDB community-extensions repository.

## Building

Builds run locally with the template Makefile. No vcpkg dependencies are required.

```sh
git submodule update --init --recursive
GEN=ninja make            # build/release/duckdb, build/release/extension/gtfs/gtfs.duckdb_extension
make test                 # SQLLogicTests
make format-check         # needs clang-format 11, black 24, cmake-format
```

The main binaries are:

- `build/release/duckdb`: DuckDB shell with the extension linked in.
- `build/release/test/unittest`: DuckDB test runner.
- `build/release/extension/gtfs/gtfs.duckdb_extension`: the loadable binary.

### WASM

GTFS Viz uses DuckDB-WASM with DuckDB v1.4.3, so the browser artifacts are built against a separate v1.4.3 checkout using Emscripten 3.1.71:

```sh
EMSDK=/path/to/emsdk DUCKDB_WASM_SOURCE=/path/to/duckdb-v1.4.3 bash scripts/build-wasm.sh
```

This produces `build/wasm_eh` and `build/wasm_mvp` artifacts.

## Testing

```sh
npm ci && npx playwright install chromium    # browser test dependencies

DUCKDB_BIN=/path/to/duckdb-1.5.4 \
GTFS_EXTENSION="$PWD/build/release/extension/gtfs/gtfs.duckdb_extension" \
GTFS_DEPENDENCY_CACHE=/path/to/extension-cache \
python3 -m unittest discover -s test -p 'test_*.py' -v

npm run test:js
npm run test:wasm:unsigned
npm run test:wasm
```

`GTFS_DEPENDENCY_CACHE` must contain the `spatial` extension for the native engine. Parity tests compare against the test-only reference `test/fixtures/legacy-gtfs_sql.hpp.txt` (provenance in `test/fixtures/legacy-reference.md`).

Unsigned loading (`-unsigned`, `allowUnsignedExtensions`) is enabled only inside these test processes. The strict browser run (`npm run test:wasm`) currently fails on the DuckDB-WASM MVP bundle with `_setThrew is not defined`, which also reproduces without this extension.

To serve locally built artifacts as an extension repository for GTFS Viz development, see [docs/local-extension-repository.md](docs/local-extension-repository.md).

## Releasing

Distribution goes through the [DuckDB community extensions](https://duckdb.org/community_extensions/documentation) repository, whose CI builds and signs every platform, so this repository needs no paid CI:

1. Build and test locally (`make`, `make test`, `make format-check`, the Python and browser suites).
2. Merge to `main` and copy the merged commit SHA into `community/description.yml` (`repo.ref`).
3. Open a pull request to `duckdb/community-extensions` adding `extensions/gtfs/description.yml`.

After it is merged, `INSTALL gtfs FROM community; LOAD gtfs;` works with default signature checks. The template workflow in `.github/workflows/MainDistributionPipeline.yml` is kept for manual runs only (`workflow_dispatch`); it does not run on push or pull requests.

## Updating DuckDB

See [docs/UPDATING.md](docs/UPDATING.md).
