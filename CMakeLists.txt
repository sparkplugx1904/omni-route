cmake_minimum_required(VERSION 3.15)
project(RoutePlanner VERSION 6.0 LANGUAGES CXX)

# Single CMakeLists for BOTH build flavors:
#
#   Native CLI   : cmake -S . -B build          (build.bat / build.sh)
#   WebAssembly  : emcmake cmake -S . -B .build-wasm   (build.bat wasm / build.sh wasm)
#
# The flavor is detected automatically: with the Emscripten toolchain
# (emcmake) CMAKE_SYSTEM_NAME becomes "Emscripten" and the WASM target is
# built. Without it, the native CLI target is built.

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

if(NOT CMAKE_BUILD_TYPE)
    set(CMAKE_BUILD_TYPE Release)
endif()

# All C++ lives in src/: headers, sources, and vendored header-only libs.
include_directories(
    ${PROJECT_SOURCE_DIR}/src
    ${PROJECT_SOURCE_DIR}/src/third_party
)

if(CMAKE_SYSTEM_NAME STREQUAL "Emscripten")
    # ------------------------------------------------------------------
    # WASM flavor (web app)
    # ------------------------------------------------------------------
    # Subset of sources only: no osrm_client (sockets), no map_builder
    # (file-based HTML) and no native main (CLI) — networking and rendering
    # live on the JS side in the browser.
    set(CMAKE_EXECUTABLE_SUFFIX ".js")
    set(CMAKE_CXX_FLAGS_RELEASE "-O3 -DNDEBUG")
    set(CMAKE_CXX_FLAGS_DEBUG "-O0 -g -Wall -Wextra")

    add_executable(route_planner_wasm
        src/wasm_main.cpp
        src/utils.cpp
        src/csv_parser.cpp
        src/tsp_solver.cpp
        src/clustering.cpp
        src/engine.cpp
    )

    # Link options: modularized module (createRoutePlanner factory),
    # memory growth, and the C-ABI surface used by public/js/wasm/worker-entry.js
    target_link_options(route_planner_wasm PRIVATE
        -sMODULARIZE=1
        -sEXPORT_NAME=createRoutePlanner
        -sALLOW_MEMORY_GROWTH=1
        -sMAXIMUM_MEMORY=4GB
        -sINITIAL_MEMORY=64MB
        -sEXPORTED_FUNCTIONS=_parse_csv,_haversine_matrix_fill,_compute_routes_wasm,_free_ptr,_malloc,_free
        -sEXPORTED_RUNTIME_METHODS=HEAPF64,HEAPU8,UTF8ToString,stringToUTF8)

    # Copy artifacts into the web assets so `vite build` ships them
    set(WASM_OUT_DIR ${PROJECT_SOURCE_DIR}/public/wasm)
    file(MAKE_DIRECTORY ${WASM_OUT_DIR})
    add_custom_command(TARGET route_planner_wasm POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E copy
            $<TARGET_FILE:route_planner_wasm>
            ${WASM_OUT_DIR}/route_planner_wasm.js
        COMMAND ${CMAKE_COMMAND} -E copy
            ${CMAKE_CURRENT_BINARY_DIR}/route_planner_wasm.wasm
            ${WASM_OUT_DIR}/route_planner_wasm.wasm)

    message(STATUS "Build flavor: WASM (web) -> ${WASM_OUT_DIR}")
else()
    # ------------------------------------------------------------------
    # Native CLI flavor
    # ------------------------------------------------------------------
    set(CMAKE_CXX_FLAGS_RELEASE "-O3 -march=native -DNDEBUG")
    set(CMAKE_CXX_FLAGS_DEBUG "-g -O0 -Wall -Wextra")

    # Find OpenSSL (optional, for MD5 hash)
    find_package(OpenSSL)
    if(OPENSSL_FOUND)
        add_definitions(-DUSE_OPENSSL)
    endif()

    # Find OpenMP (optional, for parallelism)
    find_package(OpenMP)

    add_executable(route_planner
        src/utils.cpp
        src/csv_parser.cpp
        src/osrm_client.cpp
        src/tsp_solver.cpp
        src/clustering.cpp
        src/engine.cpp
        src/map_builder.cpp
        src/main.cpp
    )

    target_link_libraries(route_planner pthread)

    if(OPENSSL_FOUND)
        target_link_libraries(route_planner OpenSSL::SSL OpenSSL::Crypto)
    endif()

    if(OpenMP_CXX_FOUND)
        target_link_libraries(route_planner OpenMP::OpenMP_CXX)
    endif()

    # Windows-specific: link ws2_32 for networking
    if(WIN32)
        target_link_libraries(route_planner ws2_32 crypt32)
        # Define Windows 10 for cpp-httplib compatibility
        target_compile_definitions(route_planner PRIVATE _WIN32_WINNT=0x0A00)
    endif()

    install(TARGETS route_planner DESTINATION bin)
    message(STATUS "Build flavor: Native CLI (route_planner)")
endif()
