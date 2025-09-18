#import "DisplayPreferencesController.h"
#import <ApplicationServices/ApplicationServices.h>

@implementation DisplayInfo
@end

@interface DisplayPreferencesController ()
@property (strong) NSWindow *prefsWindow;
@property (strong) NSTableView *tableView;
@property (strong) NSButton *startButton;
@property (strong) NSButton *launchAtLoginCheck;
@property (strong) NSMutableArray<DisplayInfo *> *displays;
@end

@implementation DisplayPreferencesController

#pragma mark - Launch at Login (LaunchAgent)

- (NSString *)launchAgentPlistPath {
    NSString *home = NSHomeDirectory();
    NSString *dir = [home stringByAppendingPathComponent:@"Library/LaunchAgents"];
    [[NSFileManager defaultManager] createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
    return [dir stringByAppendingPathComponent:@"org.samuel.DockGuard.launcher.plist"];
}

- (BOOL)isLaunchAgentInstalled {
    return [[NSFileManager defaultManager] fileExistsAtPath:[self launchAgentPlistPath]];
}

- (void)installLaunchAgent {
    NSString *bundlePath = [[NSBundle mainBundle] bundlePath];
    NSDictionary *plist = @{ 
        @"Label": @"org.samuel.DockGuard.launcher",
        @"RunAtLoad": @YES,
        @"KeepAlive": @NO,
        @"LimitLoadToSessionType": @"Aqua",
        @"ProgramArguments": @[ @"/usr/bin/open", @"-a", bundlePath ]
    };
    NSData *data = [NSPropertyListSerialization dataWithPropertyList:plist format:NSPropertyListXMLFormat_v1_0 options:0 error:nil];
    if (data) {
        [data writeToFile:[self launchAgentPlistPath] atomically:YES];
    }
    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"LaunchAtLogin"];
}

- (void)removeLaunchAgent {
    NSString *path = [self launchAgentPlistPath];
    if ([[NSFileManager defaultManager] fileExistsAtPath:path]) {
        [[NSFileManager defaultManager] removeItemAtPath:path error:nil];
    }
    [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"LaunchAtLogin"];
}

- (void)toggleLaunchAtLogin:(NSButton *)sender {
    if (sender.state == NSControlStateValueOn) {
        [self installLaunchAgent];
    } else {
        [self removeLaunchAgent];
    }
}

- (instancetype)init {
    self = [super initWithWindow:nil];
    if (self) {
        [self buildUI];
        [self reloadDisplays];
    }
    return self;
}

- (void)buildUI {
    NSRect frame = NSMakeRect(0, 0, 420, 320);
    self.prefsWindow = [[NSWindow alloc] initWithContentRect:frame
                                                   styleMask:(NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskMiniaturizable)
                                                     backing:NSBackingStoreBuffered defer:NO];
    self.prefsWindow.title = @"DockGuard Preferences";
    NSView *content = self.prefsWindow.contentView;

    NSScrollView *scrollView = [[NSScrollView alloc] initWithFrame:NSMakeRect(20, 60, 380, 220)];
    self.tableView = [[NSTableView alloc] initWithFrame:scrollView.bounds];

    NSTableColumn *col1 = [[NSTableColumn alloc] initWithIdentifier:@"allowed"];
    col1.title = @"Allow Dock float";
    col1.width = 150;
    [self.tableView addTableColumn:col1];

    NSTableColumn *col2 = [[NSTableColumn alloc] initWithIdentifier:@"name"];
    col2.title = @"Display";
    col2.width = 220;
    [self.tableView addTableColumn:col2];

    self.tableView.delegate = self;
    self.tableView.dataSource = self;

    scrollView.documentView = self.tableView;
    scrollView.hasVerticalScroller = YES;

    NSTextField *hint = [[NSTextField alloc] initWithFrame:NSMakeRect(20, 285, 380, 24)];
    hint.editable = NO; hint.bezeled = NO; hint.drawsBackground = NO;
    hint.stringValue = @"체크된 디스플레이에서는 하단에 마우스를 두면 Dock 이 나타납니다.";

    // Launch at Login checkbox
    self.launchAtLoginCheck = [[NSButton alloc] initWithFrame:NSMakeRect(20, 20, 220, 24)];
    self.launchAtLoginCheck.buttonType = NSButtonTypeSwitch;
    self.launchAtLoginCheck.title = @"로그인 시 자동 실행";
    self.launchAtLoginCheck.target = self;
    self.launchAtLoginCheck.action = @selector(toggleLaunchAtLogin:);
    self.launchAtLoginCheck.state = [self isLaunchAgentInstalled] ? NSControlStateValueOn : NSControlStateValueOff;

    self.startButton = [[NSButton alloc] initWithFrame:NSMakeRect(300, 20, 100, 30)];
    self.startButton.title = @"Start";
    self.startButton.bezelStyle = NSBezelStyleRounded;
    self.startButton.target = self;
    self.startButton.action = @selector(startClicked);

    [content addSubview:hint];
    [content addSubview:scrollView];
    [content addSubview:self.launchAtLoginCheck];
    [content addSubview:self.startButton];

    self.window = self.prefsWindow;
}

- (void)showWindow:(id)sender {
    [super showWindow:sender];
    [self.window center];
}

- (void)reloadDisplays {
    self.displays = [NSMutableArray array];

    NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
    NSArray *allowedIDs = [defs arrayForKey:@"AllowedDisplayIDs"] ?: @[];
    NSSet *allowedSet = [NSSet setWithArray:allowedIDs];

    for (NSScreen *screen in [NSScreen screens]) {
        NSNumber *num = screen.deviceDescription[@"NSScreenNumber"];
        uint32_t did = (uint32_t)num.unsignedIntValue;
        NSString *name = nil;
        if (@available(macOS 10.15, *)) {
            name = screen.localizedName;
        }
        if (name.length == 0) {
            name = [NSString stringWithFormat:@"Display %u", did];
        }
        DisplayInfo *info = [DisplayInfo new];
        info.displayID = did;
        info.name = name;
        info.allowed = [allowedSet containsObject:@(did)];
        [self.displays addObject:info];
    }

    [self.tableView reloadData];
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    return self.displays.count;
}

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    DisplayInfo *info = self.displays[row];
    if ([tableColumn.identifier isEqualToString:@"allowed"]) {
        NSButton *check = [tableView makeViewWithIdentifier:@"check" owner:self];
        if (!check) {
            check = [[NSButton alloc] initWithFrame:NSMakeRect(0, 0, 140, 20)];
            check.buttonType = NSButtonTypeSwitch;
            check.title = @"허용";
            check.identifier = @"check";
            check.target = self;
            check.action = @selector(toggleAllowed:);
        }
        check.tag = (NSInteger)row;
        check.state = info.allowed ? NSControlStateValueOn : NSControlStateValueOff;
        return check;
    } else {
        NSTableCellView *cell = [tableView makeViewWithIdentifier:@"name" owner:self];
        if (!cell) {
            cell = [[NSTableCellView alloc] initWithFrame:NSMakeRect(0, 0, 200, 20)];
            NSTextField *text = [[NSTextField alloc] initWithFrame:cell.bounds];
            text.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
            text.bezeled = NO; text.drawsBackground = NO; text.editable = NO; text.selectable = NO;
            text.tag = 1001;
            [cell addSubview:text];
            cell.identifier = @"name";
        }
        NSTextField *text = [cell viewWithTag:1001];
        text.stringValue = info.name ?: @"(이름 없음)";
        return cell;
    }
}

- (void)toggleAllowed:(NSButton *)sender {
    NSInteger row = sender.tag;
    if (row >= 0 && row < self.displays.count) {
        DisplayInfo *info = self.displays[row];
        info.allowed = (sender.state == NSControlStateValueOn);
        [self saveSelection];
    }
}

- (void)saveSelection {
    NSMutableArray *arr = [NSMutableArray array];
    for (DisplayInfo *info in self.displays) {
        if (info.allowed) {
            [arr addObject:@(info.displayID)];
        }
    }
    [[NSUserDefaults standardUserDefaults] setObject:arr forKey:@"AllowedDisplayIDs"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"AllowedDisplaysChanged" object:nil];
}

- (void)startClicked {
    [self saveSelection];
    if (self.onStartMonitoring) self.onStartMonitoring();
    [self.window orderOut:nil];
}

@end
