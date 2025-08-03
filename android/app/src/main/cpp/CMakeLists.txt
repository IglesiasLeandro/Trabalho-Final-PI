cmake_minimum_required(VERSION 3.10.2)

project("azulejo_detector")

# Adiciona a biblioteca compartilhada usada pelo Flutter
add_library(
    azulejo_detector
    SHARED
    main.cpp
    predictions.cpp
)

# Habilita suporte ao C++17
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# === Diretório dos headers do OpenCV embarcado ===
include_directories(include)

# === Declaração da biblioteca OpenCV como IMPORTED ===
add_library(opencv_java4 SHARED IMPORTED)

# Define onde está a biblioteca .so (mude se necessário)
set_target_properties(opencv_java4 PROPERTIES
    IMPORTED_LOCATION
    ${CMAKE_SOURCE_DIR}/../jniLibs/${ANDROID_ABI}/libopencv_java4.so
)
set(CMAKE_ANDROID_NDK ${ANDROID_NDK})
# Vincula com a lib do OpenCV e log (necessário no Android)
target_link_libraries(
    azulejo_detector
    opencv_java4
    log
    android
)