#import <Foundation/Foundation.h>
#import "../compat/SettingsStore.h"
#import "../compat/Runtime.h"
#include <assert.h>

@interface ChangedPrivateView : NSObject {
    id _dateLabel;
    double _scalar;
}
@property(nonatomic) NSUInteger undefinedReads;
- (id)present;
- (double)scalar;
@end
@implementation ChangedPrivateView
- (instancetype)init { if ((self = [super init])) { _dateLabel = @"label"; _scalar = 12; } return self; }
- (id)present { return @"image"; }
- (double)scalar { return _scalar; }
- (id)valueForUndefinedKey:(NSString *)key { self.undefinedReads++; return [super valueForUndefinedKey:key]; }
- (id)exploding { [NSException raise:@"PrivateGetterChanged" format:@"fixture"]; return nil; }
@end

int main(int argc, char **argv) {
    @autoreleasepool {
        assert(argc == 2);
        ChangedPrivateView *view = [ChangedPrivateView new];
        BOOL originalThrew = NO;
        @try { [view valueForKey:@"removedProperty"]; }
        @catch (NSException *exception) { originalThrew = [exception.name isEqual:NSUndefinedKeyException]; }
        assert(originalThrew && view.undefinedReads == 1);
        for (unsigned i = 0; i < 2000; i++) {
            assert(V26Object(view, @"removedProperty") == nil);
            assert(V26Object(view, @"scalar") == nil);
            assert(V26Object(view, @"exploding") == nil);
            assert([V26Object(view, @"dateLabel") isEqual:@"label"]);
            assert([V26Object(view, @"present") isEqual:@"image"]);
        }
        assert(view.undefinedReads == 1); // No KVC exception / forwarding path.
        assert(V26Object(nil, @"present") == nil);
        assert(!V26Method(ChangedPrivateView.class, @selector(scalar), "@", 0));
        assert(V26Method(ChangedPrivateView.class, @selector(present), "@", 0));

        NSString *folder = @(argv[1]);
        NSString *path = [folder stringByAppendingPathComponent:@"prefs.plist"];
        NSDictionary *imported = @{@"shadowEnabled": @YES, @"shadowIconAlpha": @48.4125,
            @"shadowWidth": @3.1465, @"backgroundEnabled": @YES, @"borderEnabled": @YES,
            @"backgroundBlurHidden": @NO, @"unknownFutureSetting": @[@1, @2]};
        assert([imported writeToFile:path atomically:YES]);
        NSData *originalBytes = [NSData dataWithContentsOfFile:path];
        V26SettingsStore *store = [[V26SettingsStore alloc] initWithPath:path];
        NSMutableDictionary *effective = [V26Defaults() mutableCopy];
        [effective addEntriesFromDictionary:[store read:nil]];
        assert(V26Requirement(@"shadowEnabled", effective));
        assert(V26Requirement(@"shadowEnabled&shadowType=icon", effective));
        assert(!V26Requirement(@"shadowEnabled&shadowType=color", effective));
        assert(V26Requirement(@"!appIconHidden", effective));
        assert(V26Requirement(nil, effective));
        NSString *baseKey = @"shadowWidth";
        NSString *appKey = V26PreferenceKey(baseKey, @"com.example.app");
        assert([appKey isEqual:@"shadowWidth_com.example.app"]);
        for (unsigned i = 0; i < 30; ++i) assert([store save:@(i % 10 + 1) forKey:appKey error:nil]);
        NSDictionary *result = [store read:nil];
        assert([result[baseKey] isEqual:imported[baseKey]]);
        assert([result[@"unknownFutureSetting"] isEqual:imported[@"unknownFutureSetting"]]);
        assert([result[appKey] isEqual:@10]);
        assert([result count] == [imported count] + 1);
        assert([[NSData dataWithContentsOfFile:[path stringByAppendingString:@".before-velvet-liquid-glass"]] isEqual:originalBytes]);
        assert([store save:nil forKey:appKey error:nil]);
        assert([[store read:nil] isEqual:imported]);
        // Different instances merge fresh disk state instead of losing changes.
        V26SettingsStore *other = [[V26SettingsStore alloc] initWithPath:path];
        assert([store save:@2 forKey:@"borderWidth" error:nil]);
        assert([other save:@4 forKey:@"shadowWidth" error:nil]);
        assert([[[store read:nil] objectForKey:@"borderWidth"] isEqual:@2]);
        assert([store reset:nil]);
        assert([[store read:nil] count] == 0);
        assert([[NSData dataWithContentsOfFile:[path stringByAppendingString:@".before-velvet-liquid-glass"]] isEqual:originalBytes]);
        NSData *corrupt = [@"not a plist" dataUsingEncoding:NSUTF8StringEncoding];
        assert([corrupt writeToFile:path atomically:YES]);
        NSError *error = nil;
        assert(![other save:@5 forKey:@"shadowWidth" error:&error]);
        assert(error && [[NSData dataWithContentsOfFile:path] isEqual:corrupt]);
        for(unsigned i=0;i<400;++i)V26Event(@"rollingDiagnostics",@{@"sample":@(i)});
        NSArray *recent=V26TestReportSnapshot()[@"events"];assert(recent.count==128 && [recent.lastObject[@"sample"] isEqual:@399]);
        puts("PASS: bounded diagnostics retain new events beyond the previous lifetime cap");
        puts("PASS: missing-private-property regression, ABI rejection, imported defaults, conditional Glow controls, repeated per-app writes, merge, backup and corrupt-file preservation");
    }
    return 0;
}
