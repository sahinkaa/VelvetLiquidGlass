#import "DecorationSurface.h"
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>
#include <math.h>
static char V26OwnedDecorationKey;
void V26MarkOwnedDecoration(UIView *view) {
    if (view) objc_setAssociatedObject(view, &V26OwnedDecorationKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
BOOL V26IsOwnedDecoration(UIView *view) {
    return view && [objc_getAssociatedObject(view, &V26OwnedDecorationKey) boolValue];
}
@interface V26DecorationSurface ()
@property(nonatomic, strong) UIVisualEffectView *blur;
@property(nonatomic, weak) UIView *material;
@property(nonatomic) BOOL previousHidden;
@property(nonatomic) BOOL ownsHidden;
@end
@implementation V26DecorationSurface
- (void)restore {
    if (!NSThread.isMainThread) return;
    if (self.ownsHidden && self.material.hidden) self.material.hidden = self.previousHidden;
    self.ownsHidden = NO;
    [self.blur removeFromSuperview];
}
- (UIView *)applyToMaterial:(UIView *)material root:(UIView *)root stableBlur:(BOOL)stable hideBlur:(BOOL)hide {
    if (!NSThread.isMainThread || !material || !root || ![material isDescendantOfView:root]) return nil;
    if (self.material != material) { [self restore];self.material = material; }
    // Construct the replacement before suppressing the native background.
    if (stable && !self.blur) {
        self.blur = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemMaterial]];
        V26MarkOwnedDecoration(self.blur);
        self.blur.userInteractionEnabled = NO;
        self.blur.accessibilityElementsHidden = YES;
        self.blur.clipsToBounds = YES;
    }
    if (stable || hide) {
        if (!self.ownsHidden) self.previousHidden = material.hidden;
        // A native callback may have made the material visible again.
        else if (!material.hidden) self.previousHidden = NO;
        self.ownsHidden = YES;
        material.hidden = YES;
    } else [self restore];
    if (!stable) { [self.blur removeFromSuperview];return material; }
    if (self.blur.superview != root) [root insertSubview:self.blur atIndex:0];
    self.blur.frame = [material convertRect:material.bounds toView:root];
    self.blur.hidden = hide;
    // Do not change the native material's alpha or the card's composite alpha.
    return self.blur;
}
@end

static char V26GlowGeometryKey;
BOOL V26ConfigureOuterGlow(UIView *glow, CGRect cardFrame, CGFloat radius) {
    if (!NSThread.isMainThread || !glow || !isfinite(cardFrame.origin.x) || !isfinite(cardFrame.origin.y) ||
        !isfinite(cardFrame.size.width) || !isfinite(cardFrame.size.height) ||
        cardFrame.size.width <= 0 || cardFrame.size.height <= 0 ||
        cardFrame.size.width > 4096 || cardFrame.size.height > 4096 || !isfinite(radius) || radius < 0) return NO;
    CGFloat shadow = glow.layer.shadowRadius;
    if (!isfinite(shadow) || shadow < 0) return NO;
    CGFloat stroke = MAX(1, MIN(16, shadow));
    CGFloat padding = MIN(128, ceil(MAX(1, shadow) * 3 + stroke / 2 + 2));
    glow.frame = CGRectInset(cardFrame, -padding, -padding);
    CGRect card = CGRectMake(padding, padding, cardFrame.size.width, cardFrame.size.height);
    radius = MIN(radius, MIN(card.size.width, card.size.height) / 2);
    NSArray *key = @[[NSValue valueWithCGRect:glow.bounds], [NSValue valueWithCGRect:card], @(radius), @(shadow)];
    if ([objc_getAssociatedObject(glow, &V26GlowGeometryKey) isEqual:key]) return YES;
    CGPathRef perimeter = CGPathCreateWithRoundedRect(card, radius, radius, NULL);
    // The emitter is a ring, not a filled card. Even before masking, it cannot
    // paint a full-strength glow through the translucent card's whole interior.
    CGPathRef shadowPath = CGPathCreateCopyByStrokingPath(perimeter, NULL, stroke, kCGLineCapRound, kCGLineJoinRound, 10);
    CGPathRelease(perimeter);
    glow.layer.shadowPath = shadowPath;
    CGPathRelease(shadowPath);
    CGMutablePathRef path = CGPathCreateMutable();
    CGPathAddRect(path, NULL, glow.bounds);
    CGPathAddRoundedRect(path, NULL, card, radius, radius);
    CAShapeLayer *mask = [CAShapeLayer layer];
    mask.frame = glow.bounds; mask.path = path; mask.fillRule = kCAFillRuleEvenOdd;
    glow.layer.mask = mask;
    CGPathRelease(path);
    objc_setAssociatedObject(glow, &V26GlowGeometryKey, key, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return YES;
}
