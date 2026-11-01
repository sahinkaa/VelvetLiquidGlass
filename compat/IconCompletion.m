#import "IconCompletion.h"
#import <objc/runtime.h>
#include <string.h>
BOOL VLGImageCompletionMethod(Class cls,SEL selector) {
    Method method=class_getInstanceMethod(cls,selector);char type[64]={0};
    if(!method || method_getNumberOfArguments(method)!=3)return NO;
    method_getReturnType(method,type,sizeof(type));if(strcmp(type,"v"))return NO;
    method_getArgumentType(method,2,type,sizeof(type));return !strcmp(type,"@?");
}
void (^VLGAfterImageCompletion(void (^original)(id),dispatch_block_t after))(id) {
    if(!original)return nil;
    return [^(id image){
        // Native completion installs its image first, preserving every call and
        // any exception from that original completion. No exception swallowing.
        original(image);
        if(after)after();
    } copy];
}
