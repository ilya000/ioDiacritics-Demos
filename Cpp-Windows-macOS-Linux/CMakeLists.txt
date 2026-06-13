cmake_minimum_required(VERSION 3.16)
project(ioDiacriticsDemoImGui VERSION 0.1.0 LANGUAGES C CXX)

# Cross-platform demo for the sibling ioDiacritics library: a Dear ImGui window (GLFW +
# OpenGL3) that restores BCS diacritics using the library's own C++17 port. GLFW and Dear
# ImGui are vendored at configure time via FetchContent, so the only host requirements are a
# C++17 compiler, CMake, and (first configure) network access. Builds on Windows, macOS, Linux.

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
if(NOT CMAKE_BUILD_TYPE AND NOT CMAKE_CONFIGURATION_TYPES)
    set(CMAKE_BUILD_TYPE Release CACHE STRING "" FORCE)
endif()

include(FetchContent)

# --- GLFW (windowing + input + clipboard) ----------------------------------------------
set(GLFW_BUILD_DOCS OFF CACHE BOOL "" FORCE)
set(GLFW_BUILD_TESTS OFF CACHE BOOL "" FORCE)
set(GLFW_BUILD_EXAMPLES OFF CACHE BOOL "" FORCE)
set(GLFW_INSTALL OFF CACHE BOOL "" FORCE)
FetchContent_Declare(
    glfw
    GIT_REPOSITORY https://github.com/glfw/glfw.git
    GIT_TAG 3.4
    GIT_SHALLOW TRUE
)
FetchContent_MakeAvailable(glfw)

# --- Dear ImGui (no upstream CMake — we add the sources we need) -------------------------
FetchContent_Declare(
    imgui
    GIT_REPOSITORY https://github.com/ocornut/imgui.git
    GIT_TAG v1.91.5
    GIT_SHALLOW TRUE
)
FetchContent_MakeAvailable(imgui)

# --- ioDiacritics C++ engine (the thing we are demoing) ----------------------------------
set(IODIACRITICS_CPP_BUILD_TESTS OFF CACHE BOOL "" FORCE)
add_subdirectory(${CMAKE_CURRENT_SOURCE_DIR}/../../ioDiacritics/cpp iodiacritics_cpp_build)

# Pull the library version out of its CMakeLists so the About panel can show it without
# hardcoding (the C++ port exposes no runtime version constant). Falls back if not found.
set(IODIA_LIB_VERSION "unknown")
file(READ "${CMAKE_CURRENT_SOURCE_DIR}/../../ioDiacritics/cpp/CMakeLists.txt" _iodia_cml)
string(REGEX MATCH "project\\(ioDiacriticsCpp[ \t\r\n]+VERSION[ \t]+([0-9]+\\.[0-9]+\\.[0-9]+)" _m "${_iodia_cml}")
if(CMAKE_MATCH_1)
    set(IODIA_LIB_VERSION "${CMAKE_MATCH_1}")
endif()

# --- OpenGL ------------------------------------------------------------------------------
set(OpenGL_GL_PREFERENCE GLVND)
find_package(OpenGL REQUIRED)

add_executable(iodiacritics_demo
    src/main.cpp
    ${imgui_SOURCE_DIR}/imgui.cpp
    ${imgui_SOURCE_DIR}/imgui_draw.cpp
    ${imgui_SOURCE_DIR}/imgui_tables.cpp
    ${imgui_SOURCE_DIR}/imgui_widgets.cpp
    ${imgui_SOURCE_DIR}/backends/imgui_impl_glfw.cpp
    ${imgui_SOURCE_DIR}/backends/imgui_impl_opengl3.cpp
    ${imgui_SOURCE_DIR}/misc/cpp/imgui_stdlib.cpp
)

target_include_directories(iodiacritics_demo PRIVATE
    ${imgui_SOURCE_DIR}
    ${imgui_SOURCE_DIR}/backends
    ${imgui_SOURCE_DIR}/misc/cpp
)

target_link_libraries(iodiacritics_demo PRIVATE glfw OpenGL::GL ioDiacritics::cpp)

# Where the bundled deshishana_*.json dictionaries live (sibling library checkout). The app
# also honours the IODIACRITICS_REPO_ROOT env var and argv[1] at runtime, and falls back to a
# ./data directory next to the binary — so a packaged build can ship the dicts alongside it.
target_compile_definitions(iodiacritics_demo PRIVATE
    IODIACRITICS_REPO_ROOT="${CMAKE_CURRENT_SOURCE_DIR}/../../ioDiacritics"
    IMGUI_FONT_DIR="${imgui_SOURCE_DIR}/misc/fonts"
    IODIACRITICS_LIB_VERSION="${IODIA_LIB_VERSION}"
    IODIACRITICS_DEMO_VERSION="${PROJECT_VERSION}"
)
if(APPLE)
    target_compile_definitions(iodiacritics_demo PRIVATE GL_SILENCE_DEPRECATION)
endif()
