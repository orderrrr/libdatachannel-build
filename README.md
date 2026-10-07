# libdatachannel-build

Prebuilt [libdatachannel](https://github.com/paullouisageneau/libdatachannel) shared libraries
(data channels + WebSocket, no media) for linux-x86_64, macos-aarch64 and windows-x86_64.
OpenSSL, libjuice, usrsctp and plog are linked in statically; only the C API (`rtc/rtc.h`) is exported.

Push a `v*` tag to publish a release. The upstream version is `LIBDATACHANNEL_REF` in the workflow.

Archive layout: `include/rtc/`, `lib/` (`.so`/`.dylib`/import `.lib`), `bin/` (Windows `.dll`), `licenses/`.

Upstream code is unmodified. Licenses: libdatachannel and libjuice MPL-2.0, usrsctp BSD-3-Clause,
plog MIT, OpenSSL Apache-2.0.
