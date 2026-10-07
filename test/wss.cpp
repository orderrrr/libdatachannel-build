// Opens one verified WebSocket. Usage: wss <url> open|fail
// Exits 0 when the outcome matches: "open" needs the TLS handshake and upgrade to succeed.
#include <rtc/rtc.h>

#include <atomic>
#include <chrono>
#include <cstdio>
#include <cstring>
#include <thread>

static std::atomic<int> outcome{0}; // 1 open, -1 error or closed

int main(int argc, char **argv) {
	if (argc != 3 || (std::strcmp(argv[2], "open") != 0 && std::strcmp(argv[2], "fail") != 0)) {
		std::fprintf(stderr, "usage: wss <url> open|fail\n");
		return 2;
	}
	rtcInitLogger(RTC_LOG_WARNING, nullptr);
	rtcWsConfiguration config = {};
	config.connectionTimeoutMs = 10000;
	int ws = rtcCreateWebSocketEx(argv[1], &config);
	if (ws < 0) {
		std::fprintf(stderr, "rtcCreateWebSocketEx failed: %d\n", ws);
		return 1;
	}
	rtcSetOpenCallback(ws, [](int, void *) { outcome = 1; });
	rtcSetErrorCallback(ws, [](int, const char *error, void *) {
		std::fprintf(stderr, "error: %s\n", error);
		outcome = -1;
	});
	rtcSetClosedCallback(ws, [](int, void *) { outcome = outcome == 1 ? 1 : -1; });
	for (int i = 0; i < 150 && outcome == 0; ++i)
		std::this_thread::sleep_for(std::chrono::milliseconds(100));
	int result = outcome;
	rtcDeleteWebSocket(ws);
	rtcCleanup();
	const char *got = result == 1 ? "open" : result == 0 ? "timeout" : "fail";
	std::printf("%s: %s (expected %s)\n", argv[1], got, argv[2]);
	return std::strcmp(got, argv[2]) == 0 ? 0 : 1;
}
