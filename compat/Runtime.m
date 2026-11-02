#import "Runtime.h"
#import <objc/runtime.h>
#import <objc/message.h>
#include <math.h>
#if !defined(V26_HOST)
#if defined(V26_ROOTHIDE)
#import <roothide.h>
#else
#import <rootless.h>
#endif
#endif

NSString *V26RootPath(NSString *path) {
#if defined(V26_HOST)
    return path;
#elif defined(V26_ROOTHIDE)
    return jbroot(path);
#else
    return ROOT_PATH_NS(path);
#endif
}

static const char *V26Type(const char *type) {
    while (type && *type && strchr("rnNoORV", *type)) ++type;
    return type;
}

BOOL V26Method(Class cls, SEL selector, const char *result, unsigned arguments) {
    Method method = cls ? class_getInstanceMethod(cls, selector) : NULL;
    if (!method || method_getNumberOfArguments(method) != arguments + 2) return NO;
    char buffer[128];
    method_getReturnType(method, buffer, sizeof(buffer));
    if (strcmp(V26Type(buffer), result)) return NO;
    for (unsigned i = 2; i < arguments + 2; ++i) {
        method_getArgumentType(method, i, buffer, sizeof(buffer));
        if (*V26Type(buffer) != '@') return NO;
    }
    return YES;
}

#if defined(V26_HOST)
static NSMutableDictionary *V26Diagnostics(void) {
    static NSMutableDictionary *report;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ report = [@{@"build": @"1.0.0", @"project": @"Velvet - Liquid Glass", @"process": NSProcessInfo.processInfo.processName} mutableCopy]; });
    return report;
}
static void V26SaveReport(void) {
#if !defined(V26_HOST)
    static BOOL scheduled;
    static NSTimeInterval lastWrite;
    if (scheduled) return;
    scheduled = YES;
    NSTimeInterval now=NSProcessInfo.processInfo.systemUptime;
    NSTimeInterval delay=lastWrite ? fmax(.2,5-(now-lastWrite)) : .2;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay*NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        NSMutableDictionary *report = V26Diagnostics();
        @synchronized (report) {
            scheduled = NO; lastWrite=NSProcessInfo.processInfo.systemUptime;
            @try {
#if defined(V26_ROOTHIDE)
                NSString *folder = V26RootPath(@"/var/mobile/Library/Logs");
#else
                NSString *folder = @"/var/mobile/Library/Logs";
#endif
                [[NSFileManager defaultManager] createDirectoryAtPath:folder withIntermediateDirectories:YES attributes:nil error:NULL];
                report[@"updatedAt"]=[NSDate date];
                NSString *file = [NSString stringWithFormat:@"VelvetLiquidGlass-%@.plist", NSProcessInfo.processInfo.processName];
                [report writeToFile:[folder stringByAppendingPathComponent:file] atomically:YES];
            } @catch (NSException *exception) { /* Diagnostics cannot interrupt UIKit. */ }
        }
    });
#endif
}
void V26Report(NSString *key, id value) {
    if (!key || !value) return;
    @try {
        NSMutableDictionary *report = V26Diagnostics();
        @synchronized (report) {
            if (report[key] || report.count >= 180) return;
            report[key] = value;
            V26SaveReport();
        }
    } @catch (NSException *exception) {}
}
void V26Event(NSString *event, NSDictionary *fields) {
    if (!event || !NSThread.isMainThread) return;
    @try {
        static NSUInteger sequence;
        static NSTimeInterval origin;
        NSTimeInterval now = NSProcessInfo.processInfo.systemUptime;
        if (!sequence) origin = now;
        NSMutableDictionary *entry = [fields mutableCopy] ?: [NSMutableDictionary dictionary];
        entry[@"event"] = event; entry[@"sequence"] = @(++sequence);
        entry[@"milliseconds"] = @((now - origin) * 1000);
        NSMutableDictionary *report = V26Diagnostics();
        @synchronized (report) {
            NSMutableArray *events = report[@"events"];
            if (!events) { events = [NSMutableArray array]; report[@"events"] = events; }
            if (events.count >= 128) [events removeObjectAtIndex:0];
            [events addObject:entry]; V26SaveReport();
        }
    } @catch (NSException *exception) {}
}

#else
#define V26UnusedDiagnostics(...) ((void)0)
#endif
id V26Object(id object, NSString *key) {
    if (!object || ![key isKindOfClass:NSString.class] || !key.length) return nil;
    Class cls = object_getClass(object);
    SEL selector = NSSelectorFromString(key);
    Method method = class_getInstanceMethod(cls, selector);
    char type[128];
    if (method && method_getNumberOfArguments(method) == 2) {
        method_getReturnType(method, type, sizeof(type));
        if (*V26Type(type) == '@' && V26Type(type)[1] != '?') {
            @try { return ((id (*)(id, SEL))objc_msgSend)(object, selector); }
            @catch (NSException *exception) {
                V26Report([NSString stringWithFormat:@"getter.exception.%@.%@", NSStringFromClass(cls), key], exception.name);
                return nil;
            }
        }
    }
    for (NSString *name in @[[ @"_" stringByAppendingString:key], key]) {
        Ivar ivar = class_getInstanceVariable(cls, name.UTF8String);
        const char *encoding = ivar ? V26Type(ivar_getTypeEncoding(ivar)) : NULL;
        if (encoding && *encoding == '@' && encoding[1] != '?') return object_getIvar(object, ivar);
    }
    V26Report([NSString stringWithFormat:@"missing.%@.%@", NSStringFromClass(cls), key], @YES);
    return nil;
}

#if defined(V26_HOST)
NSDictionary *V26TestReportSnapshot(void) {
    NSMutableDictionary *report = V26Diagnostics();
    @synchronized (report) { return [[NSDictionary alloc] initWithDictionary:report copyItems:YES]; }
}
#endif
