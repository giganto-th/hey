// Reads the system "Now Playing" info through the private MediaRemote framework and prints it as JSON.
// Private API: Apple may change or block it in any macOS update. Nothing here is stored or sent anywhere.
#include "heynp.h"
#include <CoreFoundation/CoreFoundation.h>
#include <dispatch/dispatch.h>
#include <dlfcn.h>
#include <stdio.h>
#include <string.h>

typedef void (^InfoHandler)(CFDictionaryRef);
typedef void (*GetInfoFn)(dispatch_queue_t, InfoHandler);

static void print_json_string(const char *s) {
    putchar('"');
    for (const unsigned char *p = (const unsigned char *)s; *p; p++) {
        switch (*p) {
            case '"': fputs("\\\"", stdout); break;
            case '\\': fputs("\\\\", stdout); break;
            case '\n': fputs("\\n", stdout); break;
            case '\r': fputs("\\r", stdout); break;
            case '\t': fputs("\\t", stdout); break;
            default:
                if (*p < 0x20) printf("\\u%04x", *p); else putchar(*p);
        }
    }
    putchar('"');
}

static void print_string_field(CFDictionaryRef d, const char *name, const char *key) {
    CFStringRef k = CFStringCreateWithCString(NULL, key, kCFStringEncodingUTF8);
    CFTypeRef v = CFDictionaryGetValue(d, k);
    CFRelease(k);
    printf("\"%s\":", name);
    if (v && CFGetTypeID(v) == CFStringGetTypeID()) {
        char buf[2048];
        if (CFStringGetCString((CFStringRef)v, buf, sizeof buf, kCFStringEncodingUTF8)) { print_json_string(buf); return; }
    }
    fputs("null", stdout);
}

static void print_number_field(CFDictionaryRef d, const char *name, const char *key) {
    CFStringRef k = CFStringCreateWithCString(NULL, key, kCFStringEncodingUTF8);
    CFTypeRef v = CFDictionaryGetValue(d, k);
    CFRelease(k);
    printf("\"%s\":", name);
    double x = 0;
    if (v && CFGetTypeID(v) == CFNumberGetTypeID() && CFNumberGetValue((CFNumberRef)v, kCFNumberDoubleType, &x)) printf("%.3f", x);
    else fputs("null", stdout);
}

void heynp_dump(void *interpreter, void *cv) {
    (void)interpreter; (void)cv;
    void *lib = dlopen("/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote", RTLD_NOW);
    GetInfoFn get = lib ? (GetInfoFn)dlsym(lib, "MRMediaRemoteGetNowPlayingInfo") : NULL;
    if (!get) { puts("{\"error\":\"unavailable\"}"); fflush(stdout); return; }

    dispatch_semaphore_t done = dispatch_semaphore_create(0);
    get(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^(CFDictionaryRef info) {
        if (!info || CFDictionaryGetCount(info) == 0) {
            puts("{\"error\":\"empty\"}");
        } else {
            fputs("{", stdout);
            print_string_field(info, "title", "kMRMediaRemoteNowPlayingInfoTitle"); fputs(",", stdout);
            print_string_field(info, "artist", "kMRMediaRemoteNowPlayingInfoArtist"); fputs(",", stdout);
            print_string_field(info, "album", "kMRMediaRemoteNowPlayingInfoAlbum"); fputs(",", stdout);
            print_number_field(info, "rate", "kMRMediaRemoteNowPlayingInfoPlaybackRate"); fputs(",", stdout);
            print_number_field(info, "duration", "kMRMediaRemoteNowPlayingInfoDuration"); fputs(",", stdout);
            print_number_field(info, "elapsed", "kMRMediaRemoteNowPlayingInfoElapsedTime");
            puts("}");
        }
        fflush(stdout);
        dispatch_semaphore_signal(done);
    });
    if (dispatch_semaphore_wait(done, dispatch_time(DISPATCH_TIME_NOW, 3 * NSEC_PER_SEC)) != 0) {
        puts("{\"error\":\"timeout\"}");
        fflush(stdout);
    }
}
