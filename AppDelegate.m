#import "AppDelegate.h"
#import "DisplayPreferencesController.h"
#import "MouseMonitor.h"
#import <ApplicationServices/ApplicationServices.h>

@interface AppDelegate ()
@property (strong) NSStatusItem *statusItem;
@property (strong) DisplayPreferencesController *prefsController;
@property (strong) MouseMonitor *mouseMonitor;
@property (strong) NSMenuItem *toggleMenuItem;
@property (strong) NSMenuItem *statusMenuItem;
@property (strong) NSTimer *displayIndicatorTimer;
@property (strong) NSImage *baseStatusIcon;
@property (assign) CGDirectDisplayID lastIndicatorDisplayID;
@property (assign) BOOL lastIndicatorAllowed;
@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    [self setupStatusItem];
    // Don't force accessibility permission check at launch - only when needed
    self.prefsController = [[DisplayPreferencesController alloc] init];
    __weak typeof(self) weakSelf = self;
    self.prefsController.onStartMonitoring = ^{
        [weakSelf startMonitoring];
    };

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(preferencesChanged)
                                                 name:@"PreferencesChanged"
                                               object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(allowedDisplaysChanged)
                                                 name:@"AllowedDisplaysChanged"
                                               object:nil];

    [self updateStatusMenuItem];
    [self updateStatusItemDisplayIndicatorIfNeeded];
    [self.prefsController showWindow:nil];
}

- (void)setupStatusItem {
    self.statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSSquareStatusItemLength];
    self.baseStatusIcon = [NSImage imageNamed:@"DockGuard"];
    if (self.baseStatusIcon) {
        [self.baseStatusIcon setSize:NSMakeSize(18, 18)];
        self.statusItem.button.image = self.baseStatusIcon;
    } else {
        self.statusItem.button.title = @"🧲"; // fallback icon
    }
    NSMenu *menu = [[NSMenu alloc] initWithTitle:@"DockGuard"];

    self.statusMenuItem = [[NSMenuItem alloc] initWithTitle:@"Protection: Off" action:nil keyEquivalent:@""];
    self.statusMenuItem.enabled = NO;
    [menu addItem:self.statusMenuItem];
    [menu addItem:[NSMenuItem separatorItem]];

    self.toggleMenuItem = [[NSMenuItem alloc] initWithTitle:@"Start Protection" action:@selector(toggleMonitoring) keyEquivalent:@"s"]; // toggles start/stop
    [menu addItem:self.toggleMenuItem];
    [menu addItem:[NSMenuItem separatorItem]];
    [menu addItemWithTitle:@"Preferences" action:@selector(openPreferences) keyEquivalent:@","]; 
    [menu addItem:[NSMenuItem separatorItem]];
    [menu addItemWithTitle:@"Quit" action:@selector(quitApp) keyEquivalent:@"q"];
    self.statusItem.menu = menu;

    self.lastIndicatorDisplayID = 0;
    self.lastIndicatorAllowed = NO;

    // Polling is simple/reliable for “current display under mouse” without requiring extra event taps.
    self.displayIndicatorTimer = [NSTimer scheduledTimerWithTimeInterval:0.2
                                                                  target:self
                                                                selector:@selector(updateStatusItemDisplayIndicatorIfNeeded)
                                                                userInfo:nil
                                                                 repeats:YES];
}

- (void)preferencesChanged {
    [self updateStatusMenuItem];
    [self updateStatusItemDisplayIndicatorIfNeeded];
}

- (void)allowedDisplaysChanged {
    [self updateStatusItemDisplayIndicatorIfNeeded];
}

- (CGDirectDisplayID)displayIDForCurrentMouseLocation {
    CGEventRef e = CGEventCreate(NULL);
    if (!e) {
        return 0;
    }
    CGPoint p = CGEventGetLocation(e);
    CFRelease(e);

    uint32_t count = 0;
    if (CGGetActiveDisplayList(0, NULL, &count) != kCGErrorSuccess || count == 0) {
        return 0;
    }
    CGDirectDisplayID displays[32];
    uint32_t max = (count > 32) ? 32 : count;
    if (CGGetActiveDisplayList(max, displays, &count) != kCGErrorSuccess) {
        return 0;
    }

    for (uint32_t i = 0; i < count; i++) {
        CGDirectDisplayID did = displays[i];
        CGRect b = CGDisplayBounds(did);
        if (CGRectContainsPoint(b, p)) {
            return did;
        }
    }
    return 0;
}

- (BOOL)isDisplayAllowed:(CGDirectDisplayID)displayID {
    if (displayID == 0) {
        return NO;
    }
    NSArray *allowedIDs = [[NSUserDefaults standardUserDefaults] arrayForKey:@"AllowedDisplayIDs"] ?: @[];
    for (id v in allowedIDs) {
        if ([v respondsToSelector:@selector(unsignedIntValue)] && (CGDirectDisplayID)[v unsignedIntValue] == displayID) {
            return YES;
        }
    }
    return NO;
}

- (NSImage *)statusIconWithBadgeAllowed:(BOOL)allowed {
    if (!self.baseStatusIcon) {
        return nil;
    }

    NSSize size = NSMakeSize(18, 18);
    NSImage *img = [[NSImage alloc] initWithSize:size];
    [img lockFocus];

    // Base icon
    [self.baseStatusIcon drawInRect:NSMakeRect(0, 0, size.width, size.height)
                           fromRect:NSZeroRect
                          operation:NSCompositingOperationSourceOver
                           fraction:1.0];

    // Badge dot (bottom-right)
    CGFloat r = 3.5;
    CGFloat pad = 1.3;
    NSRect dotRect = NSMakeRect(size.width - pad - (r * 2.0), pad, r * 2.0, r * 2.0);

    NSBezierPath *dot = [NSBezierPath bezierPathWithOvalInRect:dotRect];
    NSColor *fill = allowed ? [NSColor systemGreenColor] : [NSColor systemRedColor];
    [fill setFill];
    [dot fill];

    [[NSColor colorWithWhite:0 alpha:0.35] setStroke];
    dot.lineWidth = 0.7;
    [dot stroke];

    [img unlockFocus];
    return img;
}

- (void)updateStatusItemDisplayIndicatorIfNeeded {
    if (!self.statusItem || !self.statusItem.button) {
        return;
    }

    CGDirectDisplayID did = [self displayIDForCurrentMouseLocation];
    BOOL allowed = [self isDisplayAllowed:did];

    if (did == self.lastIndicatorDisplayID && allowed == self.lastIndicatorAllowed) {
        return;
    }
    self.lastIndicatorDisplayID = did;
    self.lastIndicatorAllowed = allowed;

    NSImage *badged = [self statusIconWithBadgeAllowed:allowed];
    if (badged) {
        self.statusItem.button.image = badged;
        self.statusItem.button.title = @"";
    } else {
        // Fallback when no image resource is available
        self.statusItem.button.title = allowed ? @"A" : @"P";
    }
}

- (void)updateStatusMenuItem {
    BOOL showStatus = [[NSUserDefaults standardUserDefaults] boolForKey:@"ShowStatusInMenu"];
    if (!showStatus) {
        if (self.statusMenuItem && self.statusItem.menu) {
            NSInteger idx = [self.statusItem.menu indexOfItem:self.statusMenuItem];
            if (idx != -1) {
                [self.statusItem.menu removeItemAtIndex:idx];
                // Remove the separator right after it if present
                if (self.statusItem.menu.numberOfItems > 0) {
                    NSMenuItem *first = [self.statusItem.menu itemAtIndex:0];
                    if (first.isSeparatorItem) {
                        [self.statusItem.menu removeItemAtIndex:0];
                    }
                }
            }
        }
        return;
    }

    if (self.statusMenuItem && self.statusItem.menu) {
        if ([self.statusItem.menu indexOfItem:self.statusMenuItem] == -1) {
            [self.statusItem.menu insertItem:self.statusMenuItem atIndex:0];
            [self.statusItem.menu insertItem:[NSMenuItem separatorItem] atIndex:1];
        }
        self.statusMenuItem.title = self.mouseMonitor ? @"Protection: On" : @"Protection: Off";
    }
}

- (void)openPreferences {
    [self.prefsController showWindow:nil];
    [NSApp activateIgnoringOtherApps:YES];
}

- (void)quitApp {
    [NSApp terminate:nil];
}

- (void)ensureAccessibilityPermission {
    const void* keys[] = { kAXTrustedCheckOptionPrompt };
    const void* values[] = { kCFBooleanTrue };
    CFDictionaryRef options = CFDictionaryCreate(kCFAllocatorDefault, keys, values, 1, NULL, NULL);
    Boolean trusted = AXIsProcessTrustedWithOptions(options);
    if (options) CFRelease(options);
    if (!trusted) {
        NSAlert *alert = [[NSAlert alloc] init];
        alert.messageText = @"Accessibility Permission Required";
        alert.informativeText = @"DockGuard needs Accessibility permission to monitor the mouse. Please grant access in System Settings > Privacy & Security > Accessibility.";
        NSImage *appIcon = [NSImage imageNamed:@"DockGuard"];
        if (appIcon) {
            alert.icon = appIcon;
        }
        [alert addButtonWithTitle:@"Open Settings"];
        [alert addButtonWithTitle:@"Later"];
        NSModalResponse resp = [alert runModal];
        if (resp == NSAlertFirstButtonReturn) {
            [self openAccessibilityPreferences];
        }
    }
}

- (void)openAccessibilityPreferences {
    NSURL *url = [NSURL URLWithString:@"x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"]; // macOS Ventura+
    if (url) {
        [[NSWorkspace sharedWorkspace] openURL:url];
    }
}

- (void)toggleMonitoring {
    if (self.mouseMonitor) {
        [self stopMonitoring];
    } else {
        [self startMonitoring];
    }
}

- (void)startMonitoring {
    // Check accessibility permission only when user wants to start monitoring
    const void* keys[] = { kAXTrustedCheckOptionPrompt };
    const void* values[] = { kCFBooleanFalse }; // Don't show system prompt automatically
    CFDictionaryRef options = CFDictionaryCreate(kCFAllocatorDefault, keys, values, 1, NULL, NULL);
    Boolean trusted = AXIsProcessTrustedWithOptions(options);
    if (options) CFRelease(options);
    
    if (!trusted) {
        NSAlert *alert = [[NSAlert alloc] init];
        alert.messageText = @"Accessibility Permission Required";
        alert.informativeText = @"DockGuard needs Accessibility permission to monitor the mouse and prevent accidental dock triggers. This is only required when protection is active.";
        NSImage *appIcon = [NSImage imageNamed:@"DockGuard"];
        if (appIcon) {
            alert.icon = appIcon;
        }
        [alert addButtonWithTitle:@"Open Settings"];
        [alert addButtonWithTitle:@"Cancel"];
        NSModalResponse resp = [alert runModal];
        if (resp == NSAlertFirstButtonReturn) {
            [self openAccessibilityPreferences];
        }
        return; // Don't start monitoring without permission
    }
    
    if (!self.mouseMonitor) {
        self.mouseMonitor = [[MouseMonitor alloc] init];
    }
    BOOL success = [self.mouseMonitor start];
    if (success) {
        if (self.toggleMenuItem) self.toggleMenuItem.title = @"Pause Protection";
        [self updateStatusMenuItem];
    } else {
        // If start failed, clean up and show error
        self.mouseMonitor = nil;
        NSAlert *alert = [[NSAlert alloc] init];
        alert.messageText = @"Failed to Start Protection";
        alert.informativeText = @"DockGuard could not start monitoring. Please make sure Accessibility permission is granted in System Settings > Privacy & Security > Accessibility.";
        NSImage *appIcon = [NSImage imageNamed:@"DockGuard"];
        if (appIcon) {
            alert.icon = appIcon;
        }
        [alert addButtonWithTitle:@"Open Settings"];
        [alert addButtonWithTitle:@"OK"];
        NSModalResponse resp = [alert runModal];
        if (resp == NSAlertFirstButtonReturn) {
            [self openAccessibilityPreferences];
        }
    }
}

- (void)stopMonitoring {
    if (self.mouseMonitor) {
        [self.mouseMonitor stop];
        self.mouseMonitor = nil;
    }
    if (self.toggleMenuItem) self.toggleMenuItem.title = @"Start Protection";
    [self updateStatusMenuItem];
}

- (void)dealloc {
    [self.displayIndicatorTimer invalidate];
    self.displayIndicatorTimer = nil;
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
