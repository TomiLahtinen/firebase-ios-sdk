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

include(FindPackageHandleStandardArgs)

set(BINARY_DIR ${FIREBASE_BINARY_DIR}/external/grpc)


## zlib
find_package(ZLIB REQUIRED)


## BoringSSL/OpenSSL

# If the user supplies a previously installed OpenSSL (via -DOPENSSL_ROOT_DIR)
# then FindOpenSSL will find it and set things up correctly.
#
# If not, we're using the BoringSSL supplied by gRPC and this doesn't play
# nicely:
#
#   * BoringSSL does not install, so results have to be picked out of the build
#     tree.
#   * BoringSSL does not name libraries in a way that FindOpenSSL expects.
#
# So, attempt to find OpenSSL via find_package and if not found just assume
# we're getting SSL from the build tree.

find_package(OpenSSL)
if(NOT OPENSSL_FOUND)
  find_path(
    OPENSSL_INCLUDE_DIR openssl/ssl.h
    HINTS ${BINARY_DIR}/src/grpc-download/third_party/boringssl/include
  )

  find_library(
    OPENSSL_SSL_LIBRARY
    NAMES ssl
    HINTS ${BINARY_DIR}/src/grpc-build/third_party/boringssl/ssl
    HINTS ${BINARY_DIR}/src/grpc-build/third_party/boringssl/ssl/Debug
    HINTS ${BINARY_DIR}/src/grpc-build/third_party/boringssl/ssl/Release
  )

  find_library(
    OPENSSL_CRYPTO_LIBRARY
    NAMES crypto
    HINTS ${BINARY_DIR}/src/grpc-build/third_party/boringssl/crypto
    HINTS ${BINARY_DIR}/src/grpc-build/third_party/boringssl/crypto/Debug
    HINTS ${BINARY_DIR}/src/grpc-build/third_party/boringssl/crypto/Release
  )
endif()


## C-Ares
message("c-ares_DIR ${FIREBASE_INSTALL_DIR}/lib/cmake/c-ares")
set(c-ares_DIR ${FIREBASE_INSTALL_DIR}/lib/cmake/c-ares)
find_package(c-ares CONFIG REQUIRED)


## GRPC

find_path(
  GRPC_INCLUDE_DIR grpc/grpc.h
  HINTS
    $ENV{GRPC_ROOT}/include
    ${GRPC_ROOT}/include
    ${BINARY_DIR}/src/grpc-download/include
)

find_library(
  GPR_LIBRARY
  NAMES gpr
  HINTS
    $ENV{GRPC_ROOT}/lib
    ${GRPC_ROOT}/lib
    ${BINARY_DIR}/src/grpc-build
)

find_library(
  GRPC_LIBRARY
  NAMES grpc
  HINTS
    $ENV{GRPC_ROOT}/lib
    ${GRPC_ROOT}/lib
    ${BINARY_DIR}/src/grpc-build
)

find_package_handle_standard_args(
  gRPC
  DEFAULT_MSG
  GRPC_INCLUDE_DIR
  GRPC_LIBRARY
  GPR_LIBRARY
)

if(GRPC_FOUND)
  set(GRPC_INCLUDE_DIRS ${GRPC_INCLUDE_DIR})
  set(GRPC_LIBRARIES ${GRPC_LIBRARY})

  if (NOT TARGET grpc::gpr)
    add_library(grpc::gpr UNKNOWN IMPORTED)
    set_target_properties(
      grpc::gpr PROPERTIES
      INTERFACE_INCLUDE_DIRECTORIES ${GRPC_INCLUDE_DIR}
      IMPORTED_LOCATION ${GPR_LIBRARY}
    )
  endif()

  if (NOT TARGET grpc::grpc)
    set(
      GRPC_LINK_LIBRARIES
      c-ares::cares
      grpc::gpr
      OpenSSL::SSL
      OpenSSL::Crypto
      ZLIB::ZLIB
    )

    add_library(grpc::grpc UNKNOWN IMPORTED)
    set_target_properties(
      grpc::grpc PROPERTIES
      INTERFACE_INCLUDE_DIRECTORIES ${GRPC_INCLUDE_DIR}
      INTERFACE_LINK_LIBRARIES "${GRPC_LINK_LIBRARIES}"
      IMPORTED_LOCATION ${GRPC_LIBRARY}
    )
  endif()
endif(GRPC_FOUND)
