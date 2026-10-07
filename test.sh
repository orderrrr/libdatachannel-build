#!/usr/bin/env bash
# Links test/wss.cpp against a built archive with Zig and checks wss:// verification natively.
# Usage: test.sh <target> (run on that target's OS)
set -euo pipefail

target=$1
pkg="dist/libdatachannel-$target"
good=wss://echo.websocket.org/
bad=(wss://expired.badssl.com/ wss://wrong.host.badssl.com/ wss://self-signed.badssl.com/)
exe=build/wss
case "$target" in
  windows-*) exe=build/wss.exe; libs=(-lws2_32 -liphlpapi -lbcrypt -lcrypt32 -luser32 -ladvapi32) ;;
  *) libs=(-lpthread) ;;
esac

zig c++ -O2 -std=c++17 -DRTC_STATIC -I"$pkg/include" test/wss.cpp \
  "$pkg/lib/libdatachannel.a" "$pkg/lib/libjuice.a" "$pkg/lib/libusrsctp.a" \
  "$pkg/lib/libssl.a" "$pkg/lib/libcrypto.a" "${libs[@]}" -o "$exe"
case "$target" in
  linux-*) ldd "$exe" ;;
  macos-*) otool -L "$exe" ;;
  windows-*) objdump -p "$exe" | grep 'DLL Name' || true ;;
esac

unset SSL_CERT_FILE SSL_CERT_DIR
case "$target" in
  # libdatachannel (v0.24.6, upstream master) never verifies WebSocket certificates on Windows.
  windows-*)
    "$exe" "$good" open 2>&1 | tee build/windows.log
    if grep -q "verification with root CA is not supported on Windows" build/windows.log; then
      echo "NOTE: Windows wss:// is encrypted but not certificate-verified"
    fi
    ;;
  *)
    "$exe" "$good" open
    for url in "${bad[@]}"; do "$exe" "$url" fail; done
    ;;
esac
