#import <Foundation/Foundation.h>
#import "../compat/SettingsTransfer.h"
#import "../compat/SettingsStore.h"
#include <assert.h>
#include <math.h>
int main(int argc,char **argv) {@autoreleasepool {
    assert(argc==2);NSString *folder=@(argv[1]);
    assert([VLGSettingsExportFilename isEqual:@"Velvet - Liquid Glass settings.plist"]);
    NSDictionary *settings=@{@"enabled":@YES,@"backgroundEnabled":@YES,@"backgroundIconAlpha":@44.5,@"dateIconShade_example.app":@-37,@"titleType":@"gradient",@"titleGradient1":@"0 1 0 1",@"titleGradient2":@"0 0 1 0.6",@"futureValue":@[@1,@"preserved"]};
    NSError *error=nil;NSData *xml=VLGEncodeSettings(settings,&error);assert(xml && !error);
    assert([VLGDecodeSettings(xml,&error) isEqual:settings] && !error);
    NSData *binary=[NSPropertyListSerialization dataWithPropertyList:settings format:NSPropertyListBinaryFormat_v1_0 options:0 error:NULL];
    assert([VLGDecodeSettings(binary,&error) isEqual:settings]);
    assert(!VLGDecodeSettings([@"not a plist" dataUsingEncoding:NSUTF8StringEncoding],&error) && error);
    NSData *array=[NSPropertyListSerialization dataWithPropertyList:@[@1] format:NSPropertyListXMLFormat_v1_0 options:0 error:NULL];
    assert(!VLGDecodeSettings(array,&error) && error);
    assert(!VLGEncodeSettings(@{@"backgroundIconAlpha":@(NAN)},&error) && error);
    assert(!VLGEncodeSettings(@{@"backgroundIconAlpha":@[@42]},&error));
    assert(!VLGEncodeSettings(@{@"dateType":@42},&error));
    assert(!VLGEncodeSettings(@{@"titleColor":@[@1,@0,@0,@1]},&error));
    assert(!VLGEncodeSettings(@{@"titleColor":@"nan 0 0 1"},&error));
    assert(!VLGEncodeSettings(@{@"titleGradient1":@"0 0 1 2"},&error));
    assert(VLGEncodeSettings(@{@"enabled":@"YES",@"dateIconAlpha_example.app":@"50.25"},&error));
    NSMutableData *large=[NSMutableData dataWithLength:VLGSettingsMaxFileSize+1];assert(!VLGDecodeSettings(large,&error) && error);
    id nested=@1;for(unsigned i=0;i<20;++i)nested=@[nested];assert(!VLGEncodeSettings(@{@"future":nested},&error));
    NSString *path=[folder stringByAppendingPathComponent:@"transfer.plist"];
    V26SettingsStore *store=[[V26SettingsStore alloc] initWithPath:path];
    NSDictionary *old=@{@"enabled":@NO,@"dateIconShade_old.app":@99,@"titleType":@"color"};assert([old writeToFile:path atomically:YES]);
    NSData *before=[NSData dataWithContentsOfFile:path];assert([store replaceSettings:settings error:&error]);
    assert([[store read:NULL] isEqual:settings] && ![store read:NULL][@"dateIconShade_old.app"]);
    assert([[NSData dataWithContentsOfFile:[path stringByAppendingString:@".before-import.plist"]] isEqual:before]);
    assert([[NSData dataWithContentsOfFile:[path stringByAppendingString:@".before-velvet-liquid-glass"]] isEqual:before]);
    NSData *good=[NSData dataWithContentsOfFile:path];assert(![store replaceSettings:@{@"titleEnabled":@[]} error:&error]);assert([[NSData dataWithContentsOfFile:path] isEqual:good]);
    assert([store replaceSettings:@{} error:&error]);assert([store read:NULL].count==0);
    assert([[NSData dataWithContentsOfFile:[path stringByAppendingString:@".before-import.plist"]] isEqual:good]);
    NSData *broken=[@"broken saved preferences" dataUsingEncoding:NSUTF8StringEncoding];assert([broken writeToFile:path atomically:YES]);
    assert([store replaceSettings:settings error:&error]);assert([[store read:NULL] isEqual:settings]);
    assert([[NSData dataWithContentsOfFile:[path stringByAppendingString:@".before-import.plist"]] isEqual:broken]);
    // A failed backup must leave the current settings unchanged.
    NSFileManager *fm=NSFileManager.defaultManager;NSString *backup=[path stringByAppendingString:@".before-import.plist"];
    assert([fm removeItemAtPath:backup error:NULL]);assert([fm createDirectoryAtPath:backup withIntermediateDirectories:NO attributes:nil error:NULL]);
    good=[NSData dataWithContentsOfFile:path];assert(![store replaceSettings:old error:&error]);assert([[NSData dataWithContentsOfFile:path] isEqual:good]);
    puts("PASS: XML/binary export-import round trips preserve global/per-app settings and filename; invalid, nonfinite, oversized and deeply nested imports are rejected");
    puts("PASS: import replaces the complete snapshot atomically, removes stale app overrides, preserves latest/original backups, recovers corrupt current settings and aborts if backup fails");
}return 0;}
