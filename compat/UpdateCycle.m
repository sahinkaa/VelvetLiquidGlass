#import "UpdateCycle.h"
@interface V26UpdateCycle ()
@property(nonatomic) unsigned attempts;
@property(nonatomic) BOOL scheduled;
@property(nonatomic) NSUInteger generation;
@property(nonatomic, copy) V26Schedule scheduler;
@end
@implementation V26UpdateCycle
- (instancetype)initWithOwner:(id)owner scheduler:(V26Schedule)scheduler {
    if ((self = [super init])) {
        self.owner = owner;
        self.scheduler = scheduler ?: ^(NSTimeInterval delay, dispatch_block_t block) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), dispatch_get_main_queue(), block);
        };
    }
    return self;
}
- (void)cancel { ++self.generation; self.scheduled = NO; }
- (void)reset { [self cancel]; self.attempts = 0; }
- (void)schedule:(void (^)(id))attempt {
    static const NSTimeInterval delays[] = {0, 1.0/60, .05, .15, .35, .5, 1, 2};
    if (self.scheduled || !self.owner || !attempt || self.attempts >= sizeof(delays)/sizeof(delays[0])) return;
    self.scheduled = YES;
    NSUInteger generation = self.generation;
    NSTimeInterval delay = delays[self.attempts++];
    __weak V26UpdateCycle *weakSelf = self;
    self.scheduler(delay, ^{
        V26UpdateCycle *cycle = weakSelf;
        id owner = cycle.owner;
        if (!cycle || !owner || cycle.generation != generation) return;
        cycle.scheduled = NO;
        attempt(owner);
    });
}
@end
@implementation V26PaletteEntry
@end
@interface V26PaletteCache ()
@property(nonatomic, strong) NSCache *entries;
@end
@implementation V26PaletteCache
- (instancetype)init {
    if ((self = [super init])) { self.entries = [NSCache new]; self.entries.countLimit = 128; }
    return self;
}
- (V26PaletteEntry *)entry:(id)key { return key ? [self.entries objectForKey:key] : nil; }
- (void)storeColor:(id)color image:(id)image key:(id)key {
    if (!color || !key) return;
    V26PaletteEntry *entry = [V26PaletteEntry new];entry.color = color;entry.image = image;
    [self.entries setObject:entry forKey:key];
}
- (void)clear { [self.entries removeAllObjects]; }
@end
