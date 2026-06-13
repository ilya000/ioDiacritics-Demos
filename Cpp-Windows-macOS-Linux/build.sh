#!/usr/bin/env bash
# Configure + build the ImGui demo. GLFW and Dear ImGui are fetched on the first configure,
# so the first run needs network access; later builds are offline.
#
# Requirements: CMake 3.16+, a C++17 compiler, git. On macOS also the Xcode command-line tools.
set -euo pipefail
cd "$(dirname "$0")"

BUILD_DIR="${BUILD_DIR:-build}"
BUILD_TYPE="${BUILD_TYPE:-Release}"

# Be explicit about the compilers: some CMake builds (seen with CMake 4.x + Homebrew) fail to
# auto-detect the C++ compiler by bare name. CMAKE_POLICY_VERSION_MINIMUM keeps GLFW 3.4's
# older cmake_minimum_required acceptable under CMake 4.x.
CC_BIN="${CC:-$(command -v clang || command -v gcc)}"
CXX_BIN="${CXX:-$(command -v clang++ || command -v g++)}"

cmake -S . -B "${BUILD_DIR}" \
    -DCMAKE_BUILD_TYPE="${BUILD_TYPE}" \
    -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
    -DCMAKE_C_COMPILER="${CC_BIN}" \
    -DCMAKE_CXX_COMPILER="${CXX_BIN}"

cmake --build "${BUILD_DIR}" -j

echo
echo "OK: ${BUILD_DIR}/iodiacritics_demo"
echo "    run:       ${BUILD_DIR}/iodiacritics_demo"
echo "    self-test: ${BUILD_DIR}/iodiacritics_demo --selftest"
