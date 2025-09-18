#ifndef DebugLog_h
#define DebugLog_h

#import <Foundation/Foundation.h>

// External reference to global debug flag (defined in main.m)
extern BOOL gDebugMode;

// Conditional debug logging macro
#define DockGuardLog(format, ...) do { \
    if (gDebugMode) { \
        NSLog(@"[DockGuard] " format, ##__VA_ARGS__); \
    } \
} while(0)

// Error logging (always shown regardless of debug mode)
#define DockGuardError(format, ...) NSLog(@"[DockGuard ERROR] " format, ##__VA_ARGS__)

#endif /* DebugLog_h */