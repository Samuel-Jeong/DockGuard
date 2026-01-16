#import "MouseMonitor.h"
#import "DebugLog.h"
#import <Cocoa/Cocoa.h>
#import <ApplicationServices/ApplicationServices.h>

@interface MouseMonitor ()
@property (strong) NSSet<NSNumber *> *allowedDisplays;
@property (strong) NSSet<NSString *> *ignoredBundleIDs;
@property (assign) CFMachPortRef eventTap;
@property (assign) CFRunLoopSourceRef runLoopSource;
@property (assign) BOOL isMonitoring;
@property (assign) CGFloat bottomEdgeThresholdPercent;
@property (assign) CGPoint lastMouseLocation;
@property (assign) CFTimeInterval lastProcessedTime;
@property (strong) NSArray<NSDictionary *> *cachedDisplays; // { id: NSNumber, bounds: NSValue(NSRect) }

- (void)reloadPreferences;
- (void)refreshDisplaysCache;
@end

static void displayReconfigCallback(CGDirectDisplayID display,
                                   CGDisplayChangeSummaryFlags flags,
                                   void *userInfo) {
    MouseMonitor *monitor = (__bridge MouseMonitor *)userInfo;
    [monitor refreshDisplaysCache];
    DockGuardLog(@"Display configuration changed (flags=%u), refreshed cache", (unsigned)flags);
}

CGEventRef mouseEventCallback(CGEventTapProxy proxy, CGEventType type, CGEventRef event, void *refcon) {
    MouseMonitor *monitor = (__bridge MouseMonitor *)refcon;
    
    if (type != kCGEventMouseMoved) {
        return event;
    }
    
    CGPoint mouseLocation = CGEventGetLocation(event);

    // Skip tiny movements to reduce CPU usage
    CGFloat dx = (CGFloat)(mouseLocation.x - monitor.lastMouseLocation.x);
    CGFloat dy = (CGFloat)(mouseLocation.y - monitor.lastMouseLocation.y);
    if ((dx * dx + dy * dy) < 1.0) {
        return event;
    }
    monitor.lastMouseLocation = mouseLocation;

    // Basic throttling to reduce CPU usage on high-frequency mouse move events
    CFTimeInterval now = CFAbsoluteTimeGetCurrent();
    if (now - monitor.lastProcessedTime < 0.010) { // ~100Hz
        return event;
    }
    monitor.lastProcessedTime = now;

    BOOL isInDangerZone = [monitor shouldBlockMouseAtLocation:mouseLocation];
    
    if (isInDangerZone) {
        DockGuardLog(@"WORKAROUND: Redirecting cursor from dock trigger zone");
        
        CGPoint safeLocation = mouseLocation;
        safeLocation.y -= 3.0;
        CGEventSetLocation(event, safeLocation);
        
        DockGuardLog(@"Cursor redirected from (%.1f, %.1f) to (%.1f, %.1f)",
                     mouseLocation.x, mouseLocation.y, safeLocation.x, safeLocation.y);
    }
    
    return event;
}

@implementation MouseMonitor

- (instancetype)init {
    if (self = [super init]) {
        _allowedDisplays = [self loadAllowedDisplays];
        _ignoredBundleIDs = [self loadIgnoredBundleIDs];
        _eventTap = NULL;
        _runLoopSource = NULL;
        _isMonitoring = NO;
        _bottomEdgeThresholdPercent = [self loadBottomEdgeThresholdPercent];
        _lastMouseLocation = CGPointZero;
        _lastProcessedTime = 0;
        _cachedDisplays = @[];
        
        [[NSNotificationCenter defaultCenter] addObserver:self 
                                                 selector:@selector(reloadAllowed) 
                                                     name:@"AllowedDisplaysChanged" 
                                                   object:nil];

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(reloadPreferences)
                                                     name:@"PreferencesChanged"
                                                   object:nil];
    }
    return self;
}


- (void)reloadAllowed {
    self.allowedDisplays = [self loadAllowedDisplays];
    DockGuardLog(@"Reloaded allowed displays: %@", self.allowedDisplays);
}

- (void)reloadPreferences {
    self.allowedDisplays = [self loadAllowedDisplays];
    self.ignoredBundleIDs = [self loadIgnoredBundleIDs];
    self.bottomEdgeThresholdPercent = [self loadBottomEdgeThresholdPercent];
    DockGuardLog(@"Reloaded preferences: allowed=%@ ignored=%@ sensitivity=%.1f%%",
                 self.allowedDisplays, self.ignoredBundleIDs, self.bottomEdgeThresholdPercent);
}

- (void)refreshDisplaysCache {
    uint32_t displayCount = 0;
    CGGetActiveDisplayList(0, NULL, &displayCount);
    if (displayCount == 0) {
        self.cachedDisplays = @[];
        return;
    }
    CGDirectDisplayID displays[32];
    uint32_t max = (displayCount > 32) ? 32 : displayCount;
    CGGetActiveDisplayList(max, displays, &displayCount);

    NSMutableArray *arr = [NSMutableArray array];
    for (uint32_t i = 0; i < displayCount; i++) {
        CGDirectDisplayID displayID = displays[i];
        CGRect bounds = CGDisplayBounds(displayID);
        NSRect r = NSRectFromCGRect(bounds);
        [arr addObject:@{ @"id": @(displayID), @"bounds": [NSValue valueWithRect:r] }];
    }
    self.cachedDisplays = arr;
}

- (BOOL)shouldBlockMouseAtLocation:(CGPoint)mouseLocation {
    // Respect ignored apps list (by bundle identifier)
    NSString *bundleID = [NSWorkspace sharedWorkspace].frontmostApplication.bundleIdentifier;
    if (bundleID.length > 0 && [self.ignoredBundleIDs containsObject:bundleID]) {
        return NO;
    }

    // Refresh cache lazily
    if (self.cachedDisplays.count == 0) {
        [self refreshDisplaysCache];
    }

    for (NSDictionary *d in self.cachedDisplays) {
        NSNumber *displayIDNum = d[@"id"];
        NSValue *boundsValue = d[@"bounds"];
        if (!displayIDNum || !boundsValue) {
            continue;
        }

        uint32_t displayID = (uint32_t)displayIDNum.unsignedIntValue;
        NSRect displayBoundsNS = boundsValue.rectValue;
        CGRect displayBounds = NSRectToCGRect(displayBoundsNS);

        if (!CGRectContainsPoint(displayBounds, mouseLocation)) {
            continue;
        }

        if ([self.allowedDisplays containsObject:@(displayID)]) {
            return NO;
        }

        CGFloat bottomEdgeY = displayBounds.origin.y + displayBounds.size.height;
        CGFloat relativeThreshold = displayBounds.size.height * (self.bottomEdgeThresholdPercent / 100.0);
        CGFloat thresholdY = bottomEdgeY - relativeThreshold;
        return mouseLocation.y >= thresholdY;
    }

    return NO;
}

- (NSSet<NSNumber *> *)loadAllowedDisplays {
    NSArray *arr = [[NSUserDefaults standardUserDefaults] arrayForKey:@"AllowedDisplayIDs"] ?: @[];
    return [NSSet setWithArray:arr];
}

- (NSSet<NSString *> *)loadIgnoredBundleIDs {
    NSArray *arr = [[NSUserDefaults standardUserDefaults] arrayForKey:@"IgnoredBundleIDs"] ?: @[];
    NSMutableArray<NSString *> *clean = [NSMutableArray array];
    for (id v in arr) {
        if ([v isKindOfClass:[NSString class]] && ((NSString *)v).length > 0) {
            [clean addObject:v];
        }
    }
    return [NSSet setWithArray:clean];
}

- (CGFloat)loadBottomEdgeThresholdPercent {
    NSNumber *n = [[NSUserDefaults standardUserDefaults] objectForKey:@"BottomEdgeThresholdPercent"];
    double v = n ? n.doubleValue : 8.0;
    if (v < 1.0) v = 1.0;
    if (v > 30.0) v = 30.0;
    return (CGFloat)v;
}

- (BOOL)start {
    if (self.isMonitoring) {
        DockGuardLog(@"Already running, ignoring start request");
        return YES;
    }
    
    [self reloadPreferences];
    [self refreshDisplaysCache];
    
    DockGuardLog(@"Starting protection. Allowed displays: %@ (sensitivity=%.1f%%)",
                 self.allowedDisplays, self.bottomEdgeThresholdPercent);
    
    CGEventMask eventMask = CGEventMaskBit(kCGEventMouseMoved) | 
                           CGEventMaskBit(kCGEventLeftMouseDown) |
                           CGEventMaskBit(kCGEventRightMouseDown) |
                           CGEventMaskBit(kCGEventOtherMouseDown);
    self.eventTap = CGEventTapCreate(kCGHIDEventTap,
                                    kCGHeadInsertEventTap,
                                    kCGEventTapOptionDefault,
                                    eventMask,
                                    mouseEventCallback,
                                    (__bridge void *)self);
    
    if (!self.eventTap) {
        DockGuardError(@"Failed to create event tap - accessibility permission may be required");
        return NO;
    }
    
    self.runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, self.eventTap, 0);
    if (!self.runLoopSource) {
        DockGuardError(@"Failed to create run loop source");
        CFRelease(self.eventTap);
        self.eventTap = NULL;
        return NO;
    }
    
    CFRunLoopAddSource(CFRunLoopGetCurrent(), self.runLoopSource, kCFRunLoopCommonModes);
    CGEventTapEnable(self.eventTap, true);

    CGDisplayRegisterReconfigurationCallback(displayReconfigCallback, (__bridge void *)self);
    
    self.isMonitoring = YES;
    DockGuardLog(@"Started real-time mouse monitoring for %lu allowed displays", self.allowedDisplays.count);
    return YES;
}

- (void)stop {
    if (!self.isMonitoring) {
        DockGuardLog(@"Not running, ignoring stop request");
        return;
    }
    
    self.isMonitoring = NO;
    
    if (self.runLoopSource) {
        CFRunLoopRemoveSource(CFRunLoopGetCurrent(), self.runLoopSource, kCFRunLoopCommonModes);
        CFRelease(self.runLoopSource);
        self.runLoopSource = NULL;
    }
    
    if (self.eventTap) {
        CGEventTapEnable(self.eventTap, false);
        CFRelease(self.eventTap);
        self.eventTap = NULL;
    }

    CGDisplayRemoveReconfigurationCallback(displayReconfigCallback, (__bridge void *)self);
    
    DockGuardLog(@"Stopped intelligent dock trigger prevention");
}

- (void)dealloc {
    [self stop];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
