# libdatachannel-build

Prebuilt static [libdatachannel](https://github.com/paullouisageneau/libdatachannel) archives
(data channels + WebSocket, no media) for linux-x86_64, macos-aarch64 and windows-x86_64.
Everything, including OpenSSL 3.5.9, is cross-compiled with `zig cc`/`zig c++` (Zig 0.16.0), so the
archives link into Zig executables that use Zig's libc++. Link them with `-DRTC_STATIC`.

`./build.sh <target>` builds `dist/libdatachannel-<target>.tar.gz`; `./test.sh <target>` links a
small client and checks verified `wss://` connections natively. Push a `v*` tag to publish a release.

Archive layout: `include/rtc/`, `lib/` (`libdatachannel.a`, `libjuice.a`, `libusrsctp.a`,
`libssl.a`, `libcrypto.a`), `licenses/`, `VERSION`. Windows also needs
`ws2_32 iphlpapi bcrypt crypt32 user32 advapi32`.

## Certificate verification

libdatachannel verifies WebSocket servers against OpenSSL's default verify paths.
OpenSSL never loads an `openssl.cnf` (`no-autoload-config`).

- Linux and macOS: `OPENSSLDIR=/etc/ssl`, so `/etc/ssl/cert.pem` and the hashed `/etc/ssl/certs`
  directory. Tested on macOS 14+, Ubuntu 22.04, Debian 12, Fedora 41, Arch and openSUSE Tumbleweed.
- Windows: libdatachannel (v0.24.6 and upstream master) disables WebSocket certificate
  verification on Windows, so `wss://` there is encrypted but not authenticated.

Upstream code is unmodified. Licenses: libdatachannel and libjuice MPL-2.0, usrsctp BSD-3-Clause,
plog MIT, OpenSSL Apache-2.0.
