// Narrow, explicit absence responses for APIs that are optional for headless use.
// These are not implementations of macOS graphics or input.
#include <stdint.h>
#include <stdio.h>
#include <stdbool.h>

bool SteamAPI_RestartAppIfNecessary(uint32_t appID) {
    fprintf(stderr, "FACTORIO_PROBE: Steam client unavailable on iPadOS\n");
    return false;
}

bool SteamAPI_Init(void) {
    fprintf(stderr, "FACTORIO_PROBE: Steam initialization unavailable\n");
    return false;
}

// OpenCL extension cl_khr_icd: no OpenCL platforms are available on iPadOS.
int32_t clGetPlatformIDs(uint32_t capacity, void **platforms, uint32_t *count) {
    if (count) *count = 0;
    fprintf(stderr, "FACTORIO_PROBE: OpenCL unavailable (CL_PLATFORM_NOT_FOUND_KHR)\n");
    return -1001;
}
