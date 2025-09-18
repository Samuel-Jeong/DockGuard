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
        
        DockGuardLog(@"🖥️  Display %u - Quartz 좌표: (%.0f,%.0f) %.0fx%.0f", 
              displayID, displayBounds.origin.x, displayBounds.origin.y, displayBounds.size.width, displayBounds.size.height);
        
        CGFloat bottomEdgeY = displayBounds.origin.y + displayBounds.size.height;
        DockGuardLog(@"📍 Display %u - 하단 가장자리 Y좌표: %.1f", displayID, bottomEdgeY);
        
        if (CGRectContainsPoint(displayBounds, mouseLocation)) {
            BOOL isAllowed = [self.allowedDisplays containsObject:@(displayID)];
            
            DockGuardLog(@"✅ 마우스가 Display %u 위에 있음: %@", 
                  displayID, isAllowed ? @"독 허용됨" : @"독 차단됨");
            
            if (isAllowed) {
                DockGuardLog(@"🟢 Display %u는 허용된 디스플레이 - 독 차단 안함", displayID);
                free(displays);
                return NO;
            }
            
            CGFloat distanceFromBottom = bottomEdgeY - mouseLocation.y;
            CGFloat relativeThreshold = displayBounds.size.height * (self.bottomEdgeThresholdPercent / 100.0);
            
            DockGuardLog(@"📐 Display %u - 하단까지 거리: %.1f픽셀", displayID, distanceFromBottom);
            DockGuardLog(@"📊 Display %u - 상대적 임계값: %.1f픽셀 (%.1f%% of %.0f픽셀 높이)", 
                  displayID, relativeThreshold, self.bottomEdgeThresholdPercent, displayBounds.size.height);
            
            CGFloat thresholdY = bottomEdgeY - relativeThreshold;
            
            if (mouseLocation.y >= thresholdY) {
                DockGuardLog(@"🚨 *** 확장된 하단 영역 감지! *** Display %u에서 임계점(%.1f) 이하 전체 영역에서 독 트리거 방지 작동", 
                      displayID, thresholdY);
                free(displays);
                return YES;
            } else {
                DockGuardLog(@"🟡 Display %u에서 확장된 하단 영역이 아님 - 독 차단 안함", displayID);
                free(displays);
                return NO;
            }
        } else {
            DockGuardLog(@"⚪ 마우스가 Display %u 영역 밖에 있음", displayID);
        }
    }
    
    free(displays);
    DockGuardLog(@"❓ 마우스가 감지된 디스플레이 위에 없음 - 독 차단 안함");
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