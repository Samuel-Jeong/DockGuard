#import "DisplayPreferencesController.h"
#import <ApplicationServices/ApplicationServices.h>

@implementation DisplayInfo
@end

@interface DisplayPreferencesController ()
@property (strong) NSWindow *prefsWindow;
@property (strong) NSTableView *tableView;
@property (strong) NSButton *startButton;
@property (strong) NSButton *launchAtLoginCheck;
@property (strong) NSButton *showStatusInMenuCheck;
@property (strong) NSTextField *ignoredAppsField;
@property (strong) NSSlider *sensitivitySlider;
@property (strong) NSTextField *sensitivityValueLabel;
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
    NSRect frame = NSMakeRect(0, 0, 520, 430);
    self.prefsWindow = [[NSWindow alloc] initWithContentRect:frame
                                                   styleMask:(NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskMiniaturizable)
                                                     backing:NSBackingStoreBuffered defer:NO];
    self.prefsWindow.title = @"DockGuard Preferences";
    self.prefsWindow.level = NSFloatingWindowLevel; // Make window stay on top
    NSView *content = self.prefsWindow.contentView;

    // Create tab view
    NSTabView *tabView = [[NSTabView alloc] initWithFrame:NSMakeRect(10, 10, 500, 410)];
    
    // CONTROL Tab
    NSTabViewItem *controlTab = [[NSTabViewItem alloc] initWithIdentifier:@"control"];
    controlTab.label = @"CONTROL";
    NSView *controlView = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 500, 380)];

    NSTextField *title = [[NSTextField alloc] initWithFrame:NSMakeRect(20, 340, 460, 22)];
    title.editable = NO; title.bezeled = NO; title.drawsBackground = NO;
    title.font = [NSFont boldSystemFontOfSize:14];
    title.stringValue = @"Dock trigger protection";

    NSTextField *subtitle = [[NSTextField alloc] initWithFrame:NSMakeRect(20, 318, 460, 18)];
    subtitle.editable = NO; subtitle.bezeled = NO; subtitle.drawsBackground = NO;
    subtitle.font = [NSFont systemFontOfSize:11];
    subtitle.textColor = [NSColor secondaryLabelColor];
    subtitle.stringValue = @"Select displays where Dock triggering is allowed. Other displays will be protected.";

    NSScrollView *scrollView = [[NSScrollView alloc] initWithFrame:NSMakeRect(20, 165, 460, 140)];
    self.tableView = [[NSTableView alloc] initWithFrame:scrollView.bounds];
    self.tableView.usesAlternatingRowBackgroundColors = YES;
    self.tableView.rowHeight = 24;

    NSTableColumn *col1 = [[NSTableColumn alloc] initWithIdentifier:@"allowed"];
    col1.title = @"Allowed";
    col1.width = 120;
    [self.tableView addTableColumn:col1];

    NSTableColumn *col2 = [[NSTableColumn alloc] initWithIdentifier:@"name"];
    col2.title = @"Display";
    col2.width = 320;
    [self.tableView addTableColumn:col2];

    self.tableView.delegate = self;
    self.tableView.dataSource = self;

    scrollView.documentView = self.tableView;
    scrollView.hasVerticalScroller = YES;
    scrollView.borderType = NSBezelBorder;

    // Sensitivity
    NSTextField *sensitivityLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(20, 130, 200, 18)];
    sensitivityLabel.editable = NO; sensitivityLabel.bezeled = NO; sensitivityLabel.drawsBackground = NO;
    sensitivityLabel.font = [NSFont systemFontOfSize:11];
    sensitivityLabel.textColor = [NSColor secondaryLabelColor];
    sensitivityLabel.stringValue = @"Sensitivity (bottom edge area)";

    self.sensitivitySlider = [[NSSlider alloc] initWithFrame:NSMakeRect(20, 108, 320, 20)];
    self.sensitivitySlider.minValue = 1.0;
    self.sensitivitySlider.maxValue = 20.0;
    self.sensitivitySlider.target = self;
    self.sensitivitySlider.action = @selector(sensitivityChanged:);

    self.sensitivityValueLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(350, 108, 130, 20)];
    self.sensitivityValueLabel.editable = NO;
    self.sensitivityValueLabel.bezeled = NO;
    self.sensitivityValueLabel.drawsBackground = NO;
    self.sensitivityValueLabel.alignment = NSTextAlignmentRight;

    NSNumber *savedSensitivity = [[NSUserDefaults standardUserDefaults] objectForKey:@"BottomEdgeThresholdPercent"];
    double sensitivity = savedSensitivity ? savedSensitivity.doubleValue : 8.0;
    self.sensitivitySlider.doubleValue = sensitivity;
    self.sensitivityValueLabel.stringValue = [NSString stringWithFormat:@"%.0f%%", sensitivity];

    // Menu status option
    self.showStatusInMenuCheck = [[NSButton alloc] initWithFrame:NSMakeRect(20, 78, 240, 20)];
    self.showStatusInMenuCheck.buttonType = NSButtonTypeSwitch;
    self.showStatusInMenuCheck.title = @"Show protection status in menu";
    self.showStatusInMenuCheck.target = self;
    self.showStatusInMenuCheck.action = @selector(toggleShowStatusInMenu:);
    BOOL showStatus = [[NSUserDefaults standardUserDefaults] boolForKey:@"ShowStatusInMenu"];
    self.showStatusInMenuCheck.state = showStatus ? NSControlStateValueOn : NSControlStateValueOff;

    // Ignored apps
    NSTextField *ignoredLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(20, 52, 460, 18)];
    ignoredLabel.editable = NO; ignoredLabel.bezeled = NO; ignoredLabel.drawsBackground = NO;
    ignoredLabel.font = [NSFont systemFontOfSize:11];
    ignoredLabel.textColor = [NSColor secondaryLabelColor];
    ignoredLabel.stringValue = @"Ignored apps (bundle identifiers, comma-separated)";

    self.ignoredAppsField = [[NSTextField alloc] initWithFrame:NSMakeRect(20, 30, 460, 22)];
    self.ignoredAppsField.placeholderString = @"e.g. com.apple.Terminal, com.apple.finder";
    self.ignoredAppsField.target = self;
    self.ignoredAppsField.action = @selector(ignoredAppsChanged:);
    NSArray *ignoredArr = [[NSUserDefaults standardUserDefaults] arrayForKey:@"IgnoredBundleIDs"] ?: @[];
    self.ignoredAppsField.stringValue = [ignoredArr componentsJoinedByString:@", "];

    // Launch at Login checkbox
    self.launchAtLoginCheck = [[NSButton alloc] initWithFrame:NSMakeRect(20, 5, 200, 24)];
    self.launchAtLoginCheck.buttonType = NSButtonTypeSwitch;
    self.launchAtLoginCheck.title = @"Launch at Login";
    self.launchAtLoginCheck.target = self;
    self.launchAtLoginCheck.action = @selector(toggleLaunchAtLogin:);
    self.launchAtLoginCheck.state = [self isLaunchAgentInstalled] ? NSControlStateValueOn : NSControlStateValueOff;

    self.startButton = [[NSButton alloc] initWithFrame:NSMakeRect(380, 4, 100, 30)];
    self.startButton.title = @"Apply";
    self.startButton.bezelStyle = NSBezelStyleRounded;
    self.startButton.target = self;
    self.startButton.action = @selector(startClicked);

    [controlView addSubview:title];
    [controlView addSubview:subtitle];
    [controlView addSubview:scrollView];
    [controlView addSubview:sensitivityLabel];
    [controlView addSubview:self.sensitivitySlider];
    [controlView addSubview:self.sensitivityValueLabel];
    [controlView addSubview:self.showStatusInMenuCheck];
    [controlView addSubview:ignoredLabel];
    [controlView addSubview:self.ignoredAppsField];
    [controlView addSubview:self.launchAtLoginCheck];
    [controlView addSubview:self.startButton];
    
    controlTab.view = controlView;
    [tabView addTabViewItem:controlTab];

    // HELP Tab
    NSTabViewItem *helpTab = [[NSTabViewItem alloc] initWithIdentifier:@"help"];
    helpTab.label = @"HELP";
    NSView *helpView = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 500, 380)];

    // License info
    NSTextField *licenseTitle = [[NSTextField alloc] initWithFrame:NSMakeRect(20, 330, 460, 20)];
    licenseTitle.editable = NO; licenseTitle.bezeled = NO; licenseTitle.drawsBackground = NO;
    licenseTitle.font = [NSFont boldSystemFontOfSize:14];
    licenseTitle.stringValue = @"License Information";

    NSScrollView *licenseScrollView = [[NSScrollView alloc] initWithFrame:NSMakeRect(20, 195, 460, 125)];
    NSTextView *licenseTextView = [[NSTextView alloc] initWithFrame:licenseScrollView.bounds];
    licenseTextView.editable = NO;
    licenseTextView.string = @"This project is licensed under the Creative Commons Attribution-NonCommercial 4.0 International License (CC BY-NC 4.0).\n\nSee https://creativecommons.org/licenses/by-nc/4.0/";
    licenseScrollView.documentView = licenseTextView;
    licenseScrollView.hasVerticalScroller = YES;
    licenseScrollView.borderType = NSBezelBorder;

    // Contact info
    NSTextField *contactTitle = [[NSTextField alloc] initWithFrame:NSMakeRect(20, 155, 460, 20)];
    contactTitle.editable = NO; contactTitle.bezeled = NO; contactTitle.drawsBackground = NO;
    contactTitle.font = [NSFont boldSystemFontOfSize:14];
    contactTitle.stringValue = @"Contact Information";

    NSTextField *contactEmail = [[NSTextField alloc] initWithFrame:NSMakeRect(20, 125, 460, 20)];
    contactEmail.editable = NO; contactEmail.bezeled = NO; contactEmail.drawsBackground = NO;
    contactEmail.stringValue = @"Email: ehddnr177@naver.com";

    NSTextField *versionLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(20, 85, 460, 20)];
    versionLabel.editable = NO; versionLabel.bezeled = NO; versionLabel.drawsBackground = NO;
    versionLabel.textColor = [NSColor secondaryLabelColor];
    NSString *version = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"] ?: @"";
    NSString *build = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"] ?: @"";
    versionLabel.stringValue = [NSString stringWithFormat:@"Version: %@ (%@)", version, build];

    [helpView addSubview:licenseTitle];
    [helpView addSubview:licenseScrollView];
    [helpView addSubview:contactTitle];
    [helpView addSubview:contactEmail];
    [helpView addSubview:versionLabel];

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
            check.title = @"Allow";
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
        text.stringValue = info.name ?: @"(No Name)";
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
    [[NSNotificationCenter defaultCenter] postNotificationName:@"PreferencesChanged" object:nil];
}

- (void)startClicked {
    [self saveSelection];
    if (self.onStartMonitoring) self.onStartMonitoring();
    [self.window orderOut:nil];
}

#pragma mark - New preference controls

- (void)sensitivityChanged:(NSSlider *)sender {
    double value = sender.doubleValue;
    self.sensitivityValueLabel.stringValue = [NSString stringWithFormat:@"%.0f%%", value];
    [[NSUserDefaults standardUserDefaults] setDouble:value forKey:@"BottomEdgeThresholdPercent"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"PreferencesChanged" object:nil];
}

- (void)toggleShowStatusInMenu:(NSButton *)sender {
    BOOL enabled = (sender.state == NSControlStateValueOn);
    [[NSUserDefaults standardUserDefaults] setBool:enabled forKey:@"ShowStatusInMenu"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"PreferencesChanged" object:nil];
}

- (void)ignoredAppsChanged:(NSTextField *)sender {
    NSString *raw = sender.stringValue ?: @"";
    NSArray<NSString *> *parts = [raw componentsSeparatedByString:@","];
    NSMutableArray<NSString *> *ids = [NSMutableArray array];
    for (NSString *p in parts) {
        NSString *trim = [p stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (trim.length > 0) {
            [ids addObject:trim];
        }
    }
    [[NSUserDefaults standardUserDefaults] setObject:ids forKey:@"IgnoredBundleIDs"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"PreferencesChanged" object:nil];
}

@end
