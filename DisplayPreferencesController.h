#import <Cocoa/Cocoa.h>

@interface DisplayInfo : NSObject
@property (assign) uint32_t displayID;
@property (copy) NSString *name;
@property (assign) BOOL allowed; // whether Dock floating is allowed on this display
@end

@interface DisplayPreferencesController : NSWindowController <NSTableViewDataSource, NSTableViewDelegate>
@property (copy) void (^onStartMonitoring)(void);
@end
