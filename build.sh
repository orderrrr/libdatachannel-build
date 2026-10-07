#!/usr/bin/env bash
# Builds libdatachannel (data channels + WebSocket, no media) as one shared library
# with OpenSSL, libjuice, usrsctp and plog linked in statically. Usage: build.sh <target>
set -euo pipefail

target=$1
name="libdatachannel-$target"
root=$(pwd)
pkg="$root/dist/$name"

platform=()
case "$target" in
  macos-aarch64) platform=(-DCMAKE_OSX_ARCHITECTURES=arm64 -DCMAKE_OSX_DEPLOYMENT_TARGET=14.0) ;;
  windows-x86_64) platform=(-A x64 -DCMAKE_POLICY_DEFAULT_CMP0091=NEW -DCMAKE_MSVC_RUNTIME_LIBRARY=MultiThreaded -DOPENSSL_MSVC_STATIC_RT=TRUE) ;;
esac

cmake -S src -B build "${platform[@]}" \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX="$root/install" \
  -DCMAKE_INSTALL_LIBDIR=lib -DCMAKE_INSTALL_BINDIR=bin \
  -DCMAKE_INSTALL_NAME_DIR=@rpath \
  -DCMAKE_PLATFORM_NO_VERSIONED_SONAME=ON \
  -DOPENSSL_USE_STATIC_LIBS=TRUE \
  -DCAPI_STDCALL=OFF \
  -DNO_WEBSOCKET=OFF -DNO_MEDIA=ON -DNO_TESTS=ON -DNO_EXAMPLES=ON \
  -DUSE_GNUTLS=OFF -DUSE_MBEDTLS=OFF -DUSE_NICE=OFF \
  -DPREFER_SYSTEM_LIB=OFF -DUSE_SYSTEM_JUICE=OFF \
  -DUSE_SYSTEM_USRSCTP=OFF -DUSE_SYSTEM_PLOG=OFF \
  -DBUILD_SHARED_LIBS=ON -DBUILD_SHARED_DEPS_LIBS=OFF \
  -DRTC_UPDATE_VERSION_HEADER=OFF \
  -Dsctp_build_programs=OFF -Dsctp_build_fuzzer=OFF \
  -DPLOG_BUILD_SAMPLES=OFF -DPLOG_BUILD_TESTS=OFF -DPLOG_INSTALL=OFF
cmake --build build --config Release --target datachannel --parallel
cmake --install build --config Release

mkdir -p "$pkg/lib" "$pkg/include" "$pkg/licenses"
cp -R install/include/rtc "$pkg/include/"
case "$target" in
  linux-*) cp install/lib/libdatachannel.so "$pkg/lib/" ;;
  macos-*) cp install/lib/libdatachannel.dylib "$pkg/lib/" ;;
  windows-*)
    mkdir -p "$pkg/bin"
    cp install/lib/datachannel.lib "$pkg/lib/"
    cp install/bin/datachannel.dll "$pkg/bin/"
    ;;
esac
cp src/LICENSE "$pkg/licenses/libdatachannel.txt"
cp src/deps/libjuice/LICENSE "$pkg/licenses/libjuice.txt"
cp src/deps/usrsctp/LICENSE.md "$pkg/licenses/usrsctp.md"
cp src/deps/plog/LICENSE "$pkg/licenses/plog.txt"
case "$target" in
  linux-*) cp /usr/share/doc/libssl-dev/copyright "$pkg/licenses/openssl.txt" ;;
  macos-*) cp "$OPENSSL_ROOT_DIR/LICENSE.txt" "$pkg/licenses/openssl.txt" ;;
  windows-*) cp "$OPENSSL_ROOT_DIR/share/openssl/copyright" "$pkg/licenses/openssl.txt" ;;
esac
echo "$LIBDATACHANNEL_REF $(git -C src rev-parse HEAD)" > "$pkg/VERSION"

# The shared library must not need OpenSSL (or the MSVC runtime) at runtime.
case "$target" in
  linux-*) deps=$(ldd "$pkg/lib/libdatachannel.so"); readelf -d "$pkg/lib/libdatachannel.so" | grep SONAME ;;
  macos-*) deps=$(otool -L "$pkg/lib/libdatachannel.dylib") ;;
  windows-*) deps=$(objdump -p "$pkg/bin/datachannel.dll" | grep 'DLL Name') ;;
esac
echo "$deps"
if grep -Eiq 'libssl|libcrypto|msvcp|vcruntime' <<<"$deps"; then
  echo "OpenSSL or the MSVC runtime is dynamically linked" >&2
  exit 1
fi

tar -czf "dist/$name.tar.gz" -C dist "$name"
