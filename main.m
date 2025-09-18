#import <Cocoa/Cocoa.h>
#import "AppDelegate.h"

// Global debug flag - accessible throughout the application
BOOL gDebugMode = NO;

// Function to check if another instance of DockGuard is already running
BOOL isAnotherInstanceRunning() {
    NSString *bundleIdentifier = [[NSBundle mainBundle] bundleIdentifier];
    if (!bundleIdentifier) {
        bundleIdentifier = @"org.samuel.DockGuard"; // fallback identifier
    }
    
    NSArray *runningApps = [NSRunningApplication runningApplicationsWithBundleIdentifier:bundleIdentifier];
    
    // If more than one instance is running (current instance + another), return YES
    return [runningApps count] > 1;
}

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        // Check for duplicate execution before initializing the application
        if (isAnotherInstanceRunning()) {
            printf("[DockGuard] Another instance of DockGuard is already running. Exiting.\n");
            
            // Show alert to user about duplicate execution
            NSAlert *alert = [[NSAlert alloc] init];
            alert.messageText = @"DockGuard is already running";
            alert.informativeText = @"Another instance of DockGuard is already running. Please use the existing instance in the menu bar.";
            NSImage *appIcon = [NSImage imageNamed:@"DockGuard"];
            if (appIcon) {
                alert.icon = appIcon;
            }
            [alert addButtonWithTitle:@"OK"];
            alert.alertStyle = NSAlertStyleInformational;
            [alert runModal];
            
            return 1; // Exit with error code
        }
        
        // Parse command line arguments for debug flag
        for (int i = 1; i < argc; i++) {
            NSString *arg = [NSString stringWithUTF8String:argv[i]];
            if ([arg isEqualToString:@"--debug"] || [arg isEqualToString:@"-d"]) {
                gDebugMode = YES;
                printf("[DockGuard] Debug mode enabled via command line argument\n");
                break;
            }
        }
        
        NSApplication *app = [NSApplication sharedApplication];
        AppDelegate *delegate = [[AppDelegate alloc] init];
        [app setDelegate:delegate];
        return NSApplicationMain(argc, argv);
    }
}
