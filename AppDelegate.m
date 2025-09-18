#import "AppDelegate.h"
#import "DisplayPreferencesController.h"
#import "MouseMonitor.h"
#import <ApplicationServices/ApplicationServices.h>

@interface AppDelegate ()
@property (strong) NSStatusItem *statusItem;
@property (strong) DisplayPreferencesController *prefsController;
@property (strong) MouseMonitor *mouseMonitor;
@property (strong) NSMenuItem *toggleMenuItem;
@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    [self setupStatusItem];
    [self ensureAccessibilityPermission];
    self.prefsController = [[DisplayPreferencesController alloc] init];
    __weak typeof(self) weakSelf = self;
    self.prefsController.onStartMonitoring = ^{
        [weakSelf startMonitoring];
    };
    [self.prefsController showWindow:nil];
}

- (void)setupStatusItem {
    self.statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSSquareStatusItemLength];
    self.statusItem.button.title = @"🧲"; // simple icon
    NSMenu *menu = [[NSMenu alloc] initWithTitle:@"DockGuard"];
    self.toggleMenuItem = [[NSMenuItem alloc] initWithTitle:@"Start Protection" action:@selector(toggleMonitoring) keyEquivalent:@"s"]; // toggles start/stop
    [menu addItem:self.toggleMenuItem];
    [menu addItem:[NSMenuItem separatorItem]];
    [menu addItemWithTitle:@"Preferences" action:@selector(openPreferences) keyEquivalent:@","]; 
    [menu addItem:[NSMenuItem separatorItem]];
    [menu addItemWithTitle:@"Quit" action:@selector(quitApp) keyEquivalent:@"q"];
    self.statusItem.menu = menu;
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
    if (!self.mouseMonitor) {
        self.mouseMonitor = [[MouseMonitor alloc] init];
    }
    [self.mouseMonitor start];
    if (self.toggleMenuItem) self.toggleMenuItem.title = @"Pause Protection";
}

- (void)stopMonitoring {
    if (self.mouseMonitor) {
        [self.mouseMonitor stop];
        self.mouseMonitor = nil;
    }
    if (self.toggleMenuItem) self.toggleMenuItem.title = @"Start Protection";
}

@end
