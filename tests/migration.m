#import <Foundation/Foundation.h>
#import "../compat/SettingsStore.h"
#include <assert.h>
int main(int argc,char **argv) {@autoreleasepool {
    assert(argc==2);NSString *folder=@(argv[1]);NSFileManager *fm=NSFileManager.defaultManager;
    NSString *legacy=[folder stringByAppendingPathComponent:@"com.noisyflake.velvet2.plist"],*path=[folder stringByAppendingPathComponent:@"com.sahinkaa.velvetliquidglass.plist"];
    NSDictionary *old=@{@"backgroundEnabled":@YES,@"titleColor":@"1 0 0 1",@"dateType":@"gradient",@"dateGradient1":@"0 1 0 1",@"dateIconShade_example.app":@-35,@"futureData":@[@1,@"kept"]};
    NSData *bytes=[NSPropertyListSerialization dataWithPropertyList:old format:NSPropertyListBinaryFormat_v1_0 options:0 error:NULL];assert([bytes writeToFile:legacy atomically:YES]);
    V26SettingsStore *store=[[V26SettingsStore alloc] initWithPath:path];
    dispatch_apply(24,dispatch_get_global_queue(QOS_CLASS_DEFAULT,0),^(size_t index){assert([store migrateFromPaths:@[legacy] error:NULL]);});
    assert([[NSData dataWithContentsOfFile:path] isEqual:bytes]);assert([[NSData dataWithContentsOfFile:legacy] isEqual:bytes]);
    assert([[store read:NULL] isEqual:old]);
    assert([store save:@42 forKey:@"dateIconShade_example.app" error:NULL]);
    assert([[NSData dataWithContentsOfFile:[path stringByAppendingString:@".before-velvet-liquid-glass"]] isEqual:bytes]);
    assert([store migrateFromPaths:@[legacy] error:NULL]);assert([[store read:NULL][@"dateIconShade_example.app"] isEqual:@42]);
    assert([[NSData dataWithContentsOfFile:legacy] isEqual:bytes]);
    assert([store reset:NULL]);assert([store migrateFromPaths:@[legacy] error:NULL]);assert([store read:NULL].count==0); // Never resurrect reset preferences.
    NSData *broken=[@"not a plist" dataUsingEncoding:NSUTF8StringEncoding];assert([broken writeToFile:path atomically:YES]);
    assert([store migrateFromPaths:@[legacy] error:NULL]);assert(![store read:NULL]);assert([[NSData dataWithContentsOfFile:path] isEqual:broken]);
    assert([fm removeItemAtPath:path error:NULL]);assert([broken writeToFile:legacy atomically:YES]);NSError *error=nil;
    assert(![store migrateFromPaths:@[legacy] error:&error] && error);assert(![fm fileExistsAtPath:path]);assert([[NSData dataWithContentsOfFile:legacy] isEqual:broken]);
    assert([fm removeItemAtPath:legacy error:NULL]);assert([store migrateFromPaths:@[legacy] error:NULL]);assert(![fm fileExistsAtPath:path]);
    assert([bytes writeToFile:legacy atomically:YES]);assert([store migrateFromPaths:@[legacy] error:NULL]);assert([[store read:NULL] isEqual:old]);
    puts("PASS: locked concurrent migration copies binary preferences exactly, preserves scoped Time values/unknown keys and legacy bytes, respects existing/reset/corrupt destinations, rejects corrupt legacy data and permits recovery");
}return 0;}
