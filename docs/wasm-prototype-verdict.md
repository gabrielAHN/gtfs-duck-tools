# WASM prototype verdict: PARTIAL

Historical one-helper snapshot. The artifacts below have since been rebuilt with all 65 macros; see `sql-migration-verdict.md` for the current verification scope. These checksums describe the earlier prototype, not the current build.

Date: September 27, 2026.

## Proven

Built the unchanged C++/SQL extension against DuckDB v1.4.3 (`d1dc88f950d456d72493df452dabdcd13aa413dd`) using Emscripten 3.1.71 and the template's WASM flags. Native submodule stays pinned to v1.5.4.

Ran real Chromium 147.0.7727.15 with GTFS Viz's installed DuckDB-WASM package 1.32.0. Both EH and MVP successfully fetched and loaded their own `.wasm` artifacts through a cross-origin loopback repository and returned the existing GTFS route-type labels, including NULL and unknown values. No user tables were created by LOAD; repeated LOAD preserved a user table; a new database connection could call the registered macro.

Observed repository request layout for this custom repository:

```
/v1.4.3/wasm_eh/gtfs_duck_tools.duckdb_extension.wasm
/v1.4.3/wasm_mvp/gtfs_duck_tools.duckdb_extension.wasm
```

This is a real browser download, not a mocked network response. It is not yet integration into the GTFS Viz application. Unsigned loading is enabled only in isolated positive tests.

## Gate results

| Gate | Result |
|---|---|
| Reproducible build script, both variants | Exit 0 |
| Browser unsigned development smoke | 2 cases pass |
| EH default signature rejection | Expected signature error |
| MVP default signature rejection | Unexpected `_setThrew is not defined` |
| Default full browser suite | Exit 1; intentionally not waived |
| Baseline SQL-error probe, no extension loaded | EH returns expected error; MVP produces the same `_setThrew` error |
| Native regressions after WASM work | 7 pass |

The baseline reproduction rules out our extension as a prerequisite for the MVP error. It does not yet identify the precise upstream build/exception-handling defect. Do not patch vendor workers or disable signature checks as a workaround. Investigate a supported runtime update or explicitly reduce the supported bundle matrix before release.

## Artifacts

| Path | Bytes | SHA-256 |
|---|---:|---|
| `build/wasm_eh/extension/gtfs_duck_tools/gtfs_duck_tools.duckdb_extension.wasm` | 4175 | `abf251e21df79fdd8a0dc52ce003a6a29ecf3505e5063fc7d9835a4067c49d00` |
| `build/wasm_mvp/extension/gtfs_duck_tools/gtfs_duck_tools.duckdb_extension.wasm` | 3287 | `78686e87ab0860dccacb8c40ba0cc662ba083d1caddc8071ecf1d6da535caa13` |

The small artifacts include only one SQL helper and extension registration, not the remaining GTFS database code or the DuckDB engine.

## Scope still outstanding

- Resolve the strict MVP error-handling gate.
- Test supported browsers beyond Chromium and real deployment HTTPS/CSP configuration.
- Migrate all GTFS SQL, define explicit initialization/refresh, and test parity.
- Integrate actual web and CLI clients and extract the rendering library.
- Publish the intended public repository and obtain signed community artifacts.

All changes are local and uncommitted. GTFS Viz tracked source is unchanged. Test servers close automatically; no service remains running from this harness.
