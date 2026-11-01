#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import "../compat/UpdateCycle.h"
#import "../compat/NativeShape.h"
#import "../compat/Runtime.h"
#include <assert.h>
#include <math.h>

@interface NativePlatter : NSObject
@property double value;
@property unsigned writes;
@property BOOL throws;
- (double)_continuousCornerRadius;
- (void)_setContinuousCornerRadius:(double)value;
@end
@implementation NativePlatter
- (double)_continuousCornerRadius { return self.value; }
- (void)_setContinuousCornerRadius:(double)value {
    ++self.writes;
    if (self.throws) [NSException raise:@"NativeFailure" format:@"fixture"];
    self.value = value;
}
@end
@interface LegacyPlatter : NSObject
@property double value;
- (double)_cornerRadius;
- (void)_setCornerRadius:(double)value;
@end
@implementation LegacyPlatter
- (double)_cornerRadius { return self.value; }
- (void)_setCornerRadius:(double)value { self.value = value; }
@end
@interface WrongShape : NSObject
- (CGRect)_continuousCornerRadius;
- (void)_setContinuousCornerRadius:(float)value;
@end
@implementation WrongShape
- (CGRect)_continuousCornerRadius { abort(); }
- (void)_setContinuousCornerRadius:(float)value { abort(); }
@end
@interface BoolRequestFixture : NSObject
- (bool)_setNotificationRequest:(id)request;
@end
@implementation BoolRequestFixture
- (bool)_setNotificationRequest:(id)request { return request != nil; }
@end
int main(void) { @autoreleasepool {
    assert(V26Method(BoolRequestFixture.class, @selector(_setNotificationRequest:), "B", 1));
    assert(!V26Method(BoolRequestFixture.class, @selector(_setNotificationRequest:), "v", 1));
    NSMutableArray *queue = [NSMutableArray array];
    NSMutableArray *delays = [NSMutableArray array];
    V26Schedule scheduler = ^(NSTimeInterval delay, dispatch_block_t block) { [delays addObject:@(delay)];[queue addObject:[block copy]]; };
    NSObject *owner = [NSObject new];
    V26UpdateCycle *cycle = [[V26UpdateCycle alloc] initWithOwner:owner scheduler:scheduler];
    __block unsigned callbacks = 0;
    __weak V26UpdateCycle *weakCycle = cycle;
    __block __weak void (^weakAttempt)(id);
    void (^attempt)(id) = ^(id current) { assert(current == owner); ++callbacks; [weakCycle schedule:weakAttempt]; };
    weakAttempt = attempt;
    [cycle schedule:attempt];[cycle schedule:attempt];assert(queue.count == 1);
    while (queue.count) { dispatch_block_t block = queue[0];[queue removeObjectAtIndex:0];block(); }
    assert(callbacks == 8 && cycle.attempts == 8 && !cycle.scheduled);
    assert(delays.count == 8 && [delays[0] doubleValue] == 0 && [delays[1] doubleValue] < .017);
    [cycle reset];[cycle schedule:^(id current) { ++callbacks; }];
    dispatch_block_t obsolete = queue[0];[queue removeAllObjects];
    [cycle reset];[cycle schedule:^(id current) { ++callbacks; }];
    obsolete();assert(callbacks == 8 && cycle.scheduled);
    dispatch_block_t live = queue[0];[queue removeAllObjects];live();assert(callbacks == 9 && !cycle.scheduled);
    [cycle schedule:^(id current) { abort(); }];[cycle cancel];
    ((dispatch_block_t)queue[0])();[queue removeAllObjects];
    __weak NSObject *weakOwner;
    V26UpdateCycle *orphan;
    @autoreleasepool { NSObject *temporary = [NSObject new]; weakOwner = temporary; orphan = [[V26UpdateCycle alloc] initWithOwner:temporary scheduler:scheduler]; [orphan schedule:^(id current) { abort(); }]; }
    assert(!weakOwner);((dispatch_block_t)queue[0])();[queue removeAllObjects];
    V26PaletteCache *cache = [V26PaletteCache new];
    id key = @[@"app",@2,@"actual-icon-a"], other = @[@"app",@2,@"actual-icon-b"];
    NSObject *color = [NSObject new];
    __weak NSObject *weakImage;
    @autoreleasepool { NSObject *image = [NSObject new]; weakImage = image; [cache storeColor:color image:image key:key];assert([cache entry:key].image == image); }
    assert(!weakImage && [cache entry:key].color == color && ![cache entry:other]);
    assert([cache entry:[key copy]].color == color);
    [cache storeColor:nil image:nil key:key];assert([cache entry:key].color == color);
    [cache clear];assert(![cache entry:key]);
    NativePlatter *platter = [NativePlatter new];platter.value = 25;
    V26NativeShape *shape = [V26NativeShape new];
    assert([shape applyRadius:10 to:platter] && platter.value == 10 && platter.writes == 1);
    assert([shape applyRadius:10 to:platter] && platter.writes == 1);
    LegacyPlatter *legacy = [LegacyPlatter new];legacy.value = 22;
    assert([shape radiusOn:legacy fallback:1] == 22); // a query cannot change restoration selectors
    [shape restore];assert(platter.value == 25 && platter.writes == 2);
    assert([shape applyRadius:7 to:platter]);platter.value = 30;
    [shape restore];assert(platter.value == 30); // do not overwrite a newer native/foreign value
    assert([shape applyRadius:8 to:legacy] && legacy.value == 8);
    assert([shape applyRadius:9 to:platter] && legacy.value == 22);
    [shape restore];assert(platter.value == 30);
    assert(![shape applyRadius:NAN to:platter] && ![shape applyRadius:-1 to:platter]);
    assert(![shape applyRadius:10 to:[WrongShape new]]);
    assert([shape radiusOn:[WrongShape new] fallback:25] == 25);
    unsigned baselineWrites = platter.writes;
    for (unsigned i=0; i<1000; ++i) { platter.value=25; [shape applyRadius:3 to:platter]; }
    assert(platter.writes == baselineWrites + 4); // a native override cannot cause an unbounded layout loop
    [shape restore];
    dispatch_semaphore_t done = dispatch_semaphore_create(0);
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{ assert(![shape applyRadius:6 to:platter]);dispatch_semaphore_signal(done); });
    dispatch_semaphore_wait(done, DISPATCH_TIME_FOREVER);
    platter.throws = YES;unsigned before = platter.writes;BOOL caught = NO;
    @try { [shape applyRadius:2 to:platter]; } @catch (NSException *exception) { caught = YES; }
    assert(caught && platter.writes == before + 1); // never retry a throwing native setter
    puts("PASS: bounded eight-attempt scheduling, coalescing, generation cancellation and weak-owner lifetime");
    puts("PASS: icon-description cache separation, retained color with weak image, cache invalidation");
    puts("PASS: typed native radius forwarding/readback, idempotence, restoration ownership, alternate target, wrong ABI, native-override write bound, off-main rejection and native exception propagation");
} return 0; }
