@echo off
REM Build script for Route Planner C++ (Windows)
REM Usage:
REM   build.bat          -> native CLI (build\Release\route_planner.exe)
REM   build.bat wasm     -> WebAssembly for the web app (public\wasm\)

echo ============================================
echo Route Planner - C++ Build Script
echo ============================================
echo.

REM Check if CMake is available
where cmake >nul 2>nul
if %ERRORLEVEL% NEQ 0 (
    echo Error: CMake not found. Please install CMake first.
    echo Download from: https://cmake.org/download/
    exit /b 1
)

if /i "%~1"=="wasm" goto :wasm

:native
REM Create build directory
if not exist build mkdir build
cd build

echo [1/3] Configuring with CMake...
cmake .. -DCMAKE_BUILD_TYPE=Release
if %ERRORLEVEL% NEQ 0 (
    echo Error: CMake configuration failed
    cd ..
    exit /b 1
)

echo.
echo [2/3] Building project...
cmake --build . --config Release
if %ERRORLEVEL% NEQ 0 (
    echo Error: Build failed
    cd ..
    exit /b 1
)

echo.
echo [3/3] Build complete!
echo.
echo Executable location: build\route_planner.exe (atau build\Release\route_planner.exe untuk generator MSVC)
echo.
echo To run:
echo   cd build\Release
echo   route_planner.exe --csv ..\..\samples\location.csv --start-name "Kantor" --start-lat -8.65 --start-lon 115.23 --teams 14
echo.

cd ..
exit /b 0

:wasm
REM Build WebAssembly flavor (requires Emscripten SDK, default C:\emsdk)
if "%EMSDK%"=="" set "EMSDK=C:\emsdk"
if not exist "%EMSDK%\emsdk_env.bat" (
    echo Error: Emscripten SDK not found at "%EMSDK%"
    echo Set the EMSDK environment variable or edit this script.
    exit /b 1
)
call "%EMSDK%\emsdk_env.bat" >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo Error: Failed to load emsdk environment
    exit /b 1
)
where emcc >nul 2>nul
if %ERRORLEVEL% NEQ 0 (
    echo Error: emcc not found in PATH after emsdk_env. Check EMSDK location.
    exit /b 1
)

echo [1/2] Configuring WASM build with CMake (Emscripten)...
emcmake cmake -S . -B .build-wasm -G Ninja -DCMAKE_BUILD_TYPE=Release
if %ERRORLEVEL% NEQ 0 (
    echo Error: CMake configuration failed
    exit /b 1
)

echo.
echo [2/2] Building WASM module...
cmake --build .build-wasm --parallel
if %ERRORLEVEL% NEQ 0 (
    echo Error: Build failed
    exit /b 1
)

echo.
echo Complete! WASM artifacts copied to public\wasm\ - run "npm run dev" to try.
exit /b 0
