#import <Foundation/Foundation.h>
#import "../compat/BannerTypography.h"
#include <assert.h>
#include <math.h>
int main(void) {@autoreleasepool {
    NSString *path=NSProcessInfo.processInfo.environment[@"VLG_FONT_TEST_PATH"];assert(path.length);
    [NSFileManager.defaultManager createDirectoryAtPath:path.stringByDeletingLastPathComponent withIntermediateDirectories:YES attributes:nil error:NULL];
    [@{@"os":@"oldOS",@"version":@1,@"sizes":@{@"title":@15,@"message":@15,@"date":@13}} writeToFile:path atomically:YES];
    assert(!VLGReadBannerTypography());
    NSDictionary *initial=@{@"title":@15,@"message":@15,@"date":@13};
    assert([VLGInitialBannerTypography() isEqual:initial]);
    assert(VLGStoreBannerTypography(initial));assert([VLGReadBannerTypography() isEqual:initial]);
    puts("PASS: cold-open notification typography starts at 15/15/13 points and matches the initial native compact profile without a first-banner size change");
    assert(!VLGStoreBannerTypography(@{@"title":@17}));
    assert(!VLGStoreBannerTypography(@{@"title":@17,@"message":@"17",@"date":@15}));
    assert(!VLGStoreBannerTypography(@{@"title":@(NAN),@"message":@17,@"date":@15}));
    assert(!VLGStoreBannerTypography(@{@"title":@1000,@"message":@17,@"date":@15}));
    NSDictionary *sizes=@{@"title":@17,@"message":@17,@"date":@15};
    assert(VLGStoreBannerTypography(@{@"title":@17,@"message":@17,@"date":@15,@"notificationText":@"must not be stored"}));
    assert([VLGReadBannerTypography() isEqual:sizes]);
    NSDictionary *saved=[NSDictionary dictionaryWithContentsOfFile:path];assert([saved[@"sizes"] isEqual:sizes] && saved.count==3);
    NSData *before=[NSData dataWithContentsOfFile:path];assert(VLGStoreBannerTypography(sizes));assert([before isEqual:[NSData dataWithContentsOfFile:path]]);
    dispatch_semaphore_t done=dispatch_semaphore_create(0);
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_DEFAULT,0),^{assert(!VLGReadBannerTypography() && !VLGStoreBannerTypography(sizes));dispatch_semaphore_signal(done);});
    dispatch_semaphore_wait(done,DISPATCH_TIME_FOREVER);
    puts("PASS: banner font-size cache persists only bounded numeric sizes, rejects stale-OS/malformed inputs, preserves unchanged bytes and excludes off-main access and notification text");
}return 0;}
