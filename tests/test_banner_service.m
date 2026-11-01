#define main VLGAssemblyMain
#include "test_banner.m"
#undef main
#include "../compat/TestBannerSpringBoard.m"
static NSString *frontID=@"com.apple.Preferences";
static id currentDestination;
static BOOL throwTitle,throwFormat2,throwPost;
@interface TestFront:NSObject
- (id)bundleIdentifier;
- (id)localizedName;
@end
@implementation TestFront
- (id)bundleIdentifier{return frontID;}
- (id)localizedName{return @"Fixture App";}
@end
@interface TestDispatcher:NSObject
- (id)bannerDestination;
@end
@implementation TestDispatcher
- (id)bannerDestination{return currentDestination;}
@end
@implementation UIImage
+ (id)systemImageNamed:(NSString *)name {return [self new];}
+ (id)_applicationIconImageForBundleIdentifier:(id)identifier format:(NSInteger)format scale:(double)scale {assert((format==2 || format==5) && scale==3);if(throwFormat2 && format==2)[NSException raise:NSInvalidArgumentException format:@"Fixture unsupported icon format"];return [self new];}
@end
@implementation UIScreen
+ (id)mainScreen{return [self new];}
- (double)scale{return 3;}
@end
@implementation UIApplication
+ (id)sharedApplication {static id app;static dispatch_once_t once;dispatch_once(&once,^{app=[self new];});return app;}
- (id)_accessibilityFrontMostApplication{return [TestFront new];}
- (id)notificationDispatcher{return [TestDispatcher new];}
@end
@interface VLGFixtureApplicationWorkspace:NSObject
@end
@implementation VLGFixtureApplicationWorkspace
+ (id)defaultWorkspace{return [self new];}
- (id)applicationForBundleIdentifier:(id)identifier{if(throwTitle)[NSException raise:NSInvalidArgumentException format:@"Fixture optional title denied"];return [TestFront new];}
@end
@interface TestDestination:NSObject
@property(nonatomic) unsigned posts,withdrawals;
@property(nonatomic,strong) id presented;
@end
@implementation TestDestination
- (id)identifier{return @"Banner";}
- (void)postNotificationRequest:(id)request {if(throwPost)[NSException raise:NSInvalidArgumentException format:@"Fixture post denied"];// The native destination indexes actions by context. An empty NSArray is
    // ABI-compatible as an object argument but throws here on the real device.
    NSDictionary *actions=[(TestRequest *)request supplementaryActions];
    (void)[actions objectForKey:@"default"];
    assert([actions isKindOfClass:NSDictionary.class] && actions.count==0);
    ++self.posts;self.presented=request;}
- (void)withdrawNotificationRequest:(id)request {++self.withdrawals;if(self.presented==request)self.presented=nil;}
- (id)_presentedNotificationRequest{return self.presented;}
@end
@interface WrongDestination:NSObject
@end
@implementation WrongDestination
- (id)identifier{return @"Banner";}
- (double)postNotificationRequest:(id)request {abort();}
- (void)withdrawNotificationRequest:(id)request {abort();}
@end
int main(int argc,const char **argv) {@autoreleasepool {
    assert(argc==2);setenv("VLG_TEST_COMMAND_FOLDER",argv[1],1);
    objc_registerClassPair(objc_allocateClassPair(TestRequest.class,"NCNotificationRequest",0));
    objc_registerClassPair(objc_allocateClassPair(TestOptions.class,"NCMutableNotificationOptions",0));
    TestDestination *destination=[TestDestination new];currentDestination=destination;
    assert(VLGRequestTestBanner(@"net.fixture",NULL));VLGHandleCommand();
    assert(destination.posts==1 && VLGRequest==destination.presented && VLGIsOurs(destination.presented));
    assert(![(TestRequest *)VLGRequest options].dismissAutomatically);
    VLGHandleCommand();assert(destination.posts==1); // Same command is not replayed.
    NSMutableDictionary *cancel=[[NSDictionary dictionaryWithContentsOfFile:VLGTestCommandPath()] mutableCopy];
    cancel[@"action"]=@"cancel";cancel[@"nonce"]=NSUUID.UUID.UUIDString;cancel[@"session"]=NSUUID.UUID.UUIDString;
    assert([cancel writeToFile:VLGTestCommandPath() atomically:YES]);VLGHandleCommand();
    assert(destination.withdrawals==0 && VLGRequest); // Another session cannot dismiss it.
    VLGCancelTestBanner();VLGHandleCommand();assert(destination.withdrawals==1 && !VLGRequest && !destination.presented);
    frontID=@"com.apple.mobilemail";assert(VLGRequestTestBanner(@"net.fixture",NULL));VLGHandleCommand();assert(destination.posts==1);
    frontID=@"com.apple.Preferences";currentDestination=[WrongDestination new];
    assert(VLGRequestTestBanner(@"net.fixture",NULL));VLGHandleCommand();assert(!VLGRequest);
    currentDestination=destination;assert(VLGRequestTestBanner(@"net.fixture",NULL));VLGHandleCommand();assert(destination.posts==2);
    id real=[NSObject new];destination.presented=real;VLGWithdraw();assert(destination.presented==real);
    // A stale command cannot become a delayed notification in a new session.
    cancel=[[NSDictionary dictionaryWithContentsOfFile:VLGTestCommandPath()] mutableCopy];cancel[@"date"]=[NSDate dateWithTimeIntervalSinceNow:-16];cancel[@"nonce"]=NSUUID.UUID.UUIDString;
    assert([cancel writeToFile:VLGTestCommandPath() atomically:YES]);VLGHandleCommand();assert(destination.posts==2);
    throwTitle=YES;throwFormat2=YES;
    assert(VLGRequestTestBanner(@"net.fixture",NULL));VLGHandleCommand();assert(destination.posts==3 && VLGRequest);
    assert(V26TestReportSnapshot()[@"testBanner.titleFailure"] && V26TestReportSnapshot()[@"testBanner.iconFailure.2"]);
    throwPost=YES;assert(VLGRequestTestBanner(@"net.fixture",NULL));VLGHandleCommand();assert(!VLGRequest);
    NSDictionary *failure=V26TestReportSnapshot()[@"testBanner.failure.native banner presentation"];
    assert([failure[@"reason"] isEqual:@"Fixture post denied"] && [failure[@"name"] isEqual:NSInvalidArgumentException]);
    NSDictionary *reply=[NSDictionary dictionaryWithContentsOfFile:[VLGTestCommandPath().stringByDeletingLastPathComponent stringByAppendingPathComponent:@"test-banner-result.plist"]];
    assert([reply[@"message"] containsString:@"native banner presentation"]);
    puts("PASS: optional title/icon exceptions preserve posting; native presentation exceptions retain stage/reason and send visible feedback without touching unrelated banners");
    puts("PASS: production SpringBoard test service posts only in foreground Settings, rejects wrong ABIs/stale/duplicate commands, cancels by session, leaves unrelated banners alone and retrieves the system-rendered icon");
}return 0;}
