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
    NSRect frame = NSMakeRect(0, 0, 420, 360);
    self.prefsWindow = [[NSWindow alloc] initWithContentRect:frame
                                                   styleMask:(NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskMiniaturizable)
                                                     backing:NSBackingStoreBuffered defer:NO];
    self.prefsWindow.title = @"DockGuard Preferences";
    self.prefsWindow.level = NSFloatingWindowLevel; // Make window stay on top
    NSView *content = self.prefsWindow.contentView;

    // Create tab view
    NSTabView *tabView = [[NSTabView alloc] initWithFrame:NSMakeRect(10, 10, 400, 340)];
    
    // CONTROL Tab
    NSTabViewItem *controlTab = [[NSTabViewItem alloc] initWithIdentifier:@"control"];
    controlTab.label = @"CONTROL";
    NSView *controlView = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 400, 310)];

    NSScrollView *scrollView = [[NSScrollView alloc] initWithFrame:NSMakeRect(10, 60, 380, 220)];
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

    NSTextField *hint = [[NSTextField alloc] initWithFrame:NSMakeRect(10, 285, 380, 24)];
    hint.editable = NO; hint.bezeled = NO; hint.drawsBackground = NO;

    // Launch at Login checkbox
    self.launchAtLoginCheck = [[NSButton alloc] initWithFrame:NSMakeRect(10, 20, 220, 24)];
    self.launchAtLoginCheck.buttonType = NSButtonTypeSwitch;
    self.launchAtLoginCheck.title = @"로그인 시 자동 실행";
    self.launchAtLoginCheck.target = self;
    self.launchAtLoginCheck.action = @selector(toggleLaunchAtLogin:);
    self.launchAtLoginCheck.state = [self isLaunchAgentInstalled] ? NSControlStateValueOn : NSControlStateValueOff;

    self.startButton = [[NSButton alloc] initWithFrame:NSMakeRect(290, 20, 100, 30)];
    self.startButton.title = @"Start";
    self.startButton.bezelStyle = NSBezelStyleRounded;
    self.startButton.target = self;
    self.startButton.action = @selector(startClicked);

    [controlView addSubview:hint];
    [controlView addSubview:scrollView];
    [controlView addSubview:self.launchAtLoginCheck];
    [controlView addSubview:self.startButton];
    
    controlTab.view = controlView;
    [tabView addTabViewItem:controlTab];

    // HELP Tab
    NSTabViewItem *helpTab = [[NSTabViewItem alloc] initWithIdentifier:@"help"];
    helpTab.label = @"HELP";
    NSView *helpView = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 400, 310)];

    // License info
    NSTextField *licenseTitle = [[NSTextField alloc] initWithFrame:NSMakeRect(20, 260, 360, 20)];
    licenseTitle.editable = NO; licenseTitle.bezeled = NO; licenseTitle.drawsBackground = NO;
    licenseTitle.font = [NSFont boldSystemFontOfSize:14];
    licenseTitle.stringValue = @"License Information";

    NSScrollView *licenseScrollView = [[NSScrollView alloc] initWithFrame:NSMakeRect(20, 120, 360, 130)];
    NSTextView *licenseTextView = [[NSTextView alloc] initWithFrame:licenseScrollView.bounds];
    licenseTextView.editable = NO;
    licenseTextView.string = @"This project is licensed under the Creative Commons Attribution-NonCommercial 4.0 International License (CC BY-NC 4.0).\n\nSee https://creativecommons.org/licenses/by-nc/4.0/";
    licenseScrollView.documentView = licenseTextView;
    licenseScrollView.hasVerticalScroller = YES;

    // Contact info
    NSTextField *contactTitle = [[NSTextField alloc] initWithFrame:NSMakeRect(20, 80, 360, 20)];
    contactTitle.editable = NO; contactTitle.bezeled = NO; contactTitle.drawsBackground = NO;
    contactTitle.font = [NSFont boldSystemFontOfSize:14];
    contactTitle.stringValue = @"Contact Information";

    NSTextField *contactEmail = [[NSTextField alloc] initWithFrame:NSMakeRect(20, 50, 360, 20)];
    contactEmail.editable = NO; contactEmail.bezeled = NO; contactEmail.drawsBackground = NO;
    contactEmail.stringValue = @"Email: ehddnr177@naver.com";

    [helpView addSubview:licenseTitle];
    [helpView addSubview:licenseScrollView];
    [helpView addSubview:contactTitle];
    [helpView addSubview:contactEmail];

    helpTab.view = helpView;
    [tabView addTabViewItem:helpTab];

    [content addSubview:tabView];

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
