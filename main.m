#import <Cocoa/Cocoa.h>
#import "AppDelegate.h"

// Global debug flag - accessible throughout the application
BOOL gDebugMode = NO;

int main(int argc, const char * argv[]) {
    @autoreleasepool {
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
