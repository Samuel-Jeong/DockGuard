#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>

@interface MouseMonitor : NSObject
- (BOOL)start;
- (void)stop;
- (BOOL)shouldBlockMouseAtLocation:(CGPoint)mouseLocation;
@end
