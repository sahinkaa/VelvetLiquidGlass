#import "ManagerUIKit.h"
#import "../compat/SettingsStore.h"
#include <assert.h>
#import "../compat/CardStyle.h"
#include <math.h>
@implementation UIColor
+ (instancetype)clearColor {return [self new];}
+ (instancetype)colorFromP3String:(NSString *)string {return [self new];}
@end
int main(void) { @autoreleasepool {
    NSString *path=NSProcessInfo.processInfo.environment[@"VLG_PREFS_TEST_PATH"];
    NSDictionary *saved=@{@"backgroundIconAlpha":@42,@"backgroundIconAlpha_fixture.app":@60,@"borderEnabled":@YES,@"lineEnabled_fixture.app":@YES,@"appIconHidden":@YES};assert([saved writeToFile:path atomically:YES]);
    Velvet2PrefsManager *m=[[Velvet2PrefsManager alloc] initWithSuiteName:@"fixture"];
    assert([[m settingForKey:@"backgroundIconAlpha" withIdentifier:@"fixture.app"] isEqual:@60]);
    assert(![m objectForKey:@"borderEnabled"] && ![m settingForKey:@"lineEnabled" withIdentifier:@"fixture.app"] && ![m objectForKey:@"appIconHidden"]);
    assert([[m settingForKey:@"appearance" withIdentifier:@"fixture.app"] isEqual:@"dark"]);
    assert([m saveValue:@"default" forKey:@"appearance" error:NULL]);assert([[m objectForKey:@"appearance"] isEqual:@"dark"]);
    assert([m saveValue:@"light" forKey:@"appearance" error:NULL]);assert([[m settingForKey:@"appearance" withIdentifier:@"fixture.app"] isEqual:@"light"]);
    [m setTransientValue:@0 forKey:@"backgroundIconAlpha_fixture.app"];
    assert([[m settingForKey:@"backgroundIconAlpha" withIdentifier:@"fixture.app"] isEqual:@0]);
    assert([[[NSDictionary dictionaryWithContentsOfFile:path] objectForKey:@"backgroundIconAlpha_fixture.app"] isEqual:@60]);
    [m clearTransientValueForKey:@"backgroundIconAlpha_fixture.app"];
    assert([[m settingForKey:@"backgroundIconAlpha" withIdentifier:@"fixture.app"] isEqual:@60]);
    assert([m saveValue:@0 forKey:@"backgroundIconAlpha_fixture.app" error:NULL]);
    assert([[m settingForKey:@"backgroundIconAlpha" withIdentifier:@"fixture.app"] isEqual:@0]);
    assert([m saveValue:nil forKey:@"backgroundIconAlpha_fixture.app" error:NULL]);
    assert([[m settingForKey:@"backgroundIconAlpha" withIdentifier:@"fixture.app"] isEqual:@42]);
    [m setTransientValue:@100 forKey:@"backgroundIconAlpha"];
    assert([[m settingForKey:@"backgroundIconAlpha" withIdentifier:@"fixture.app"] isEqual:@100]);
    [m clearTransientValueForKey:@"backgroundIconAlpha"];
    assert([m saveValue:@100 forKey:@"backgroundIconAlpha" error:NULL]);
    assert([[m objectForKey:@"backgroundIconAlpha"] isEqual:@100]);
    assert([m saveValue:@61 forKey:@"backgroundIconAlpha_fixture.app" error:NULL]);
    assert([m saveValue:@17 forKey:@"backgroundIconAlpha_fixture.app2" error:NULL]);
    assert([m saveValue:@YES forKey:@"lineEnabled_fixture.app" error:NULL]);
    [m setTransientValue:@3 forKey:@"shadowWidth_fixture.app"];
    [m setTransientValue:@9 forKey:@"shadowWidth_fixture.app2"];
    assert(![m resetIdentifier:@"" error:NULL]);
    assert([m resetIdentifier:@"fixture.app" error:NULL]);
    assert([[m settingForKey:@"backgroundIconAlpha" withIdentifier:@"fixture.app"] isEqual:@100]);
    assert([[m settingForKey:@"backgroundIconAlpha" withIdentifier:@"fixture.app2"] isEqual:@17]);
    assert([[m settingForKey:@"shadowWidth" withIdentifier:@"fixture.app"] isEqual:@5]);
    assert([[m settingForKey:@"shadowWidth" withIdentifier:@"fixture.app2"] isEqual:@9]);
    assert(![NSDictionary dictionaryWithContentsOfFile:path][@"lineEnabled_fixture.app"]);
    assert([[m objectForKey:@"backgroundIconAlpha"] isEqual:@100]);
    assert([m saveValue:@19 forKey:@"cornerRadiusCustom" error:NULL]);
    assert(fabs([[m settingForKey:@"cornerRadiusPercent" withIdentifier:@"fixture.app"] doubleValue]-VLGLegacyRadiusPercent(19))<.001);
    assert([m saveValue:@50 forKey:@"cornerRadiusCustom_fixture.app" error:NULL]);
    assert([[m settingForKey:@"cornerRadiusPercent" withIdentifier:@"fixture.app"] doubleValue]==100);
    assert([m saveValue:@0 forKey:@"cornerRadiusPercent_fixture.app" error:NULL]);
    assert([[m settingForKey:@"cornerRadiusPercent" withIdentifier:@"fixture.app"] doubleValue]==0);
    assert([m saveValue:@100 forKey:@"cornerRadiusPercent" error:NULL]);
    assert([[m settingForKey:@"cornerRadiusPercent" withIdentifier:@"fixture.other"] doubleValue]==100);
    assert([NSDictionary dictionaryWithContentsOfFile:path][@"cornerRadiusCustom_fixture.app"]); // Legacy keys preserved for rollback.
    [m setTransientValue:@73 forKey:@"cornerRadiusPercent_fixture.app"];
    assert([[m settingForKey:@"cornerRadiusPercent" withIdentifier:@"fixture.app"] doubleValue]==73);
    assert([m resetIdentifier:@"fixture.app" error:NULL]);
    assert([[m settingForKey:@"cornerRadiusPercent" withIdentifier:@"fixture.app"] doubleValue]==100);
    assert([[m settingForKey:@"titleIconShade" withIdentifier:@"fixture.app"] doubleValue]==0);
    assert([m saveValue:@-40 forKey:@"titleIconShade" error:NULL]);
    assert([[m settingForKey:@"titleIconShade" withIdentifier:@"fixture.app"] doubleValue]==-40);
    assert([m saveValue:@200 forKey:@"titleIconShade_fixture.app" error:NULL]);assert([[m settingForKey:@"titleIconShade" withIdentifier:@"fixture.app"] doubleValue]==100);
    [m setTransientValue:@-200 forKey:@"titleIconShade_fixture.app"];assert([[m settingForKey:@"titleIconShade" withIdentifier:@"fixture.app"] doubleValue]==-100);
    [m clearTransientValueForKey:@"titleIconShade_fixture.app"];
    assert([m resetIdentifier:@"fixture.app" error:NULL]);assert([[m settingForKey:@"titleIconShade" withIdentifier:@"fixture.app"] doubleValue]==-40);
    [m setTransientValue:@0 forKey:@"shadowIconAlpha"];
    assert([m reset:NULL]);assert([[m objectForKey:@"shadowIconAlpha"] isEqual:@100]);
    assert([NSDictionary dictionaryWithContentsOfFile:path].count==0);
    // Exercise automatic migration through the production manager, not only
    // the storage helper. A corrupt import must also block saves and resets.
    NSData *exported=[m exportSettingsData:NULL];assert(exported);
    assert([m saveValue:@88 forKey:@"dateIconAlpha_import.app" error:NULL]);
    [m setTransientValue:@99 forKey:@"shadowIconAlpha"];
    assert([m importSettingsData:exported error:NULL]);
    assert(![NSDictionary dictionaryWithContentsOfFile:path][@"dateIconAlpha_import.app"]);
    assert([[m settingForKey:@"shadowIconAlpha" withIdentifier:nil] doubleValue]==100);
    NSData *beforeInvalid=[NSData dataWithContentsOfFile:path];
    assert(![m importSettingsData:[@"bad" dataUsingEncoding:NSUTF8StringEncoding] error:NULL]);
    assert([[NSData dataWithContentsOfFile:path] isEqual:beforeInvalid]);
    puts("PASS: production preference manager exports saved values, imports a full snapshot, clears transient edits and rejects invalid import without changing preferences");
    NSString *newPath=[path stringByAppendingString:@".new-domain"],*legacyPath=[path stringByAppendingString:@".legacy"];
    NSDictionary *legacy=@{@"dateEnabled":@YES,@"dateIconShade_fixture.app":@-27,@"dateType":@"icon",@"futureKey":@[@1,@2]};
    assert([legacy writeToFile:legacyPath atomically:YES]);NSData *legacyBytes=[NSData dataWithContentsOfFile:legacyPath];
    setenv("VLG_PREFS_TEST_PATH",newPath.fileSystemRepresentation,1);setenv("VLG_LEGACY_PREFS_TEST_PATH",legacyPath.fileSystemRepresentation,1);
    Velvet2PrefsManager *migrated=[[Velvet2PrefsManager alloc] initWithSuiteName:@"fixture.new"];
    assert([[migrated settingForKey:@"dateIconShade" withIdentifier:@"fixture.app"] isEqual:@-27]);
    assert([[NSData dataWithContentsOfFile:newPath] isEqual:legacyBytes]);
    assert([migrated saveValue:@14 forKey:@"dateIconShade_fixture.app" error:NULL]);assert([[NSData dataWithContentsOfFile:legacyPath] isEqual:legacyBytes]);
    assert([migrated reset:NULL]);Velvet2PrefsManager *afterReset=[[Velvet2PrefsManager alloc] initWithSuiteName:@"fixture.new"];
    assert(![[afterReset settingForKey:@"dateEnabled" withIdentifier:@"fixture.app"] boolValue]);
    NSString *badPath=[path stringByAppendingString:@".corrupt-import"];setenv("VLG_PREFS_TEST_PATH",badPath.fileSystemRepresentation,1);
    NSData *broken=[@"broken legacy" dataUsingEncoding:NSUTF8StringEncoding];assert([broken writeToFile:legacyPath atomically:YES]);
    Velvet2PrefsManager *blocked=[[Velvet2PrefsManager alloc] initWithSuiteName:@"fixture.new"];NSError *error=nil;
    assert(![blocked saveValue:@0 forKey:@"backgroundIconAlpha" error:&error] && error);
    assert(![blocked reset:NULL] && ![blocked resetIdentifier:@"fixture.app" error:NULL]);
    assert(![NSFileManager.defaultManager fileExistsAtPath:badPath]);assert([[NSData dataWithContentsOfFile:legacyPath] isEqual:broken]);
    assert([legacyBytes writeToFile:legacyPath atomically:YES]);[blocked reloadFromDisk];
    assert([[blocked settingForKey:@"dateIconShade" withIdentifier:@"fixture.app"] isEqual:@-27]);
    unsetenv("VLG_LEGACY_PREFS_TEST_PATH");
    puts("PASS: production manager imports the old domain automatically, retains scoped Time controls, preserves the old file, respects reset across launches and blocks writes/reset during a corrupt import until recovery");
    puts("PASS: production preference-manager transient preview isolation, exact zero/100 persistence, per-app inheritance, retired-key suppression and atomic app-only reset isolation");
} return 0; }
