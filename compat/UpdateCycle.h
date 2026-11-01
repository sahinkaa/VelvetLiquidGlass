#import <Foundation/Foundation.h>

typedef void (^V26Schedule)(NSTimeInterval, dispatch_block_t);
@interface V26UpdateCycle : NSObject
@property(nonatomic, weak) id owner;
@property(nonatomic, readonly) unsigned attempts;
@property(nonatomic, readonly) BOOL scheduled;
- (instancetype)initWithOwner:(id)owner scheduler:(V26Schedule)scheduler;
- (void)cancel;
- (void)reset;
- (void)schedule:(void (^)(id owner))attempt;
@end

@interface V26PaletteEntry : NSObject
@property(nonatomic, weak) id image;
@property(nonatomic, strong) id color;
@end
@interface V26PaletteCache : NSObject
- (V26PaletteEntry *)entry:(id)key;
- (void)storeColor:(id)color image:(id)image key:(id)key;
- (void)clear;
@end
