#!/usr/bin/env bash
set -euo pipefail
: "${EMSDK:?Set EMSDK to the Emscripten 3.1.71 SDK directory}"
: "${DUCKDB_WASM_SOURCE:?Set DUCKDB_WASM_SOURCE to a DuckDB v1.4.3 checkout}"
root="$(cd "$(dirname "$0")/.." && pwd)"
expected=d1dc88f950d456d72493df452dabdcd13aa413dd
actual="$(git -C "$DUCKDB_WASM_SOURCE" rev-parse HEAD)"
if [[ "$actual" != "$expected" ]]; then
  printf 'Expected DuckDB v1.4.3 source %s, got %s\n' "$expected" "$actual" >&2
  exit 1
fi
source "$EMSDK/emsdk_env.sh"
if ! emcc --version | python3 -c 'import sys; sys.exit(0 if "3.1.71" in sys.stdin.read() else 1)'; then
  printf 'Emscripten 3.1.71 is required for this compatibility probe\n' >&2
  exit 1
fi
for variant in eh mvp; do
  flags=""
  if [[ "$variant" == eh ]]; then
    flags="-fwasm-exceptions -DWEBDB_FAST_EXCEPTIONS=1"
  fi
  emcmake cmake -G Ninja -S "$DUCKDB_WASM_SOURCE" -B "$root/build/wasm_$variant" \
    -DDUCKDB_EXTENSION_CONFIGS="$root/extension_config.cmake" \
    -DWASM_LOADABLE_EXTENSIONS=1 -DBUILD_EXTENSIONS_ONLY=1 \
    -DEXTENSION_STATIC_BUILD=0 -DOVERRIDE_GIT_DESCRIBE=v1.4.3 \
    -DDUCKDB_EXPLICIT_PLATFORM="wasm_$variant" -DDUCKDB_CUSTOM_PLATFORM="wasm_$variant" \
    -DCMAKE_CXX_FLAGS="$flags" -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_POLICY_VERSION_MINIMUM=3.5
  cmake --build "$root/build/wasm_$variant" --target gtfs_duck_tools_loadable_extension -j 4
done
