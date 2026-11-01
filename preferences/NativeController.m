#import <UIKit/UIKit.h>
#import <Preferences/PSViewController.h>
#import <CoreImage/CoreImage.h>
#import <CoreFoundation/CoreFoundation.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
#import "../compat/SettingsTransfer.h"
#import "../headers/Velvet2/Velvet2PrefsManager.h"
#import "LiquidGlassPreview.h"
#import "NumericSliderCell.h"
#import "../compat/TestBanner.h"
#import "../compat/NumericSetting.h"
#import "../headers/Velvet2/UIColor+Velvet.h"
#import "../compat/Runtime.h"
#import "../compat/SettingsStore.h"
#import "../compat/PaneModel.h"
#include <spawn.h>

static id managerValue(NSString *identifier, NSString *key);

// A child color editor in a height-limited sheet leaves the persistent
// SpringBoard banner unobstructed. UIKit owns its spectrum/grid controls.
@interface VLGColorEditorController : UIViewController
@property(nonatomic,strong) UIColorPickerViewController *picker;
@property(nonatomic,copy) void (^finished)(void);
@end
@implementation VLGColorEditorController
- (void)viewDidLoad {
    [super viewDidLoad];self.view.backgroundColor=UIColor.systemBackgroundColor;
    UIView *toolbar=[UIView new];toolbar.translatesAutoresizingMaskIntoConstraints=NO;[self.view addSubview:toolbar];
    UILabel *title=[UILabel new];title.text=self.title;title.font=[UIFont preferredFontForTextStyle:UIFontTextStyleHeadline];
    UIButton *done=[UIButton buttonWithType:UIButtonTypeSystem];[done setTitle:@"Done" forState:UIControlStateNormal];
    [done addTarget:self action:@selector(finish) forControlEvents:UIControlEventTouchUpInside];
    for(UIView *v in @[title,done]){v.translatesAutoresizingMaskIntoConstraints=NO;[toolbar addSubview:v];}
    [self addChildViewController:self.picker];UIView *editor=self.picker.view;editor.translatesAutoresizingMaskIntoConstraints=NO;
    [self.view addSubview:editor];[self.picker didMoveToParentViewController:self];
    [NSLayoutConstraint activateConstraints:@[[toolbar.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [toolbar.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],[toolbar.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [toolbar.heightAnchor constraintEqualToConstant:44],[title.leadingAnchor constraintEqualToAnchor:toolbar.leadingAnchor constant:20],
        [title.centerYAnchor constraintEqualToAnchor:toolbar.centerYAnchor],[done.trailingAnchor constraintEqualToAnchor:toolbar.trailingAnchor constant:-20],
        [done.topAnchor constraintEqualToAnchor:toolbar.topAnchor],[done.bottomAnchor constraintEqualToAnchor:toolbar.bottomAnchor],
        [done.widthAnchor constraintGreaterThanOrEqualToConstant:60],[title.trailingAnchor constraintLessThanOrEqualToAnchor:done.leadingAnchor constant:-8],
        [editor.topAnchor constraintEqualToAnchor:toolbar.bottomAnchor],[editor.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [editor.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],[editor.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor]]];
}
- (void)finish {if(self.finished)self.finished();}
@end

@interface V26PaneController : PSViewController <UITableViewDataSource, UITableViewDelegate, UIColorPickerViewControllerDelegate, UIAdaptivePresentationControllerDelegate, UIDocumentPickerDelegate>
@property(nonatomic, strong) UITableView *settingsTable;
@property(nonatomic, copy) NSString *pageName;
@property(nonatomic, copy) NSString *scopeIdentifier;
@property(nonatomic, copy) NSDictionary *resource;
@property(nonatomic, copy) NSArray<NSDictionary *> *groups;
@property(nonatomic, strong) VLGLivePreviewView *preview;
@property(nonatomic, strong) NSMutableDictionary *pendingNumbers;
@property(nonatomic, strong) UIView *testingHeader;
@property(nonatomic, strong) UIView *testingControls;
@property(nonatomic, strong) UILabel *testingTitle;
@property(nonatomic, strong) UIView *appearancePanel;
@property(nonatomic, strong) UISegmentedControl *appearanceControl;
@property(nonatomic, strong) NSTimer *numberTimer,*previewTimer;
@property(nonatomic, strong) NSLayoutConstraint *headerHeight;
@property(nonatomic, strong) NSMutableArray<NSDictionary *> *paneHistory;
@property(nonatomic, strong) UIView *rootHeader,*rootFooter;
@property(nonatomic, strong) UILabel *testStatus;
@property(nonatomic, copy) NSString *pickerKey;
@property(nonatomic, copy) NSString *pendingColor;
@property(nonatomic,strong) NSTimer *colorTimer;
@property(nonatomic,weak) UIColorPickerViewController *activePicker;
@property(nonatomic,copy) NSString *documentAction;
@property(nonatomic,strong) NSURL *exportDirectory;
@property(nonatomic,copy) NSData *pendingImportData;
@property(nonatomic,strong) NSError *pendingImportError;
@property(nonatomic) NSUInteger importGeneration;
@end

@implementation V26PaneController
- (void)loadView {
    self.pageName = self.pageName ?: @"Root";
    self.settingsTable = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleInsetGrouped];
    self.settingsTable.dataSource = self;
    self.settingsTable.delegate = self;
    self.settingsTable.rowHeight = UITableViewAutomaticDimension;
    self.settingsTable.estimatedRowHeight = 64;
    self.settingsTable.sectionHeaderHeight = UITableViewAutomaticDimension;
    self.settingsTable.sectionFooterHeight = UITableViewAutomaticDimension;
    self.settingsTable.keyboardDismissMode = UIScrollViewKeyboardDismissModeOnDrag;
    self.view=[UIView new];self.view.backgroundColor=UIColor.systemBackgroundColor;
    self.testingHeader=[UIView new];self.testingHeader.translatesAutoresizingMaskIntoConstraints=NO;
    [self.view addSubview:self.testingHeader];
    self.settingsTable.translatesAutoresizingMaskIntoConstraints=NO;[self.view addSubview:self.settingsTable];
    self.headerHeight=[self.testingHeader.heightAnchor constraintEqualToConstant:290];
    [NSLayoutConstraint activateConstraints:@[[self.testingHeader.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [self.testingHeader.leadingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.leadingAnchor],
        [self.testingHeader.trailingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.trailingAnchor],self.headerHeight,
        [self.settingsTable.topAnchor constraintEqualToAnchor:self.testingHeader.bottomAnchor],
        [self.settingsTable.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.settingsTable.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.settingsTable.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor]]];
    self.settingsTable.contentInsetAdjustmentBehavior=UIScrollViewContentInsetAdjustmentNever;
    self.settingsTable.sectionHeaderTopPadding=0;
}
- (void)viewDidLoad {
    [super viewDidLoad];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(testBannerResult:) name:@"VLGTestBannerResult" object:nil];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(flushForBackground:) name:UIApplicationWillResignActiveNotification object:nil];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(resumeImport:) name:UIApplicationDidBecomeActiveNotification object:nil];
    if ([self.pageName isEqual:@"Root"]) {
        self.title = @"Velvet - Liquid Glass";
        UIView *header = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 152)];
        UIImage *image = [UIImage imageNamed:@"velvet-header-icon.png" inBundle:[NSBundle bundleForClass:V26PaneController.class] compatibleWithTraitCollection:nil];
        UIImageView *logo = [[UIImageView alloc] initWithImage:image];
        logo.frame = CGRectMake(0, 26, 320, 80);
        logo.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        logo.contentMode = UIViewContentModeScaleAspectFit;
        [header addSubview:logo];
        UILabel *brand=[[UILabel alloc] initWithFrame:CGRectMake(12,114,296,28)];
        brand.autoresizingMask=UIViewAutoresizingFlexibleWidth;brand.font=[UIFont systemFontOfSize:17 weight:UIFontWeightSemibold];
        brand.textAlignment=NSTextAlignmentCenter;brand.adjustsFontSizeToFitWidth=YES;brand.minimumScaleFactor=.75;
        brand.text=@"Velvet - Liquid Glass";[header addSubview:brand];
        self.rootHeader=header;self.settingsTable.tableHeaderView = header;
        UILabel *footer = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 320, 64)];
        footer.font = [UIFont systemFontOfSize:13];
        footer.textColor = UIColor.secondaryLabelColor;
        footer.numberOfLines = 3;
        footer.textAlignment = NSTextAlignmentCenter;
        footer.text = @"Velvet by NoisyFlake\nLiquid Glass port by sahinkaa\n1.0.0";
        self.rootFooter=footer;self.settingsTable.tableFooterView = footer;
    }
    CGFloat previewWidth=self.navigationController.view.bounds.size.width;
    if(previewWidth<=0)previewWidth=UIScreen.mainScreen.bounds.size.width;
    self.preview=[[VLGLivePreviewView alloc] initWithFrame:CGRectMake(0,85,previewWidth,130) identifier:self.scopeIdentifier];
    [self.testingHeader addSubview:self.preview];
    __weak typeof(self) weakSelf=self;
    self.preview.appChanged=^{[weakSelf.preview updatePreview];};
    self.testStatus=[UILabel new];self.testStatus.numberOfLines=3;self.testStatus.font=[UIFont systemFontOfSize:12];
    self.testStatus.textAlignment=NSTextAlignmentCenter;self.testStatus.textColor=UIColor.secondaryLabelColor;
    [self.testingHeader addSubview:self.testStatus];
    self.testingControls=[UIView new];[self.testingHeader addSubview:self.testingControls];
    UIButton *back=[UIButton buttonWithType:UIButtonTypeSystem];[back setTitle:@"‹ Back" forState:UIControlStateNormal];
    back.titleLabel.font=[UIFont systemFontOfSize:17 weight:UIFontWeightMedium];back.accessibilityLabel=@"Back to previous menu";
    [back addTarget:self action:@selector(goBack) forControlEvents:UIControlEventTouchUpInside];
    UIButton *test=[UIButton buttonWithType:UIButtonTypeSystem];[test setTitle:@"Test Banner" forState:UIControlStateNormal];
    test.titleLabel.font=[UIFont systemFontOfSize:17 weight:UIFontWeightSemibold];test.accessibilityHint=@"Show a persistent test banner. Swipe it up to dismiss.";
    [test addTarget:self action:@selector(testBanner) forControlEvents:UIControlEventTouchUpInside];
    self.testingTitle=[UILabel new];self.testingTitle.font=[UIFont systemFontOfSize:14 weight:UIFontWeightSemibold];
    self.testingTitle.textAlignment=NSTextAlignmentCenter;self.testingTitle.lineBreakMode=NSLineBreakByTruncatingTail;
    for(UIView *v in @[back,self.testingTitle,test]) {v.translatesAutoresizingMaskIntoConstraints=NO;[self.testingControls addSubview:v];}
    [NSLayoutConstraint activateConstraints:@[[back.leadingAnchor constraintEqualToAnchor:self.testingControls.leadingAnchor constant:16],
        [back.topAnchor constraintEqualToAnchor:self.testingControls.topAnchor],[back.bottomAnchor constraintEqualToAnchor:self.testingControls.bottomAnchor],
        [back.widthAnchor constraintEqualToConstant:76],[test.trailingAnchor constraintEqualToAnchor:self.testingControls.trailingAnchor constant:-16],
        [test.topAnchor constraintEqualToAnchor:self.testingControls.topAnchor],[test.bottomAnchor constraintEqualToAnchor:self.testingControls.bottomAnchor],
        [test.widthAnchor constraintEqualToConstant:110],[self.testingTitle.leadingAnchor constraintEqualToAnchor:back.trailingAnchor constant:4],
        [self.testingTitle.trailingAnchor constraintEqualToAnchor:test.leadingAnchor constant:-4],[self.testingTitle.centerYAnchor constraintEqualToAnchor:back.centerYAnchor]]];
    self.appearancePanel=[UIView new];self.appearancePanel.backgroundColor=UIColor.secondarySystemGroupedBackgroundColor;
    self.appearancePanel.layer.cornerRadius=14;[self.testingHeader addSubview:self.appearancePanel];
    UILabel *appearanceLabel=[UILabel new];appearanceLabel.text=@"Banner";appearanceLabel.font=[UIFont systemFontOfSize:15 weight:UIFontWeightMedium];
    self.appearanceControl=[[UISegmentedControl alloc] initWithItems:@[@"Light",@"Dark"]];
    self.appearanceControl.accessibilityLabel=@"Banner appearance";
    [self.appearanceControl addTarget:self action:@selector(appearanceChanged) forControlEvents:UIControlEventValueChanged];
    for(UIView *v in @[appearanceLabel,self.appearanceControl]){v.translatesAutoresizingMaskIntoConstraints=NO;[self.appearancePanel addSubview:v];}
    [NSLayoutConstraint activateConstraints:@[[appearanceLabel.leadingAnchor constraintEqualToAnchor:self.appearancePanel.leadingAnchor constant:14],
        [appearanceLabel.centerYAnchor constraintEqualToAnchor:self.appearancePanel.centerYAnchor],
        [self.appearanceControl.leadingAnchor constraintEqualToAnchor:appearanceLabel.trailingAnchor constant:14],
        [self.appearanceControl.trailingAnchor constraintEqualToAnchor:self.appearancePanel.trailingAnchor constant:-12],
        [self.appearanceControl.centerYAnchor constraintEqualToAnchor:self.appearancePanel.centerYAnchor],
        [self.appearanceControl.heightAnchor constraintGreaterThanOrEqualToConstant:34],
        [self.appearanceControl.widthAnchor constraintGreaterThanOrEqualToConstant:130]]];
    [self reloadPage];
}
- (void)appearanceChanged {
    [self flushPendingColor];[self flushNumericEdits];
    [self saveValue:self.appearanceControl.selectedSegmentIndex==0 ? @"light" : @"dark" key:@"appearance"];
}
- (void)dealloc { [self cleanupExport];[self.colorTimer invalidate];[self.numberTimer invalidate];[self.previewTimer invalidate];[NSNotificationCenter.defaultCenter removeObserver:self]; }
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.navigationController setNavigationBarHidden:YES animated:NO];
    [self reloadPage];
}
- (void)viewDidAppear:(BOOL)animated {[super viewDidAppear:animated];[self completePendingImport];}
- (void)resumeImport:(NSNotification *)notification {[self completePendingImport];}
- (void)viewWillDisappear:(BOOL)animated {
    [self flushPendingColor];
    [self flushNumericEdits];
    [super viewWillDisappear:animated];
    // Internal Velvet navigation keeps the test alive. Leaving Velvet removes
    // only our own request and restores the host Settings navigation bar.
    UINavigationController *navigation=self.navigationController;
    dispatch_async(dispatch_get_main_queue(),^{
        BOOL inVelvet=[self containsPane:navigation.topViewController];
        if(!inVelvet) {++self.importGeneration;self.pendingImportData=nil;self.pendingImportError=nil;[navigation setNavigationBarHidden:NO animated:NO];VLGCancelTestBanner();}
    });
}
- (void)flushForBackground:(NSNotification *)notification { [self flushPendingColor];[self flushNumericEdits];VLGCancelTestBanner(); }
- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    CGFloat width = self.settingsTable.bounds.size.width;
    CGFloat reserved=self.view.bounds.size.height>600 ? 85 : 65;
    CGFloat headerWidth=self.testingHeader.bounds.size.width;
    if(headerWidth<=1)headerWidth=MAX(1,self.view.bounds.size.width);
    CGFloat previewHeight=[self.preview preferredHeightForWidth:headerWidth];
    self.headerHeight.constant=reserved+previewHeight+44+65;
    self.testStatus.frame=CGRectMake(16,MAX(0,reserved-60),MAX(1,headerWidth-32),52);
    self.preview.frame=CGRectMake(0,reserved,headerWidth,previewHeight);
    self.testingControls.frame=CGRectMake(0,reserved+previewHeight,headerWidth,44);
    self.appearancePanel.frame=CGRectMake(16,reserved+previewHeight+44+3,MAX(1,headerWidth-32),56);
    UIView *header = self.settingsTable.tableHeaderView;
    if (header && width > 0 && fabs(header.frame.size.width - width) > 0.5) {
        header.frame = CGRectMake(0, 0, width, header.frame.size.height);
        self.settingsTable.tableHeaderView = header;
    }
}
- (BOOL)containsPane:(UIViewController *)controller {
    if(!controller)return NO;
    NSMutableArray *queue=[NSMutableArray arrayWithObject:controller];
    for(NSUInteger i=0;i<queue.count && i<32;++i) {
        UIViewController *item=queue[i];if(item==self || [item isKindOfClass:V26PaneController.class])return YES;
        if(queue.count<32)[queue addObjectsFromArray:item.childViewControllers];
    }
    return NO;
}
- (void)goBack {
    [self flushPendingColor];[self flushNumericEdits];
    NSDictionary *previous=self.paneHistory.lastObject;
    if(previous) {
        [self.paneHistory removeLastObject];self.pageName=previous[@"page"];
        self.scopeIdentifier=previous[@"scope"]==NSNull.null ? nil : previous[@"scope"];
        self.title=previous[@"title"];self.pickerKey=nil;
        [self reloadPage];[self.settingsTable layoutIfNeeded];
        self.settingsTable.contentOffset=CGPointMake([previous[@"x"] doubleValue],[previous[@"y"] doubleValue]);
    } else [self.navigationController popViewControllerAnimated:YES];
}
- (void)testBannerResult:(NSNotification *)note {
    NSString *message=note.userInfo[@"message"];
    if(![message isKindOfClass:NSString.class])return;
    self.testStatus.text=message;self.testStatus.textColor=message.length ? UIColor.systemOrangeColor : UIColor.secondaryLabelColor;
    // Visibility depends on our mounted view, not equality with the host's
    // topViewController. iOS Settings can embed the preference controller.
    if(message.length && self.viewIfLoaded.window && !self.presentedViewController && UIApplication.sharedApplication.applicationState==UIApplicationStateActive) {
        UIAccessibilityPostNotification(UIAccessibilityAnnouncementNotification,message);
        [self showError:message];
    }
}
- (void)testBanner {
    [self flushPendingColor];[self flushNumericEdits];
    NSString *identifier=self.scopeIdentifier ?: [[Velvet2PrefsManager sharedInstance] objectForKey:@"currentIcon"];
    if(!identifier.length)identifier=@"com.apple.Preferences";
    if([identifier isEqual:@"com.noisyflake.velvetFocus"]) {[self showError:@"Choose an installed app to show a Test Banner."];return;}
    self.testStatus.text=nil;
    NSError *error=nil;
    if(!VLGRequestTestBanner(identifier,&error)) [self showError:error.localizedDescription ?: @"The Test Banner request could not be sent."];
}
- (void)showError:(NSString *)message {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Velvet - Liquid Glass" message:message preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}
- (id)setting:(NSString *)key {
    return [[Velvet2PrefsManager sharedInstance] settingForKey:key withIdentifier:self.scopeIdentifier];
}
- (void)reloadPage {
    [[Velvet2PrefsManager sharedInstance] reloadFromDisk];
    if ([self.pageName isEqual:@"Apps"]) {
        [self loadApps];
    } else {
        NSString *path = [[NSBundle bundleForClass:V26PaneController.class] pathForResource:self.pageName ofType:@"plist"];
        NSData *data = path ? [NSData dataWithContentsOfFile:path] : nil;
        id resource = data ? [NSPropertyListSerialization propertyListWithData:data options:0 format:NULL error:nil] : nil;
        self.resource = [resource isKindOfClass:NSDictionary.class] ? resource : nil;
        NSMutableDictionary *values = [V26Defaults() mutableCopy];
        for (NSDictionary *item in self.resource[@"items"]) {
            id key = item[@"key"];
            if ([key isKindOfClass:NSString.class]) {
                id value = [self setting:key];
                if (value) values[key] = value;
            }
            for (NSString *part in [item[@"require"] componentsSeparatedByString:@"&"]) {
                NSString *name = [[part componentsSeparatedByString:@"="] firstObject];
                if ([name hasPrefix:@"!"]) name = [name substringFromIndex:1];
                id value = [self setting:name];
                if (value) values[name] = value;
            }
        }
        self.groups = V26PaneSections(self.resource, values);
        if ([self.pageName isEqual:@"Root"]) {
            self.groups = [self.groups arrayByAddingObject:@{@"rows": @[@{@"cell": @"PSButtonCell", @"label": @"Respring", @"action": @"respring"}]}];
        }
        if ([self.pageName isEqual:@"Settings"] && self.scopeIdentifier.length) {
            self.groups=[self.groups arrayByAddingObject:@{@"footer":@"Remove this app’s overrides and inherit Global Settings.",@"rows":@[@{@"cell":@"PSButtonCell",@"label":@"Reset This App",@"action":@"resetApp",@"isDestructive":@YES}]}];
        }
        if (!self.title.length) self.title = self.resource[@"title"] ?: @"Velvet - Liquid Glass";
    }
    V26Report([@"nativePane.sections." stringByAppendingString:self.pageName], @(self.groups.count));
    NSUInteger rows = 0;
    for (NSDictionary *group in self.groups) rows += [group[@"rows"] count];
    V26Report([@"nativePane.rows." stringByAppendingString:self.pageName], @(rows));
    BOOL rootPage=[self.pageName isEqual:@"Root"];
    self.settingsTable.tableHeaderView=rootPage ? self.rootHeader : nil;
    self.settingsTable.tableFooterView=rootPage ? self.rootFooter : nil;
    [self.preview configureIdentifier:self.scopeIdentifier];
    self.testingTitle.text=rootPage ? @"" : self.title;
    self.appearanceControl.selectedSegmentIndex=[[self setting:@"appearance"] isEqual:@"light"] ? 0 : 1;
    [self.settingsTable reloadData];
    [self.preview updatePreview];
}
- (void)loadApps {
    NSMutableArray *rows = [NSMutableArray new];
    id workspace = V26Object(NSClassFromString(@"LSApplicationWorkspace"), @"defaultWorkspace");
    id apps = V26Object(workspace, @"allInstalledApplications");
    if ([apps isKindOfClass:NSArray.class]) for (id app in apps) {
        id bundle = V26Object(app, @"applicationIdentifier");
        id name = V26Object(app, @"localizedName");
        id type = V26Object(app, @"applicationType");
        id tags = V26Object(app, @"appTags");
        BOOL hidden = [tags isKindOfClass:NSArray.class] && [tags containsObject:@"hidden"];
        if (![bundle isKindOfClass:NSString.class] || ![name isKindOfClass:NSString.class] || hidden || ![@[@"User", @"System"] containsObject:type]) continue;
        if ([bundle isEqual:@"com.apple.webapp"]) continue;
        [rows addObject:@{@"cell": @"App", @"label": name, @"key": bundle}];
    }
    [rows sortUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) { return [a[@"label"] localizedCaseInsensitiveCompare:b[@"label"]]; }];
    [rows insertObject:@{@"cell": @"App", @"label": @"Focus", @"key": @"com.noisyflake.velvetFocus"} atIndex:0];
    self.groups = @[@{@"title": @"Per-App Settings", @"footer": @"Unset options inherit Global Settings.", @"rows": rows}];
}
- (BOOL)saveValue:(id)value key:(NSString *)key { return [self writeValue:value key:key reload:YES]; }
- (BOOL)writeValue:(id)value key:(NSString *)key reload:(BOOL)reload {
    NSString *fullKey = V26PreferenceKey(key, self.scopeIdentifier);
    if (!fullKey) return NO;
    Velvet2PrefsManager *manager = [Velvet2PrefsManager sharedInstance];
    id stored = self.scopeIdentifier.length && [[manager objectForKey:key] isEqual:value] ? nil : value;
    // A newly edited per-app radius is explicit. Eliding it could reveal a
    // preserved legacy point override beneath the new percent key.
    if(self.scopeIdentifier.length && [key isEqual:@"cornerRadiusPercent"])stored=value;
    NSError *error = nil;
    if (![manager saveValue:stored forKey:fullKey error:&error]) {
        [self showError:error.localizedDescription ?: @"The setting could not be saved. Please reopen the page and try again."];
        return NO;
    }
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), CFSTR("com.sahinkaa.velvetliquidglass/preferenceUpdate"), NULL, NULL, YES);
    if (reload) [self reloadPage];
    return YES;
}
- (void)stageNumber:(double)value key:(NSString *)key final:(BOOL)final {
    if (!self.pendingNumbers) self.pendingNumbers=[NSMutableDictionary dictionary];
    self.pendingNumbers[key]=@(value);
    [[Velvet2PrefsManager sharedInstance] setTransientValue:@(value) forKey:V26PreferenceKey(key,self.scopeIdentifier)];
    if(!self.previewTimer && !final) {
        __weak typeof(self) weakSelf=self;
        self.previewTimer=[NSTimer timerWithTimeInterval:1.0/60 repeats:NO block:^(NSTimer *timer) {
            weakSelf.previewTimer=nil;[weakSelf.preview updatePreview];
        }];
        [NSRunLoop.mainRunLoop addTimer:self.previewTimer forMode:NSRunLoopCommonModes];
    }
    if(final) {[self.numberTimer invalidate];self.numberTimer=nil;[self flushNumericEdits];}
    else if(!self.numberTimer) {
        __weak typeof(self) weakSelf=self;
        self.numberTimer=[NSTimer timerWithTimeInterval:.08 repeats:NO block:^(NSTimer *timer) {
            weakSelf.numberTimer=nil;[weakSelf flushNumericEdits];
        }];
        // Common modes include UISlider tracking. This timer exists only while
        // edits are pending and never delays the per-finger-tick value label.
        [NSRunLoop.mainRunLoop addTimer:self.numberTimer forMode:NSRunLoopCommonModes];
    }
}
- (void)commitNumber:(NSString *)key {
    NSNumber *number=self.pendingNumbers[key];if (!number) return;
    Velvet2PrefsManager *manager=[Velvet2PrefsManager sharedInstance];
    // Remove the temporary override before comparing with inherited defaults.
    [manager clearTransientValueForKey:V26PreferenceKey(key,self.scopeIdentifier)];
    [self.pendingNumbers removeObjectForKey:key];
    if (![self writeValue:number key:key reload:NO]) [self reloadPage];
    [self.preview updatePreview];
}
- (void)flushNumericEdits {
    [self.numberTimer invalidate];self.numberTimer=nil;[self.previewTimer invalidate];self.previewTimer=nil;
    for (NSString *key in self.pendingNumbers.allKeys) [self commitNumber:key];
}
- (void)editNumber:(NSDictionary *)row cell:(VLGNumericSliderCell *)cell {
    NSString *key=row[@"key"],*title=row[@"label"] ?: @"Radius";
    double minimum=[row[@"min"] doubleValue],maximum=[row[@"max"] doubleValue];
    NSString *range=[NSString stringWithFormat:@"Enter a value from %@ to %@.",V26NumericText(minimum,NO),V26NumericText(maximum,NO)];
    UIAlertController *alert=[UIAlertController alertControllerWithTitle:title message:range preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *field) {field.keyboardType=minimum<0 ? UIKeyboardTypeNumbersAndPunctuation : UIKeyboardTypeDecimalPad;field.text=V26NumericText(cell.value,NO);field.clearButtonMode=UITextFieldViewModeWhileEditing;}];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    __weak typeof(self) weakSelf=self;__weak VLGNumericSliderCell *weakCell=cell;
    __weak UIAlertController *weakAlert=alert;
    [alert addAction:[UIAlertAction actionWithTitle:@"Save" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        double value;
        if (!V26ParseNumeric(weakAlert.textFields.firstObject.text,minimum,maximum,&value)) {[weakSelf showError:range];return;}
        [weakCell setNumericValue:value];[weakSelf stageNumber:value key:key final:YES];
        [weakCell setOverrideHighlighted:weakSelf.scopeIdentifier.length && [[Velvet2PrefsManager sharedInstance] objectForKey:V26PreferenceKey(key,weakSelf.scopeIdentifier)]!=nil];
    }]];
    __weak UIAlertAction *weakSave=alert.actions.lastObject;
    [alert.textFields.firstObject addAction:[UIAction actionWithHandler:^(UIAction *action) {
        double value;weakSave.enabled=V26ParseNumeric(weakAlert.textFields.firstObject.text,minimum,maximum,&value);
    }] forControlEvents:UIControlEventEditingChanged];
    [self presentViewController:alert animated:YES completion:nil];
}
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { return (NSInteger)self.groups.count; }
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { return [self.groups[(NSUInteger)section][@"rows"] count]; }
// Own the header/footer geometry instead of inheriting inset-grouped
// UIKit title margins, which add a second gap on iOS 26.
- (UIView *)sectionText:(NSString *)text table:(UITableView *)table footer:(BOOL)footer {
    UIView *container=[UIView new];if(!text.length)return container;
    UILabel *label=[UILabel new];label.text=text;label.numberOfLines=0;
    label.font=[UIFont systemFontOfSize:footer ? 13 : 17 weight:footer ? UIFontWeightRegular : UIFontWeightSemibold];
    label.textColor=UIColor.secondaryLabelColor;label.translatesAutoresizingMaskIntoConstraints=NO;[container addSubview:label];
    CGFloat inset=MAX(24,table.layoutMargins.left+16);
    [NSLayoutConstraint activateConstraints:@[[label.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:inset],
        [label.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-inset],
        [label.topAnchor constraintEqualToAnchor:container.topAnchor constant:footer ? 4 : 5],
        [label.bottomAnchor constraintEqualToAnchor:container.bottomAnchor constant:footer ? -3 : -3]]];
    return container;
}
- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {return [self sectionText:self.groups[(NSUInteger)section][@"title"] table:tableView footer:NO];}
- (UIView *)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section {return [self sectionText:self.groups[(NSUInteger)section][@"footer"] table:tableView footer:YES];}
- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    NSString *title=self.groups[(NSUInteger)section][@"title"];return title.length ? 29 : 5;
}
- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section {
    NSString *footer=self.groups[(NSUInteger)section][@"footer"];
    if(!footer.length)return .01;
    CGFloat width=MAX(1,tableView.bounds.size.width-2*MAX(24,tableView.layoutMargins.left+16));
    CGRect rect=[footer boundingRectWithSize:CGSizeMake(width,CGFLOAT_MAX) options:NSStringDrawingUsesLineFragmentOrigin attributes:@{NSFontAttributeName:[UIFont systemFontOfSize:13]} context:nil];
    return ceil(rect.size.height)+7;
}
- (NSDictionary *)rowAt:(NSIndexPath *)path { return self.groups[(NSUInteger)path.section][@"rows"][(NSUInteger)path.row]; }
- (BOOL)rowEnabled:(NSDictionary *)row {
    if ([self.scopeIdentifier isEqual:@"com.noisyflake.velvetFocus"] && [@[@"Time"] containsObject:row[@"key"]]) return NO;
    return YES;
}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)path {
    NSDictionary *row = [self rowAt:path];
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:nil];
    NSString *kind = row[@"cell"];
    NSString *key = row[@"key"];
    cell.textLabel.text = row[@"label"] ?: ([key isEqual:@"cornerRadiusPercent"] ? @"Radius" : key);
    cell.detailTextLabel.text = row[@"cellSubtitleText"];
    cell.detailTextLabel.numberOfLines = 2;
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    BOOL enabled = [self rowEnabled:row];
    cell.userInteractionEnabled = enabled;
    cell.contentView.alpha = enabled ? 1 : 0.45;
    NSString *symbol = row[@"systemIcon"];
    if (symbol.length) { cell.imageView.image = [UIImage systemImageNamed:symbol]; cell.imageView.tintColor = UIColor.systemBlueColor; }
    if([row[@"iconName"] isKindOfClass:NSString.class]) {
        UIImage *logo=[UIImage imageNamed:row[@"iconName"] inBundle:[NSBundle bundleForClass:self.class] compatibleWithTraitCollection:nil];
        cell.imageView.image=[logo imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];cell.imageView.tintColor=UIColor.systemBlueColor;
    }
    if (self.scopeIdentifier.length && managerValue(self.scopeIdentifier, key) != nil) cell.backgroundColor = [UIColor.systemBlueColor colorWithAlphaComponent:0.12];
    __weak V26PaneController *weakSelf = self;
    if([row[@"action"] isEqual:@"respring"]) {
        cell.textLabel.text=nil;cell.detailTextLabel.text=nil;cell.selectionStyle=UITableViewCellSelectionStyleNone;
        cell.backgroundConfiguration=[UIBackgroundConfiguration clearConfiguration];
        UIButton *button=[UIButton buttonWithType:UIButtonTypeSystem];[button setTitle:@"Respring" forState:UIControlStateNormal];
        button.titleLabel.font=[UIFont systemFontOfSize:16 weight:UIFontWeightMedium];button.backgroundColor=UIColor.secondarySystemGroupedBackgroundColor;
        button.layer.cornerRadius=22;button.translatesAutoresizingMaskIntoConstraints=NO;
        [button addTarget:self action:@selector(confirmRespring) forControlEvents:UIControlEventTouchUpInside];[cell.contentView addSubview:button];
        [NSLayoutConstraint activateConstraints:@[[button.centerXAnchor constraintEqualToAnchor:cell.contentView.centerXAnchor],
            [button.widthAnchor constraintEqualToConstant:136],[button.heightAnchor constraintEqualToConstant:44],
            [button.topAnchor constraintEqualToAnchor:cell.contentView.topAnchor constant:4],[button.bottomAnchor constraintEqualToAnchor:cell.contentView.bottomAnchor constant:-4]]];
        return cell;
    }
    if ([kind isEqual:@"PSSwitchCell"]) {
        UISwitch *control = [UISwitch new];
        control.on = [[self setting:key] boolValue];
        control.enabled = enabled;
        [control addAction:[UIAction actionWithHandler:^(UIAction *action) { [weakSelf saveValue:@(((UISwitch *)action.sender).on) key:key]; }] forControlEvents:UIControlEventValueChanged];
        cell.accessoryView = control;
    } else if ([kind isEqual:@"PSSliderCell"]) {
        VLGNumericSliderCell *numeric=[[VLGNumericSliderCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
        [numeric configureTitle:row[@"label"] ?: @"Radius" minimum:[row[@"min"] doubleValue] maximum:[row[@"max"] doubleValue]
            value:[[self setting:key] doubleValue] percent:([key hasSuffix:@"Alpha"] || [key hasSuffix:@"Shade"] || [key isEqual:@"cornerRadiusPercent"])];
        __weak VLGNumericSliderCell *weakNumeric=numeric;
        numeric.changed=^(double value,BOOL final) {
            [weakSelf stageNumber:value key:key final:final];
            [weakNumeric setOverrideHighlighted:weakSelf.scopeIdentifier.length && [[Velvet2PrefsManager sharedInstance] objectForKey:V26PreferenceKey(key,weakSelf.scopeIdentifier)]!=nil];
        };
        numeric.enterValue=^{[weakSelf editNumber:row cell:weakNumeric];};
        [numeric setOverrideHighlighted:self.scopeIdentifier.length && [[Velvet2PrefsManager sharedInstance] objectForKey:V26PreferenceKey(key,self.scopeIdentifier)]!=nil];
        return numeric;
    } else if ([row[@"options"] isKindOfClass:NSArray.class]) {
        NSArray *options = row[@"options"];
        NSMutableArray *titles = [NSMutableArray new];
        for (NSDictionary *option in options) [titles addObject:option[@"text"] ?: @""];
        UISegmentedControl *control = [[UISegmentedControl alloc] initWithItems:titles];
        NSString *value = [self setting:key];
        if([key isEqual:@"appearance"] && ![@[@"light",@"dark"] containsObject:value])value=@"dark";
        for (NSUInteger index = 0; index < options.count; ++index) if ([options[index][@"value"] isEqual:value]) control.selectedSegmentIndex = (NSInteger)index;
        [control addAction:[UIAction actionWithHandler:^(UIAction *action) {
            NSInteger index = ((UISegmentedControl *)action.sender).selectedSegmentIndex;
            if (index >= 0 && (NSUInteger)index < options.count) [weakSelf saveValue:options[(NSUInteger)index][@"value"] key:key];
        }] forControlEvents:UIControlEventValueChanged];
        control.translatesAutoresizingMaskIntoConstraints = NO;
        cell.textLabel.text = nil;
        [cell.contentView addSubview:control];
        [NSLayoutConstraint activateConstraints:@[[control.leadingAnchor constraintEqualToAnchor:cell.contentView.layoutMarginsGuide.leadingAnchor], [control.trailingAnchor constraintEqualToAnchor:cell.contentView.layoutMarginsGuide.trailingAnchor], [control.topAnchor constraintEqualToAnchor:cell.contentView.topAnchor constant:12], [control.bottomAnchor constraintEqualToAnchor:cell.contentView.bottomAnchor constant:-12], [control.heightAnchor constraintGreaterThanOrEqualToConstant:36]]];
    } else {
        cell.selectionStyle = UITableViewCellSelectionStyleDefault;
        if ([kind isEqual:@"PSButtonCell"]) cell.textLabel.textColor = [row[@"isDestructive"] boolValue] ? UIColor.systemRedColor : UIColor.systemBlueColor;
        else if ([row[@"cellClass"] isEqual:@"Velvet2ColorPicker"]) {
            UIColor *color = [self colorForKey:key];
            UIView *swatch = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 28, 28)];
            swatch.backgroundColor = color; swatch.layer.cornerRadius = 14; swatch.layer.borderWidth = 1; swatch.layer.borderColor = UIColor.secondaryLabelColor.CGColor;
            cell.accessoryView = swatch;
        } else if ([kind isEqual:@"PSLinkListCell"]) {
            NSUInteger index = [row[@"validValues"] indexOfObject:[self setting:key] ?: NSNull.null];
            if (index != NSNotFound && index < [row[@"validTitles"] count]) cell.detailTextLabel.text = row[@"validTitles"][index];
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        } else if (![kind isEqual:@"Error"]) cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }
    return cell;
}
static id managerValue(NSString *identifier, NSString *key) {
    return key.length ? [[Velvet2PrefsManager sharedInstance] objectForKey:V26PreferenceKey(key, identifier)] : nil;
}
- (UIColor *)colorForKey:(NSString *)key {
    id value = [self setting:key];
    return [value isKindOfClass:NSString.class] ? [UIColor colorFromP3String:value] : UIColor.whiteColor;
}
- (NSIndexPath *)tableView:(UITableView *)tableView willSelectRowAtIndexPath:(NSIndexPath *)path {
    return [[[self rowAt:path] objectForKey:@"action"] isEqual:@"respring"] ? nil : path;
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)path {
    [tableView deselectRowAtIndexPath:path animated:YES];
    NSDictionary *row = [self rowAt:path];
    if (![self rowEnabled:row]) return;
    NSString *destination = V26Destination(row);
    if ([row[@"cell"] isEqual:@"App"]) destination = @"Settings";
    if (destination) {
        [self flushPendingColor];[self flushNumericEdits];
        if(!self.paneHistory)self.paneHistory=[NSMutableArray new];
        [self.paneHistory addObject:@{@"page":self.pageName,@"scope":self.scopeIdentifier ?: NSNull.null,
            @"title":self.title ?: @"Velvet",@"x":@(self.settingsTable.contentOffset.x),@"y":@(self.settingsTable.contentOffset.y)}];
        self.pageName=destination;
        if([row[@"cell"] isEqual:@"App"])self.scopeIdentifier=row[@"key"];
        self.title=row[@"label"];self.pickerKey=nil;
        [self reloadPage];[self.settingsTable setContentOffset:CGPointZero animated:NO];
    } else if ([row[@"cellClass"] isEqual:@"Velvet2ColorPicker"]) {
        self.pickerKey = row[@"key"];
        UIColorPickerViewController *picker = [UIColorPickerViewController new];
        picker.delegate = self; picker.supportsAlpha = YES; picker.selectedColor = [self colorForKey:self.pickerKey];
        self.activePicker=picker;
        VLGColorEditorController *editor=[VLGColorEditorController new];editor.picker=picker;editor.title=row[@"label"] ?: @"Color";
        editor.modalPresentationStyle=UIModalPresentationPageSheet;
        __weak typeof(self) weakSelf=self;
        __weak VLGColorEditorController *weakEditor=editor;
        editor.finished=^{
            [weakSelf queueColor:weakSelf.activePicker.selectedColor];[weakSelf flushPendingColor];
            [weakEditor dismissViewControllerAnimated:YES completion:^{[weakSelf refreshColorSwatches];}];
        };
        UISheetPresentationController *sheet=editor.sheetPresentationController;
        if(@available(iOS 16.0,*)) sheet.detents=@[[UISheetPresentationControllerDetent customDetentWithIdentifier:@"VelvetColorEditor" resolver:^CGFloat(id<UISheetPresentationControllerDetentResolutionContext> context) {
            return MAX(240,context.maximumDetentValue-130);
        }]];
        else sheet.detents=@[UISheetPresentationControllerDetent.mediumDetent];
        sheet.prefersScrollingExpandsWhenScrolledToEdge=NO;sheet.prefersGrabberVisible=YES;
        [self presentViewController:editor animated:YES completion:nil];editor.presentationController.delegate=self;
    } else if ([row[@"cell"] isEqual:@"PSLinkListCell"]) {
        UIAlertController *choices = [UIAlertController alertControllerWithTitle:row[@"label"] message:nil preferredStyle:UIAlertControllerStyleActionSheet];
        NSArray *values = row[@"validValues"], *titles = row[@"validTitles"];
        for (NSUInteger index = 0; index < MIN(values.count, titles.count); ++index) {
            id value = values[index]; NSString *key = row[@"key"];
            [choices addAction:[UIAlertAction actionWithTitle:titles[index] style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) { [self saveValue:value key:key]; }]];
        }
        [choices addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
        choices.popoverPresentationController.sourceView = tableView;
        choices.popoverPresentationController.sourceRect = [tableView rectForRowAtIndexPath:path];
        [self presentViewController:choices animated:YES completion:nil];
    } else {
        NSString *action = row[@"action"];
        if ([action isEqual:@"respring"]) [self confirmRespring];
        else if ([action isEqual:@"resetApp"]) [self confirmAppReset];
        else if ([action isEqual:@"resetSettings"]) [self confirmReset];
        else if ([action isEqual:@"exportSettings"]) [self exportSettings];
        else if ([action isEqual:@"importSettings"]) [self importSettings];
        else if ([action isEqual:@"twitter"]) [UIApplication.sharedApplication openURL:[NSURL URLWithString:@"https://twitter.com/NoisyFlake"] options:@{} completionHandler:nil];
        else if ([action isEqual:@"github"]) [UIApplication.sharedApplication openURL:[NSURL URLWithString:@"https://github.com/sahinkaa"] options:@{} completionHandler:nil];
        else if ([action isEqual:@"paypal"]) [UIApplication.sharedApplication openURL:[NSURL URLWithString:@"https://paypal.me/NoisyFlake"] options:@{} completionHandler:nil];
    }
}
- (void)refreshColorSwatches {
    for(NSIndexPath *path in self.settingsTable.indexPathsForVisibleRows) {
        NSDictionary *row=[self rowAt:path];if(![row[@"cellClass"] isEqual:@"Velvet2ColorPicker"])continue;
        UITableViewCell *cell=[self.settingsTable cellForRowAtIndexPath:path];
        cell.accessoryView.backgroundColor=[self colorForKey:row[@"key"]];
    }
}
- (void)queueColor:(UIColor *)color {
    if(!color || !self.pickerKey.length)return;
    CGColorSpaceRef space=CGColorSpaceCreateWithName(kCGColorSpaceDisplayP3);
    CGColorRef converted=CGColorCreateCopyByMatchingToColorSpace(space,kCGRenderingIntentDefault,color.CGColor,NULL);
    CGColorSpaceRelease(space);if(!converted)return;
    const CGFloat *rgba=CGColorGetComponents(converted);
    if(CGColorGetNumberOfComponents(converted)==4)
        self.pendingColor=[[NSString alloc] initWithFormat:@"%.7f %.7f %.7f %.7f" locale:[NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"],rgba[0],rgba[1],rgba[2],rgba[3]];
    CGColorRelease(converted);if(!self.pendingColor)return;
    [[Velvet2PrefsManager sharedInstance] setTransientValue:self.pendingColor forKey:V26PreferenceKey(self.pickerKey,self.scopeIdentifier)];
    [self refreshColorSwatches];
    if(!self.previewTimer) {
        __weak typeof(self) weakSelf=self;
        self.previewTimer=[NSTimer timerWithTimeInterval:1.0/60 repeats:NO block:^(NSTimer *timer){weakSelf.previewTimer=nil;[weakSelf.preview updatePreview];}];
        [NSRunLoop.mainRunLoop addTimer:self.previewTimer forMode:NSRunLoopCommonModes];
    }
    if(!self.colorTimer) {
        __weak typeof(self) weakSelf=self;
        self.colorTimer=[NSTimer timerWithTimeInterval:.08 repeats:NO block:^(NSTimer *timer){weakSelf.colorTimer=nil;[weakSelf flushPendingColor];}];
        [NSRunLoop.mainRunLoop addTimer:self.colorTimer forMode:NSRunLoopCommonModes];
    }
}
- (void)flushPendingColor {
    [self.colorTimer invalidate];self.colorTimer=nil;
    if(!self.pendingColor || !self.pickerKey)return;
    NSString *value=self.pendingColor;self.pendingColor=nil;
    [[Velvet2PrefsManager sharedInstance] clearTransientValueForKey:V26PreferenceKey(self.pickerKey,self.scopeIdentifier)];
    [self writeValue:value key:self.pickerKey reload:NO];[self refreshColorSwatches];[self.preview updatePreview];
}
- (void)colorPickerViewController:(UIColorPickerViewController *)controller didSelectColor:(UIColor *)color continuously:(BOOL)continuously {
    [self queueColor:color];if(!continuously)[self flushPendingColor];
}
- (void)colorPickerViewControllerDidFinish:(UIColorPickerViewController *)controller {
    [self queueColor:controller.selectedColor];[self flushPendingColor];[self refreshColorSwatches];
}
- (void)presentationControllerDidDismiss:(UIPresentationController *)presentationController {
    if(self.activePicker)[self queueColor:self.activePicker.selectedColor];
    [self flushPendingColor];self.activePicker=nil;[self refreshColorSwatches];
}
- (void)cleanupExport {
    if(self.exportDirectory)[NSFileManager.defaultManager removeItemAtURL:self.exportDirectory error:NULL];
    self.exportDirectory=nil;
}
- (void)exportSettings {
    if(self.presentedViewController)return;
    ++self.importGeneration;self.pendingImportData=nil;self.pendingImportError=nil;
    [self flushPendingColor];[self flushNumericEdits];
    NSError *error=nil;NSData *data=[[Velvet2PrefsManager sharedInstance] exportSettingsData:&error];
    if(!data){[self showError:error.localizedDescription ?: @"Settings could not be exported."];return;}
    [self cleanupExport];
    NSURL *folder=[[NSURL fileURLWithPath:NSTemporaryDirectory() isDirectory:YES] URLByAppendingPathComponent:[@"VelvetLiquidGlass-export-" stringByAppendingString:NSUUID.UUID.UUIDString] isDirectory:YES];
    if(![NSFileManager.defaultManager createDirectoryAtURL:folder withIntermediateDirectories:YES attributes:nil error:&error]){[self showError:error.localizedDescription];return;}
    self.exportDirectory=folder;NSURL *file=[folder URLByAppendingPathComponent:VLGSettingsExportFilename];
    if(![data writeToURL:file options:NSDataWritingAtomic error:&error]){[self cleanupExport];[self showError:error.localizedDescription];return;}
    VLGCancelTestBanner();
    UIDocumentPickerViewController *picker=[[UIDocumentPickerViewController alloc] initForExportingURLs:@[file] asCopy:YES];
    picker.delegate=self;picker.shouldShowFileExtensions=YES;self.documentAction=@"export";
    [self presentViewController:picker animated:YES completion:nil];
}
- (void)importSettings {
    if(self.presentedViewController)return;
    ++self.importGeneration;self.pendingImportData=nil;self.pendingImportError=nil;
    [self flushPendingColor];[self flushNumericEdits];VLGCancelTestBanner();
    UIDocumentPickerViewController *picker=[[UIDocumentPickerViewController alloc] initForOpeningContentTypes:@[UTTypePropertyList] asCopy:YES];
    picker.delegate=self;picker.allowsMultipleSelection=NO;picker.shouldShowFileExtensions=YES;self.documentAction=@"import";
    [self presentViewController:picker animated:YES completion:nil];
}
- (void)documentPickerWasCancelled:(UIDocumentPickerViewController *)controller {
    ++self.importGeneration;self.documentAction=nil;self.pendingImportData=nil;self.pendingImportError=nil;[self cleanupExport];
}
- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
    NSString *action=self.documentAction;self.documentAction=nil;
    if([action isEqual:@"export"]){[self cleanupExport];return;}
    if(![action isEqual:@"import"] || urls.count!=1)return;
    [self readImportedSettings:urls.firstObject];
}
- (void)readImportedSettings:(NSURL *)url {
    NSUInteger generation=self.importGeneration;
    __weak typeof(self) weakSelf=self;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED,0),^{
        BOOL scoped=[url startAccessingSecurityScopedResource];
        __block NSData *data=nil;__block NSError *readError=nil;NSError *coordinationError=nil;
        @try {
            NSFileCoordinator *coordinator=[[NSFileCoordinator alloc] initWithFilePresenter:nil];
            [coordinator coordinateReadingItemAtURL:url options:NSFileCoordinatorReadingWithoutChanges error:&coordinationError byAccessor:^(NSURL *coordinatedURL){
                NSFileHandle *handle=[NSFileHandle fileHandleForReadingFromURL:coordinatedURL error:&readError];
                if(handle){data=[handle readDataUpToLength:VLGSettingsMaxFileSize+1 error:&readError];[handle closeAndReturnError:NULL];}
            }];
        } @catch(NSException *exception) {
            readError=[NSError errorWithDomain:@"VelvetLiquidGlass.SettingsTransfer" code:2 userInfo:@{NSLocalizedDescriptionKey:@"The selected file could not be read."}];
        } @finally {if(scoped)[url stopAccessingSecurityScopedResource];}
        NSError *error=readError ?: coordinationError;
        NSDictionary *settings=error ? nil : VLGDecodeSettings(data,&error);
        dispatch_async(dispatch_get_main_queue(),^{
            typeof(self) pane=weakSelf;if(!pane || generation!=pane.importGeneration)return;
            pane.pendingImportData=settings ? data : nil;
            pane.pendingImportError=settings ? nil : error ?: [NSError errorWithDomain:@"VelvetLiquidGlass.SettingsTransfer" code:3 userInfo:@{NSLocalizedDescriptionKey:@"The selected file is not a settings plist."}];
            [pane completePendingImport];
        });
    });
}
- (void)completePendingImport {
    if((!self.pendingImportData && !self.pendingImportError) || !self.viewIfLoaded.window || self.presentedViewController || UIApplication.sharedApplication.applicationState!=UIApplicationStateActive)return;
    // Files dismisses itself. Defer alerts until that presentation transition
    // has finished; viewDidAppear/activation also retry this event-driven step.
    id<UIViewControllerTransitionCoordinator> transition=self.transitionCoordinator;
    if(transition) {
        __weak typeof(self) weakSelf=self;
        if([transition animateAlongsideTransition:nil completion:^(id<UIViewControllerTransitionCoordinatorContext> context){dispatch_async(dispatch_get_main_queue(),^{[weakSelf completePendingImport];});}])return;
    }
    NSData *data=self.pendingImportData;NSError *error=self.pendingImportError;self.pendingImportData=nil;self.pendingImportError=nil;
    if(error)[self showError:error.localizedDescription];else [self confirmImportData:data];
}
- (void)confirmImportData:(NSData *)data {
    UIAlertController *alert=[UIAlertController alertControllerWithTitle:@"Import Settings?" message:@"Replace your global and per-app settings with this file? A backup of your current settings will be saved first." preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    __weak typeof(self) weakSelf=self;
    [alert addAction:[UIAlertAction actionWithTitle:@"Import" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action){
        typeof(self) pane=weakSelf;if(!pane)return;
        [pane flushPendingColor];[pane flushNumericEdits];NSError *error=nil;
        if([[Velvet2PrefsManager sharedInstance] importSettingsData:data error:&error]) {
            CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),CFSTR("com.sahinkaa.velvetliquidglass/preferenceUpdate"),NULL,NULL,YES);
            [pane reloadPage];
        } else [pane showError:error.localizedDescription ?: @"Settings could not be imported. Your current settings have not been replaced."];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}
- (void)confirmAppReset {
    if (!self.scopeIdentifier.length) return;
    [self flushPendingColor];[self flushNumericEdits];
    NSString *identifier=[self.scopeIdentifier copy];
    UIAlertController *alert=[UIAlertController alertControllerWithTitle:@"Reset This App?" message:@"Remove only this app’s overrides? It will inherit Global Settings. Other apps will keep their settings." preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    __weak typeof(self) weakSelf=self;
    [alert addAction:[UIAlertAction actionWithTitle:@"Reset This App" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
        NSError *error=nil;
        if ([[Velvet2PrefsManager sharedInstance] resetIdentifier:identifier error:&error]) {
            CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), CFSTR("com.sahinkaa.velvetliquidglass/preferenceUpdate"),NULL,NULL,YES);
            [weakSelf reloadPage];
        } else [weakSelf showError:error.localizedDescription ?: @"This app’s settings could not be reset."];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}
- (void)confirmReset {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Reset Settings?" message:@"Restore global and per-app defaults? The original file is backed up before the first change." preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Reset" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
        NSError *error = nil;
        if ([[Velvet2PrefsManager sharedInstance] reset:&error]) {
            CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), CFSTR("com.sahinkaa.velvetliquidglass/preferenceUpdate"), NULL, NULL, YES);
            [self reloadPage];
        } else [self showError:error.localizedDescription ?: @"Settings could not be reset."];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}
- (void)confirmRespring {
    [self flushPendingColor];[self flushNumericEdits];
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Respring?" message:nil preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Confirm" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        pid_t pid;
        const char *arguments[] = {"sbreload", NULL};
        int status = posix_spawn(&pid, V26RootPath(@"/usr/bin/sbreload").fileSystemRepresentation, NULL, NULL, (char *const *)arguments, NULL);
        if (status) [self showError:@"The Home Screen could not be restarted from Settings. Please respring from your jailbreak utility."];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}
@end

// PreferenceLoader instantiates this simple PSViewController facade. Every
// section/row/navigation path above belongs to our own public UIKit table.
@interface V26RootController : V26PaneController
@end
@implementation V26RootController
@end
