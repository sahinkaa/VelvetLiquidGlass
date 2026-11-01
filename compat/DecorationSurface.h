#ifdef V26_STYLE_HOST
#import "../tests/StyleUIKit.h"
#else
#import <UIKit/UIKit.h>
#endif
@interface V26DecorationSurface : NSObject
@property(nonatomic, strong, readonly) UIVisualEffectView *blur;
- (UIView *)applyToMaterial:(UIView *)material root:(UIView *)root stableBlur:(BOOL)stable hideBlur:(BOOL)hide;
- (void)restore;
@end
// Mask the glow's interior on its own layer, never on a native notification.
BOOL V26ConfigureOuterGlow(UIView *glow, CGRect cardFrame, CGFloat radius);

void V26MarkOwnedDecoration(UIView *view);
BOOL V26IsOwnedDecoration(UIView *view);
