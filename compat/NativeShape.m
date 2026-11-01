#import "NativeShape.h"
#import "Runtime.h"
#import <objc/runtime.h>
#import <objc/message.h>
#include <math.h>

static BOOL V26ScalarMethod(id target, SEL selector, char result, unsigned count) {
    Method m = target ? class_getInstanceMethod(object_getClass(target), selector) : NULL;
    if (!m || method_getNumberOfArguments(m) != count + 2) return NO;
    char type[64]; method_getReturnType(m, type, sizeof(type));
    if (type[0] != result || type[1]) return NO;
    if (count) { method_getArgumentType(m, 2, type, sizeof(type)); if (strcmp(type, "d")) return NO; }
    return YES;
}
@interface V26NativeShape ()
@property(nonatomic, weak) id target;
@property(nonatomic) SEL getter;
@property(nonatomic) SEL setter;
@property(nonatomic) double previous;
@property(nonatomic) double applied;
@property(nonatomic) double requested;
@property(nonatomic) unsigned writesForValue;
@property(nonatomic) BOOL owned;
@end
@implementation V26NativeShape
- (BOOL)resolve:(id)target getter:(SEL *)getterOut setter:(SEL *)setterOut {
    for (NSArray *pair in @[@[@"_continuousCornerRadius", @"_setContinuousCornerRadius:"], @[@"_cornerRadius", @"_setCornerRadius:"]]) {
        SEL getter = NSSelectorFromString(pair[0]), setter = NSSelectorFromString(pair[1]);
        if (V26ScalarMethod(target, getter, 'd', 0) && V26ScalarMethod(target, setter, 'v', 1)) {
            *getterOut = getter; *setterOut = setter; return YES;
        }
    }
    return NO;
}
- (double)radiusOn:(id)target fallback:(double)fallback {
    if (!NSThread.isMainThread) return fallback;
    SEL getter, setter;
    if (![self resolve:target getter:&getter setter:&setter]) return fallback;
    double value = ((double (*)(id, SEL))objc_msgSend)(target, getter);
    return isfinite(value) && value >= 0 ? value : fallback;
}
- (BOOL)applyRadius:(double)radius to:(id)target {
    if (!NSThread.isMainThread || !isfinite(radius) || radius < 0 || !target) return NO;
    if (self.target != target) [self restore];
    SEL getter, setter;
    if (![self resolve:target getter:&getter setter:&setter]) return NO;
    self.getter = getter; self.setter = setter;
    double before = ((double (*)(id, SEL))objc_msgSend)(target, self.getter);
    if (!isfinite(before) || before < 0) return NO;
    if (!self.owned) { self.target = target; self.previous = before; }
    if (self.requested != radius) { self.requested = radius; self.writesForValue = 0; }
    // Native layout is allowed to run. Reapply only when its radius differs.
    if (fabs(before - radius) > .01) {
        // A system layout that repeatedly restores its own radius must not
        // create a setter/layout feedback loop in this diagnostic candidate.
        if (self.writesForValue >= 4) {
            V26Report(@"shape.nativeOverrideBudgetExhausted", @YES);
            return NO;
        }
        ++self.writesForValue;
        ((void (*)(id, SEL, double))objc_msgSend)(target, self.setter, radius);
    }
    self.applied = radius; self.owned = YES;
    double after = ((double (*)(id, SEL))objc_msgSend)(target, self.getter);
    if (isfinite(after) && after >= 0) self.applied = after;
    V26Report(@"shape.nativeClass", NSStringFromClass(object_getClass(target)));
    V26Report(@"shape.nativeSetter", NSStringFromSelector(self.setter));
    V26Report(@"shape.nativeReadbackMatched", @(isfinite(after) && fabs(after - radius) <= .01));
    return isfinite(after) && fabs(after - radius) <= .01;
}
- (void)restore {
    id target = self.target;
    if (NSThread.isMainThread && self.owned && V26ScalarMethod(target, self.getter, 'd', 0) && V26ScalarMethod(target, self.setter, 'v', 1)) {
        double current = ((double (*)(id, SEL))objc_msgSend)(target, self.getter);
        if (isfinite(current) && fabs(current - self.applied) <= .01)
            ((void (*)(id, SEL, double))objc_msgSend)(target, self.setter, self.previous);
    }
    self.owned = NO; self.target = nil; self.writesForValue = 0;
}
@end
