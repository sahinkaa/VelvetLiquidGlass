#import "../compat/TestBanner.h"
#include <assert.h>
@interface TestOptions : NSObject <NSCopying,NSMutableCopying>
@property(nonatomic) BOOL dismissAutomatically,canPlaySound,preventsAutomaticLock,suppressesAlertsWhenAppIsActive;
@end
@implementation TestOptions
- (id)copyWithZone:(NSZone *)zone{return self;}
- (id)mutableCopyWithZone:(NSZone *)zone{return self;}
@end
@interface TestContent : NSObject <NSCopying,NSMutableCopying>
@property(nonatomic,copy) NSArray *icons;
@end
@implementation TestContent
- (id)copyWithZone:(NSZone *)zone{return self;}
- (id)mutableCopyWithZone:(NSZone *)zone{return self;}
@end
@interface TestRequest : NSObject <NSCopying,NSMutableCopying>
@property(nonatomic,strong) TestContent *content;
@property(nonatomic,strong) TestOptions *options;
@property(nonatomic,strong) id sound,defaultAction,cancelAction,clearAction,closeAction,silenceAction,inlineAction;
@property(nonatomic,copy) NSDictionary *supplementaryActions;
@property(nonatomic,copy) NSDictionary *context;
@property(nonatomic,copy) NSString *section,*notificationID,*destination;
+ (id)notificationRequestWithSectionId:(id)section notificationId:(id)identifier threadId:(id)thread title:(id)title message:(id)message timestamp:(id)date destination:(id)destination;
@end
@implementation TestRequest
+ (id)notificationRequestWithSectionId:(id)section notificationId:(id)identifier threadId:(id)thread title:(id)title message:(id)message timestamp:(id)date destination:(id)destination {
    assert([date isKindOfClass:NSDate.class]);assert([message containsString:@"Test Banner"]);
    TestRequest *request=[self new];request.section=section;request.notificationID=identifier;request.destination=destination;
    request.options=[TestOptions new];request.content=[TestContent new];request.options.dismissAutomatically=YES;
    request.options.canPlaySound=YES;request.options.preventsAutomaticLock=YES;request.options.suppressesAlertsWhenAppIsActive=YES;
    request.context=@{@"nativeFixtureMarker":@YES};request.sound=@"sound";request.defaultAction=@"launch app";request.supplementaryActions=@{@"default":@[@"action"]};
    return request;
}
- (NSString *)notificationIdentifier {return self.notificationID;}
- (id)copyWithZone:(NSZone *)zone{return self;}
- (id)mutableCopyWithZone:(NSZone *)zone{return self;}
@end
@interface BadFactory:NSObject
+ (id)notificationRequestWithSectionId:(id)section notificationId:(id)identifier threadId:(id)thread title:(id)title message:(id)message timestamp:(double)date destination:(id)destination;
@end
@implementation BadFactory
+ (id)notificationRequestWithSectionId:(id)a notificationId:(id)b threadId:(id)c title:(id)d message:(id)e timestamp:(double)f destination:(id)g {abort();}
@end
@interface ThrowingFactory:TestRequest
@end
@implementation ThrowingFactory
+ (id)notificationRequestWithSectionId:(id)a notificationId:(id)b threadId:(id)c title:(id)d message:(id)e timestamp:(id)f destination:(id)g {[NSException raise:@"Fixture" format:@"Guard only this test assembly"];return nil;}
@end
int main(int argc,const char **argv) {@autoreleasepool {
    NSString *prefix=@"com.sahinkaa.velvetliquidglass.test.fixture";NSError *error=nil;id icon=[NSObject new];
    TestRequest *request=VLGMakeTestNotification(TestRequest.class,TestOptions.class,@"net.whatsapp.WhatsApp",prefix,@"Banner",@"WhatsApp",icon,&error);
    assert(request && !error && !request.options.dismissAutomatically && !request.options.canPlaySound && !request.options.preventsAutomaticLock && !request.options.suppressesAlertsWhenAppIsActive);
    assert([request.section isEqual:@"net.whatsapp.WhatsApp"] && [request.notificationID isEqual:prefix] && [request.destination isEqual:@"Banner"]);
    assert(request.content.icons.count==1 && request.content.icons.firstObject==icon && !request.sound && !request.defaultAction && request.supplementaryActions.count==0 && [request.context[@"VelvetTestBanner"] boolValue]);
    assert([request.context[@"nativeFixtureMarker"] boolValue]);
    assert([request.supplementaryActions isKindOfClass:NSDictionary.class]);
    assert(![request.supplementaryActions objectForKey:@"default"]);
    assert(!VLGMakeTestNotification(BadFactory.class,TestOptions.class,@"net.example",prefix,@"Banner",@"Title",icon,&error) && error);
    assert(!VLGMakeTestNotification(ThrowingFactory.class,TestOptions.class,@"net.example",prefix,@"Banner",@"Title",icon,&error));
    assert(!VLGMakeTestNotification(TestRequest.class,TestOptions.class,@"net.example",@"real.notification",@"Banner",@"Title",icon,&error));
    assert(!VLGMakeTestNotification(TestRequest.class,TestOptions.class,@"net.example",prefix,@"Banner",@"Title",nil,&error));
    for(id value in @[@"../../bad",@"net.example\n",@"app",@42,NSNull.null])assert(!VLGValidTestIdentifier(value));
    NSDate *now=NSDate.date;NSMutableDictionary *command=[@{@"schema":@1,@"action":@"show",@"identifier":@"net.example",@"session":NSUUID.UUID.UUIDString,@"nonce":NSUUID.UUID.UUIDString,@"date":now} mutableCopy];
    assert(VLGValidateTestCommand(command,now));command[@"date"]=[now dateByAddingTimeInterval:-16];assert(!VLGValidateTestCommand(command,now));
    command[@"date"]=[now dateByAddingTimeInterval:3];assert(!VLGValidateTestCommand(command,now));command[@"date"]=now;
    command[@"nonce"]=@"not a UUID";assert(!VLGValidateTestCommand(command,now));command[@"nonce"]=NSUUID.UUID.UUIDString;
    command[@"action"]=@"cancel";[command removeObjectForKey:@"identifier"];assert(VLGValidateTestCommand(command,now));
    command[@"action"]=@"run-command";assert(!VLGValidateTestCommand(command,now));assert(!VLGValidateTestCommand(@[],now));
    assert(argc==2);setenv("VLG_TEST_COMMAND_FOLDER",argv[1],1);
    assert(VLGRequestTestBanner(@"net.example",&error));
    NSDictionary *saved=[NSDictionary dictionaryWithContentsOfFile:VLGTestCommandPath()];assert(VLGValidateTestCommand(saved,NSDate.date));
    NSString *session=saved[@"session"],*nonce=saved[@"nonce"];VLGCancelTestBanner();saved=[NSDictionary dictionaryWithContentsOfFile:VLGTestCommandPath()];
    assert([saved[@"session"] isEqual:session] && ![saved[@"nonce"] isEqual:nonce] && [saved[@"action"] isEqual:@"cancel"]);
    puts("PASS: native test request assembly validates every object/scalar ABI, sets request-only persistence, removes sound/actions, preserves selected app/icon; rejects malformed/stale commands and unsafe factory signatures; cancellation stays session-scoped");
}return 0;}
