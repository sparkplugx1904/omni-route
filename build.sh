#!/usr/bin/env bash
# Build script for Route Planner C++ (Linux/Mac)
# Usage:
#   ./build.sh        -> native CLI (build/route_planner)
#   ./build.sh wasm   -> WebAssembly for the web app (public/wasm/)
set -e

echo "============================================"
echo "Route Planner - C++ Build Script"
echo "============================================"
echo ""

if ! command -v cmake &> /dev/null; then
    echo "Error: CMake not found. Please install CMake first."
    echo "  Ubuntu/Debian: sudo apt install cmake build-essential"
    echo "  MacOS: brew install cmake"
    exit 1
fi

build_wasm() {
    # Requires: Emscripten SDK available in PATH or $EMSDK
    EMSDK_ROOT="${EMSDK:-$HOME/emsdk}"
    if command -v emcc >/dev/null 2>&1; then
        : # already in PATH
    elif [ -f "$EMSDK_ROOT/emsdk_env.sh" ]; then
        # shellcheck source=/dev/null
        source "$EMSDK_ROOT/emsdk_env.sh" >/dev/null 2>&1
    else
        echo "Error: Emscripten not found. Set EMSDK or add emcc to PATH."
        exit 1
    fi

    echo "[1/2] Configuring WASM build with CMake (Emscripten)..."
    emcmake cmake -S . -B .build-wasm -DCMAKE_BUILD_TYPE=Release

    echo "[2/2] Building WASM module..."
    cmake --build .build-wasm --parallel

    echo ""
    echo "Complete! WASM artifacts copied to public/wasm/ - run 'npm run dev' to try."
    exit 0
}

if [ "${1:-}" = "wasm" ]; then
    build_wasm
fi

# Native CLI build
mkdir -p build
cd build

echo "[1/3] Configuring with CMake..."
cmake .. -DCMAKE_BUILD_TYPE=Release

echo ""
echo "[2/3] Building project..."
cmake --build . -j$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 4)

echo ""
echo "[3/3] Build complete!"
echo ""
echo "Executable location: build/route_planner"
echo ""
echo "To run:"
echo "  ./build/route_planner --csv samples/location.csv --start-name \"Kantor\" --start-lat -8.65 --start-lon 115.23 --teams 14"
echo ""
