cmake_minimum_required(VERSION 3.16)
project(logicsynth LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

add_library(logicsynth STATIC src/cpp/optimizer.cpp)
target_include_directories(logicsynth PUBLIC include)
target_compile_options(logicsynth PRIVATE -Wall -Wextra -Wpedantic)

add_executable(logicsynth-demo src/cpp/main.cpp)
target_link_libraries(logicsynth-demo PRIVATE logicsynth)

include(CTest)
if(BUILD_TESTING)
  add_executable(logicsynth-cpp-test tests/cpp/test_optimizer.cpp)
  target_link_libraries(logicsynth-cpp-test PRIVATE logicsynth)
  add_test(NAME logicsynth-cpp-test COMMAND logicsynth-cpp-test)
endif()
