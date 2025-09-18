#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>

@interface MouseMonitor : NSObject
- (void)start;
- (void)stop;
- (BOOL)shouldBlockMouseAtLocation:(CGPoint)mouseLocation;
@end
