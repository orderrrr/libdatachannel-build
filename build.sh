#!/usr/bin/env bash
# Cross-builds static libdatachannel (data channels + WebSocket, no media), libjuice, usrsctp and
# OpenSSL with `zig cc`/`zig c++`, so they link into Zig executables. Usage: build.sh <target>
set -euo pipefail

target=$1
name="libdatachannel-$target"
root=$(pwd)
work="$root/build/$target"
pkg="$root/dist/$name"
openssl_version=3.5.9
openssl_sha256=603f5602e2eef00d77fbd429d34dcd5822bb301757a1bc9cdb24c670f1eb859a

# OPENSSLDIR holds the default verify paths (cert.pem, certs/) on the user's machine.
# Windows keeps OpenSSL's admin-only default; rd exports the system roots and sets SSL_CERT_FILE.
case "$target" in
  linux-x86_64)   zig_target=x86_64-linux-gnu.2.28; ossl_target=linux-x86_64;   system=Linux ;;
  macos-aarch64)  zig_target=aarch64-macos.14.0;    ossl_target=darwin64-arm64; system=Darwin ;;
  windows-x86_64) zig_target=x86_64-windows-gnu;    ossl_target=mingw64;        system=Windows ;;
  *) echo "unknown target $target" >&2; exit 1 ;;
esac

rm -rf "$work" "$pkg" "dist/$name.tar.gz"
mkdir -p "$work/tools" "$pkg/lib" "$pkg/include" "$pkg/licenses"
for tool in cc c++ ar ranlib; do
  case "$tool" in
    cc|c++) printf '#!/bin/sh\nexec zig %s -target %s -g0 "$@"\n' "$tool" "$zig_target" ;;
    *) printf '#!/bin/sh\nexec zig %s "$@"\n' "$tool" ;;
  esac > "$work/tools/$tool"
  chmod +x "$work/tools/$tool"
done

tarball="openssl-$openssl_version.tar.gz"
[ -f "$root/build/$tarball" ] || curl -sfL -o "$root/build/$tarball" \
  "https://github.com/openssl/openssl/releases/download/openssl-$openssl_version/$tarball"
echo "$openssl_sha256  $root/build/$tarball" | shasum -a 256 -c -
tar -xzf "$root/build/$tarball" -C "$work"

# no-quic: Zig's MinGW headers lack SIO_UDP_NETRESET. no-module: providers are built in.
# no-autoload-config: distro openssl.cnf files (e.g. Fedora crypto-policies) target their own OpenSSL.
# Configure on a Unix host rejects "C:/..." as relative, so Windows sets the Makefile variable.
case "$target" in
  windows-*) openssldir="C:/Program Files/Common Files/SSL" ;;
  *) openssldir=/etc/ssl ;;
esac
(
  cd "$work/openssl-$openssl_version"
  CC="$work/tools/cc" AR="$work/tools/ar" RANLIB="$work/tools/ranlib" ./Configure "$ossl_target" \
    no-shared no-module no-engine no-autoload-config no-quic no-apps no-tests no-docs --prefix=/usr/local --openssldir=/etc/ssl
  make -j"$(getconf _NPROCESSORS_ONLN)" OPENSSLDIR="$openssldir" build_libs > "$work/openssl-build.log"
  mkdir -p "$work/openssl/lib" "$work/openssl/include"
  cp libssl.a libcrypto.a "$work/openssl/lib/"
  cp -R include/openssl "$work/openssl/include/"
)

cat > "$work/toolchain.cmake" <<EOF
set(CMAKE_SYSTEM_NAME $system)
set(CMAKE_C_COMPILER "$work/tools/cc")
set(CMAKE_CXX_COMPILER "$work/tools/c++")
set(CMAKE_AR "$work/tools/ar")
set(CMAKE_RANLIB "$work/tools/ranlib")
set(CMAKE_OSX_SYSROOT "")
set(CMAKE_INSTALL_NAME_TOOL "$(command -v true)")
EOF

cmake -S src -B "$work/cmake" \
  -DCMAKE_TOOLCHAIN_FILE="$work/toolchain.cmake" \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX="$work/install" -DCMAKE_INSTALL_LIBDIR=lib \
  -DOPENSSL_ROOT_DIR="$work/openssl" -DOPENSSL_USE_STATIC_LIBS=TRUE \
  -DCAPI_STDCALL=OFF \
  -DNO_WEBSOCKET=OFF -DNO_MEDIA=ON -DNO_TESTS=ON -DNO_EXAMPLES=ON \
  -DUSE_GNUTLS=OFF -DUSE_MBEDTLS=OFF -DUSE_NICE=OFF \
  -DPREFER_SYSTEM_LIB=OFF -DUSE_SYSTEM_JUICE=OFF \
  -DUSE_SYSTEM_USRSCTP=OFF -DUSE_SYSTEM_PLOG=OFF \
  -DBUILD_SHARED_LIBS=OFF \
  -DRTC_UPDATE_VERSION_HEADER=OFF \
  -Dsctp_build_programs=OFF -Dsctp_build_fuzzer=OFF \
  -DPLOG_BUILD_SAMPLES=OFF -DPLOG_BUILD_TESTS=OFF -DPLOG_INSTALL=OFF
cmake --build "$work/cmake" --target datachannel --parallel
cmake --install "$work/cmake"

cp -R "$work/install/include/rtc" "$pkg/include/"
cp "$work/install/lib/libdatachannel.a" "$work/install/lib/libjuice.a" "$work/install/lib/libusrsctp.a" \
  "$work/openssl/lib/libssl.a" "$work/openssl/lib/libcrypto.a" "$pkg/lib/"
cp src/LICENSE "$pkg/licenses/libdatachannel.txt"
cp src/deps/libjuice/LICENSE "$pkg/licenses/libjuice.txt"
cp src/deps/usrsctp/LICENSE.md "$pkg/licenses/usrsctp.md"
cp src/deps/plog/LICENSE "$pkg/licenses/plog.txt"
cp "$work/openssl-$openssl_version/LICENSE.txt" "$pkg/licenses/openssl.txt"
printf 'libdatachannel %s %s\nopenssl %s\nzig %s %s\n' "$LIBDATACHANNEL_REF" "$(git -C src rev-parse HEAD)" \
  "$openssl_version" "$(zig version)" "$zig_target" > "$pkg/VERSION"

tar -czf "dist/$name.tar.gz" -C dist "$name"
