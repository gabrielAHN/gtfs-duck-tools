# GTFS Duck Tools

DuckDB extension for GTFS data functions, extracted incrementally from GTFS Viz.

**Status: local native/WASM extension, not a published community extension.** All 65 macros from the existing GTFS SQL header are now embedded and registered by the extension, including analysis, pathfinding, trip editing and route-geometry calculations. Explicit dataset preparation, initialization and refresh are exposed as pragmas. Raw-file ingestion remains in the consumers. Opt-in web/CLI download adapters and the independent rendering library are prepared in the companion GTFS Viz change; signed distribution and complete cutover are still pending. No rendering or npm runtime is included.

## Layout

- `sql/{load,init,reroute}.sql`: authoritative SQL, extracted without changes from the existing GTFS SQL header.
- `src/gtfs_duck_tools_extension.cpp`: registers parsed macros in DuckDB's system catalog.
- `src/include/gtfs_sql.hpp.in`: build-time SQL embedding.
- `test/test_native.py`: tests a real loadable artifact using a separate DuckDB CLI, including HTTP download and a clean cache.
- `test/test_lifecycle.py`: normalized fixture, explicit initialization, after-midnight times, and refresh preserving pending edits.
- `test/test_parity.py`: optional comparisons against the original SQL header, including spatial route-band results.
- `test/sql/gtfs_duck_tools.test`: SQLLogicTests for template CI.

Loading the extension registers functions only: it does not create GTFS tables, edit tables, or materialized data.

## Dataset lifecycle

Execute `LOAD` as its own query. Then use `PRAGMA gtfs_prepare` before importing normalized source tables, `PRAGMA gtfs_init` after import, and `PRAGMA gtfs_refresh` after edits. Refresh preserves pending edits; route-shape cache population remains explicit. Spatial geometry queries additionally require the separate `spatial` extension. See `docs/sql-migration-verdict.md` for the exact scope and parity-test reproduction.

## Toolchain

Based on the user-selected DuckDB extension template, revision `cfaf3e236008e782d27f4341b0ee036002d0a449`. Submodules are pinned to its DuckDB 1.5.4 and extension-ci-tools revisions. The example OpenSSL dependency and sample functions have been removed.

The template's regular build/test flow is `GEN=ninja make` followed by `make test`. These full-build/SQLLogicTest commands have not yet been run for this prototype. Its retained distribution workflow is likewise not yet exercised in GitHub Actions.

### Verified fast native build (macOS arm64)

Requires CMake, Ninja, a C++ compiler, initialized submodules, and a separate DuckDB **1.5.4** CLI for testing. This dynamic-link fast build is a development convenience, not the cross-platform distribution recipe.

```sh
git submodule update --init --recursive
cmake -G Ninja -S duckdb -B build/release \
  -DCMAKE_BUILD_TYPE=Release \
  -DDUCKDB_EXTENSION_CONFIGS="$PWD/extension_config.cmake" \
  -DEXTENSION_STATIC_BUILD=0 \
  -DOVERRIDE_GIT_DESCRIBE=v1.5.4 \
  -DBUILD_UNITTESTS=OFF -DBUILD_SHELL=OFF \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5
cmake --build build/release --target gtfs_duck_tools_loadable_extension -j 4
DUCKDB_BIN=/absolute/path/to/duckdb-1.5.4 \
GTFS_EXTENSION="$PWD/build/release/extension/gtfs_duck_tools/gtfs_duck_tools.duckdb_extension" \
python3 -m unittest discover -s test -p 'test_*.py' -v
```

Use a separate build directory for a future full build, or reconfigure the disabled shell/unittest options before `make test`.

### Development query

Start the matching CLI with `-unsigned` **only for this local unsigned prototype**, then run:

```sql
LOAD '/absolute/path/to/gtfs_duck_tools.duckdb_extension';
SELECT route_type_to_name(3);
```

The native test suite also serves the binary as a gzipped artifact over a temporary loopback HTTP repository and verifies that `INSTALL gtfs_duck_tools FROM ...; LOAD gtfs_duck_tools;` downloads and executes it from a fresh cache. It does not use or publish to the community repository.

## Verified / outstanding

Native tests: **27 passed** on macOS arm64 with the standalone DuckDB 1.5.4 CLI, with the migration-parity environment configured. Covers the previous download/security regressions, lifecycle behavior, all 65 registered macro names, unchanged extracted SQL, and 14 nonempty result comparisons with the original implementation. The parity suite is skipped unless `GTFS_LEGACY_HEADER` is set; see `docs/sql-migration-verdict.md` for reproduction and scope.

WASM builds now load successfully in a real Chromium browser using the existing GTFS Viz package (`@duckdb/duckdb-wasm` 1.32.0, embedded engine **1.4.3**). Both `wasm_eh` and `wasm_mvp` download their actual artifacts from a separate loopback origin, with CORS enabled. Each passes all 65 macro registrations, explicit preparation/initialization/refresh, fixture availability, recursive shortest-path results, after-midnight times, pending-edit preservation, route-type results, no tables on LOAD, preserved user data, and access from a new connection. These positive tests explicitly enable unsigned extensions only in the development harness.

**The full browser release gate still fails:** EH rejects the unsigned artifact with the expected signature error; MVP throws `_setThrew is not defined`. The same MVP error reproduces with `SELECT error('gtfs_baseline_probe')` before installing or loading any extension, isolating it to the existing runtime/test integration rather than the extension's SQL. The underlying runtime defect is not fixed. Do not claim signature-handling validation for MVP or enable unsigned extensions in the production app.

Native and WASM binaries target different engine versions (native 1.5.4, WASM 1.4.3). The older system DuckDB CLI (1.2.0) is incompatible with the native artifact; use a matching 1.5.4 CLI. Companion native/browser adapter and built-dashboard development tests pass with isolated unsigned artifacts. Cross-platform CI and signed positive consumer tests remain unverified.

### Reproduce WASM verification

Provision Emscripten **3.1.71** using emsdk, and a separate DuckDB **v1.4.3** source checkout (commit `d1dc88f950d456d72493df452dabdcd13aa413dd`). Do not repin the native submodule merely to run this compatibility probe.

```sh
EMSDK=/absolute/path/to/emsdk \
DUCKDB_WASM_SOURCE=/absolute/path/to/duckdb-v1.4.3 \
bash scripts/build-wasm.sh

GTFS_VIZ_ROOT=/absolute/path/to/gtfs-viz node test/test_wasm.mjs --unsigned-only
GTFS_VIZ_ROOT=/absolute/path/to/gtfs-viz node test/test_wasm.mjs
GTFS_VIZ_ROOT=/absolute/path/to/gtfs-viz node test/test_wasm.mjs --baseline-errors
```

The harness reuses the sibling application's installed Playwright, esbuild, and DuckDB-WASM dependencies; it does not bundle them into the extension. A Playwright Chromium installation is required. The unsigned-only smoke passes; the default strict suite and baseline-errors probe deliberately remain red on the MVP runtime issue. They are not skipped or relabeled as passing.

Build/test logs are under `build/wasm-build.log`, `build/wasm-unsigned-test.log`, `build/wasm-full-test.log`, `build/wasm-baseline-errors.log`, and `build/native-test.log`. See `docs/wasm-prototype-verdict.md` for scope and artifact checksums.

Next: resolve MVP error handling or explicitly narrow supported browser bundles, support selective-import initialization, exercise release CI, and seek signed community distribution. Do not advertise `INSTALL ... FROM community` as available before acceptance.
