#import "NativePreviewMaterial.h"
#import "Runtime.h"
#import <objc/runtime.h>
#include <string.h>
@protocol VLGPlatterInitializer
- (instancetype)initWithRecipe:(NSInteger)recipe supportsGlass:(BOOL)supportsGlass;
@end
BOOL VLGNativePlatterABI(Class cls) {
    if (!cls || ![cls isSubclassOfClass:UIView.class]) return NO;
    Method method=class_getInstanceMethod(cls,NSSelectorFromString(@"initWithRecipe:supportsGlass:"));
    if (!method || method_getNumberOfArguments(method)!=4) return NO;
    char result[32]={0},recipe[32]={0},glass[32]={0};
    method_getReturnType(method,result,sizeof(result));method_getArgumentType(method,2,recipe,sizeof(recipe));method_getArgumentType(method,3,glass,sizeof(glass));
    return result[0]=='@' && !strcmp(recipe,@encode(NSInteger)) && !strcmp(glass,@encode(BOOL));
}
UIView *VLGCreateNativePlatter(Class cls) {
    if (!NSThread.isMainThread || !VLGNativePlatterABI(cls)) return nil;
    @try {
        // Use an Objective-C init-family call so ARC correctly handles a
        // replacing initializer. The exact private signature is checked first.
        id view=[(id<VLGPlatterInitializer>)[cls alloc] initWithRecipe:1 supportsGlass:YES];
        return [view isKindOfClass:UIView.class] ? view : nil;
    } @catch (NSException *exception) {V26Report(@"preview.nativeInitError",exception.name);return nil;}
}
