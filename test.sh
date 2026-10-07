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
  windows-*)
    # OpenSSL's default paths hold no roots on Windows; rd supplies them through SSL_CERT_FILE.
    "$exe" "$good" fail
    powershell -NoProfile -Command '
      $pem = Get-ChildItem Cert:\LocalMachine\Root | ForEach-Object {
        "-----BEGIN CERTIFICATE-----`n" + [Convert]::ToBase64String($_.RawData, "InsertLineBreaks") + "`n-----END CERTIFICATE-----"
      }
      Set-Content -Path build\roots.pem -Value $pem -Encoding ascii'
    export SSL_CERT_FILE="$(pwd)/build/roots.pem"
    ;;
esac
"$exe" "$good" open
for url in "${bad[@]}"; do "$exe" "$url" fail; done
