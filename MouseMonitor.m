#import "MouseMonitor.h"
#import "DebugLog.h"
#import <Cocoa/Cocoa.h>
#import <ApplicationServices/ApplicationServices.h>

@interface MouseMonitor ()
@property (strong) NSSet<NSNumber *> *allowedDisplays;
@property (assign) CFMachPortRef eventTap;
@property (assign) CFRunLoopSourceRef runLoopSource;
@property (assign) BOOL isMonitoring;
@property (assign) CGFloat bottomEdgeThresholdPercent;
@property (assign) NSTimeInterval dockTriggerDelay;
@property (assign) CGPoint lastMouseLocation;
@property (assign) NSTimeInterval hoverStartTime;
@property (assign) BOOL isHoveringAtBottom;
@property (strong) NSTimer *hoverTimer;
@end

CGEventRef mouseEventCallback(CGEventTapProxy proxy, CGEventType type, CGEventRef event, void *refcon) {
    MouseMonitor *monitor = (__bridge MouseMonitor *)refcon;
    
    if (type != kCGEventMouseMoved) {
        return event;
    }
    
    CGPoint mouseLocation = CGEventGetLocation(event);
    BOOL isInDangerZone = [monitor shouldBlockMouseAtLocation:mouseLocation];
    
    if (isInDangerZone) {
        DockGuardLog(@"🎯 WORKAROUND: Redirecting cursor from dock trigger zone without touching dock settings");
        
        CGPoint safeLocation = mouseLocation;
        safeLocation.y -= 3.0;
        CGEventSetLocation(event, safeLocation);
        
        DockGuardLog(@"🔄 Cursor redirected from (%.1f, %.1f) to (%.1f, %.1f) - dock won't trigger!", 
              mouseLocation.x, mouseLocation.y, safeLocation.x, safeLocation.y);
    }
    
    return event;
}

@implementation MouseMonitor

- (instancetype)init {
    if (self = [super init]) {
        _allowedDisplays = [self loadAllowedDisplays];
        _eventTap = NULL;
        _runLoopSource = NULL;
        _isMonitoring = NO;
        _bottomEdgeThresholdPercent = 8.0;
        _lastMouseLocation = CGPointZero;
        _hoverStartTime = 0;
        _isHoveringAtBottom = NO;
        _hoverTimer = nil;
        
        [[NSNotificationCenter defaultCenter] addObserver:self 
                                                 selector:@selector(reloadAllowed) 
                                                     name:@"AllowedDisplaysChanged" 
                                                   object:nil];
    }
    return self;
}


- (void)reloadAllowed {
    self.allowedDisplays = [self loadAllowedDisplays];
    DockGuardLog(@"Reloaded allowed displays: %@", self.allowedDisplays);
}

- (BOOL)shouldBlockMouseAtLocation:(CGPoint)mouseLocation {
    DockGuardLog(@"🖱️  마우스 위치: (%.1f, %.1f) [Quartz 좌표계]", mouseLocation.x, mouseLocation.y);
    
    uint32_t displayCount;
    CGGetActiveDisplayList(0, NULL, &displayCount);
    CGDirectDisplayID *displays = malloc(displayCount * sizeof(CGDirectDisplayID));
    CGGetActiveDisplayList(displayCount, displays, &displayCount);
    
    for (uint32_t i = 0; i < displayCount; i++) {
        CGDirectDisplayID displayID = displays[i];
        CGRect displayBounds = CGDisplayBounds(displayID);
        
        DockGuardLog(@"🖥️  Display %u - Quartz coordinates: (%.0f,%.0f) %.0fx%.0f", 
              displayID, displayBounds.origin.x, displayBounds.origin.y, displayBounds.size.width, displayBounds.size.height);
        
        CGFloat bottomEdgeY = displayBounds.origin.y + displayBounds.size.height;
        DockGuardLog(@"📍 Display %u - Bottom edge Y coordinate: %.1f", displayID, bottomEdgeY);
        
        if (CGRectContainsPoint(displayBounds, mouseLocation)) {
            BOOL isAllowed = [self.allowedDisplays containsObject:@(displayID)];
            
            DockGuardLog(@"✅ Mouse is on Display %u: %@", 
                  displayID, isAllowed ? @"Dock allowed" : @"Dock blocked");
            
            if (isAllowed) {
                DockGuardLog(@"🟢 Display %u is allowed display - no dock blocking", displayID);
                free(displays);
                return NO;
            }
            
            CGFloat distanceFromBottom = bottomEdgeY - mouseLocation.y;
            CGFloat relativeThreshold = displayBounds.size.height * (self.bottomEdgeThresholdPercent / 100.0);
            
            DockGuardLog(@"📐 Display %u - Distance to bottom: %.1f pixels", displayID, distanceFromBottom);
            DockGuardLog(@"📊 Display %u - Relative threshold: %.1f pixels (%.1f%% of %.0f pixel height)", 
                  displayID, relativeThreshold, self.bottomEdgeThresholdPercent, displayBounds.size.height);
            
            CGFloat thresholdY = bottomEdgeY - relativeThreshold;
            
            if (mouseLocation.y >= thresholdY) {
                DockGuardLog(@"🚨 *** Extended bottom area detected! *** Dock trigger prevention active in entire area below threshold (%.1f) on Display %u", 
                      thresholdY, displayID);
                free(displays);
                return YES;
            } else {
                DockGuardLog(@"🟡 Not in extended bottom area on Display %u - no dock blocking", displayID);
                free(displays);
                return NO;
            }
        } else {
            DockGuardLog(@"⚪ Mouse is outside Display %u area", displayID);
        }
    }
    
    free(displays);
    DockGuardLog(@"❓ Mouse is not on any detected display - no dock blocking");
    return NO;
}

- (NSSet<NSNumber *> *)loadAllowedDisplays {
    NSArray *arr = [[NSUserDefaults standardUserDefaults] arrayForKey:@"AllowedDisplayIDs"] ?: @[];
    return [NSSet setWithArray:arr];
}

- (BOOL)start {
    if (self.isMonitoring) {
        DockGuardLog(@"Already running, ignoring start request");
        return YES;
    }
    
    self.allowedDisplays = [self loadAllowedDisplays];
    
    DockGuardLog(@"Starting intelligent dock trigger prevention. Allowed displays: %@", self.allowedDisplays);
    DockGuardLog(@"Available displays:");
    for (NSScreen *screen in [NSScreen screens]) {
        NSNumber *screenNumber = screen.deviceDescription[@"NSScreenNumber"];
        uint32_t displayID = (uint32_t)screenNumber.unsignedIntValue;
        BOOL isAllowed = [self.allowedDisplays containsObject:@(displayID)];
        NSRect frame = screen.frame;
        DockGuardLog(@"  Display %u: %@ (frame: %.0f,%.0f %.0fx%.0f)", 
              displayID, isAllowed ? @"DOCK_ALLOWED" : @"DOCK_PREVENTED", 
              frame.origin.x, frame.origin.y, frame.size.width, frame.size.height);
    }
    
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
    
    DockGuardLog(@"Stopped intelligent dock trigger prevention");
}

- (void)dealloc {
    [self stop];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
