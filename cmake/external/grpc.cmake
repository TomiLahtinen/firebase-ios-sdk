# Copyright 2018 Google
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

include(ExternalProject)
include(ExternalProjectFlags)

set(GRPC_EP_DIR ${PROJECT_BINARY_DIR}/external/grpc)
set(GRPC_SOURCE_DIR ${GRPC_EP_DIR}/src/grpc-download)


## gRPC download

# Several gRPC dependencies are available as submodules within the
# gRPC project but can also be taken from the host system. Enable downloading
# these if they're not provided.
set(
  GRPC_GIT_SUBMODULES
  third_party/cares/cares
)

find_package(OpenSSL)
if(NOT OPENSSL_FOUND)
  list(APPEND GRPC_GIT_SUBMODULES third_party/boringssl)
endif()

find_package(ZLIB)
if(NOT ZLIB_FOUND)
  list(APPEND GRPC_GIT_SUBMODULES third_party/zlib)
endif()

# Use separate ExternalProjects for downloading and building gRPC so that:
#
#   * The download can start much sooner in the build, in parallel with
#     dependencies that gRPC needs.
#   * Dependencies which gRPC includes can be installed first while relying on
#     gRPC's own submodules to manage which version we get.
#

ExternalProject_GitSource(
  GRPC_GIT
  GIT_REPOSITORY "https://github.com/grpc/grpc.git"
  GIT_TAG "v1.8.3"
  GIT_SUBMODULES ${GRPC_GIT_SUBMODULES}
)

ExternalProject_Add(
  grpc-download

  ${GRPC_GIT}

  PREFIX ${GRPC_EP_DIR}

  UPDATE_COMMAND ""
  CONFIGURE_COMMAND ""
  BUILD_COMMAND ""
  INSTALL_COMMAND ""
  TEST_COMMAND ""
)


## Flags for the sub-builds

set(
  COMMON_CMAKE_ARGS
  -DCMAKE_INSTALL_PREFIX:PATH=${FIREBASE_INSTALL_DIR}
  -DCMAKE_BUILD_TYPE:STRING=${CMAKE_BUILD_TYPE}
)

set(
  GRPC_CMAKE_ARGS
  ${COMMON_CMAKE_ARGS}
  -DgRPC_INSTALL:BOOL=ON
  -DgRPC_BUILD_TESTS:BOOL=OFF
  -DBUILD_SHARED_LIBS:BOOL=OFF

  # TODO(rsgowman): We're currently building nanopb twice; once via grpc, and
  # once via nanopb. The version from grpc is the one that actually ends up
  # being used. We need to fix this such that either:
  #   a) we instruct grpc to use our nanopb
  #   b) we rely on grpc's nanopb instead of using our own.
  # For now, we'll pass in the necessary nanopb cflags into grpc. (We require
  # 16 bit fields. Without explicitly requesting this, nanopb uses 8 bit
  # fields.)
  -DCMAKE_C_FLAGS=-DPB_FIELD_16BIT
  -DCMAKE_CXX_FLAGS=-DPB_FIELD_16BIT
)


## boringssl

# gRPC supports compiling with an outboard OpenSSL or compiling against a
# built-in BoringSSL. Unfortunately, BoringSSL does not support installation so
# downstream projects that need gRPC also need to handle this.

if(OPENSSL_FOUND)
  if(NOT DEFINED OPENSSL_ROOT_DIR)
    get_filename_component(
      OPENSSL_ROOT_DIR
      ${OPENSSL_INCLUDE_DIR}
      DIRECTORY
    )
  endif()

  list(
    APPEND GRPC_CMAKE_ARGS
    -DgRPC_SSL_PROVIDER:STRING=package
    -DOPENSSL_ROOT_DIR=${OPENSSL_ROOT_DIR}

    # gRPC's CMakeLists.txt does not account for finding OpenSSL in a directory
    # that's not in the default search path.
    -DCMAKE_CXX_FLAGS=-I${OPENSSL_INCLUDE_DIR}
  )
endif()


## c-ares

ExternalProject_Add(
  c-ares
  DEPENDS
    grpc-download

  PREFIX ${GRPC_EP_DIR}

  DOWNLOAD_COMMAND ""
  SOURCE_DIR ${GRPC_SOURCE_DIR}/third_party/cares/cares

  CMAKE_CACHE_ARGS
    ${COMMON_CMAKE_ARGS}
    -DCARES_STATIC:BOOL=ON
    -DCARES_SHARED:BOOL=OFF
    -DCARES_STATIC_PIC:BOOL=ON

  UPDATE_COMMAND ""
  TEST_COMMAND ""
)

list(
  APPEND GRPC_CMAKE_ARGS
  -DgRPC_CARES_PROVIDER:STRING=package
  -Dc-ares_DIR:PATH=${FIREBASE_INSTALL_DIR}/lib/cmake/c-ares
)


## protobuf

# Unlike other dependencies of gRPC, we control the protobuf version because we
# have checked-in protoc outputs that must match the runtime.

# The location where protobuf-config.cmake will be installed varies by platform
if (WIN32)
  set(PROTOBUF_CONFIG_DIR "${FIREBASE_INSTALL_DIR}/cmake")
else()
  set(PROTOBUF_CONFIG_DIR "${FIREBASE_INSTALL_DIR}/lib/cmake/protobuf")
endif()

list(
  APPEND GRPC_CMAKE_ARGS
  -DgRPC_PROTOBUF_PROVIDER:STRING=package
  -DgRPC_PROTOBUF_PACKAGE_TYPE:STRING=CONFIG
  -DProtobuf_DIR:PATH=${PROTOBUF_CONFIG_DIR}
)


## zlib

# zlib can be built by grpc but we can avoid it on platforms that provide it
# by default.
if(ZLIB_FOUND)
  add_custom_target(zlib)

  list(
    APPEND GRPC_CMAKE_ARGS
    -DgRPC_ZLIB_PROVIDER:STRING=package
    -DZLIB_INCLUDE_DIR:PATH=${ZLIB_INCLUDE_DIR}
    -DZLIB_LIBRARY:FILEPATH=${ZLIB_LIBRARY}
  )

else()
  ExternalProject_Add(
    zlib
    DEPENDS
      grpc-download

    PREFIX ${GRPC_EP_DIR}

    DOWNLOAD_COMMAND ""
    SOURCE_DIR ${GRPC_SOURCE_DIR}/third_party/zlib

    CMAKE_CACHE_ARGS
      ${COMMON_CMAKE_ARGS}

    UPDATE_COMMAND ""
    TEST_COMMAND ""
  )

  list(
    APPEND GRPC_CMAKE_ARGS
    -DgRPC_ZLIB_PROVIDER:STRING=package
  )
endif()


## gRPC build

ExternalProject_Add(
  grpc
  DEPENDS
    grpc-download
    c-ares
    protobuf
    zlib

  PREFIX ${GRPC_EP_DIR}

  DOWNLOAD_COMMAND ""
  SOURCE_DIR ${GRPC_EP_DIR}/src/grpc-download

  CMAKE_ARGS
    ${GRPC_CMAKE_ARGS}

  BUILD_COMMAND
    ${CMAKE_COMMAND} --build . --target grpc

  UPDATE_COMMAND ""
  TEST_COMMAND ""
  INSTALL_COMMAND ""
)
