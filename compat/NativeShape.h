#import <Foundation/Foundation.h>
// Calls only checked double/void methods on the caller's owned notification view.
@interface V26NativeShape : NSObject
@property(nonatomic, readonly) BOOL owned;
- (double)radiusOn:(id)target fallback:(double)fallback;
- (BOOL)applyRadius:(double)radius to:(id)target;
- (void)restore;
@end
