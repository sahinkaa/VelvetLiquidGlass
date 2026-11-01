#import "BannerTemplate.h"
#import "Runtime.h"
#import "DecorationSurface.h"
#import <objc/runtime.h>
#import <objc/message.h>
#include <string.h>
#import <CoreFoundation/CoreFoundation.h>
static NSDictionary *VLGReadCache;
static NSTimeInterval VLGReadChecked;

#if !defined(V26_STYLE_HOST)
static void VLGTemplateChanged(CFNotificationCenterRef center,void *observer,CFStringRef name,const void *object,CFDictionaryRef info) {
    dispatch_async(dispatch_get_main_queue(),^{VLGReadCache=nil;VLGReadChecked=0;[NSNotificationCenter.defaultCenter postNotificationName:@"VLGPreviewTemplateDidChange" object:nil];});
}
#endif

static NSString *VLGTemplatePath(void) {
#if defined(V26_STYLE_HOST)
    NSString *path=NSProcessInfo.processInfo.environment[@"VLG_TEMPLATE_TEST_PATH"];NSCAssert(path.length,@"Template test path required");return path;
#elif defined(V26_ROOTHIDE)
    return V26RootPath(@"/var/mobile/Library/Caches/com.sahinkaa.velvetliquidglass/banner-template.plist");
#else
    return @"/var/mobile/Library/Caches/com.sahinkaa.velvetliquidglass/banner-template.plist";
#endif
}
static NSString *VLGOS(void) {return NSProcessInfo.processInfo.operatingSystemVersionString;}
static BOOL VLGScalarMethod(id object, NSString *name, const char *result, const char *argument) {
    Method m=object ? class_getInstanceMethod(object_getClass(object),NSSelectorFromString(name)) : NULL;
    if (!m || method_getNumberOfArguments(m)!=(argument ? 3 : 2)) return NO;
    char type[128]={0};method_getReturnType(m,type,sizeof(type));if(strcmp(type,result)) return NO;
    if (argument) {method_getArgumentType(m,2,type,sizeof(type));if(strcmp(type,argument))return NO;}
    return YES;
}
static NSNumber *VLGInteger(id object,NSString *name) {
    if (VLGScalarMethod(object,name,@encode(NSInteger),NULL)) return @(((NSInteger(*)(id,SEL))objc_msgSend)(object,NSSelectorFromString(name)));
    if (VLGScalarMethod(object,name,@encode(NSUInteger),NULL)) {
        NSUInteger value=((NSUInteger(*)(id,SEL))objc_msgSend)(object,NSSelectorFromString(name));return value<=128 ? @(value) : nil;
    }
    // Some iOS 26 scalars have a setter but no getter. Read only exact integer
    // ivars with validated type, offset and object-instance bounds.
    Ivar ivar=class_getInstanceVariable(object_getClass(object),[[@"_" stringByAppendingString:name] UTF8String]);
    const char *type=ivar ? ivar_getTypeEncoding(ivar) : NULL;
    ptrdiff_t offset=ivar ? ivar_getOffset(ivar) : -1;
    if(type && (!strcmp(type,@encode(NSInteger)) || !strcmp(type,@encode(NSUInteger))) && offset>=(ptrdiff_t)sizeof(void *) && (size_t)offset+sizeof(NSUInteger)<=class_getInstanceSize(object_getClass(object))) {
        NSUInteger value=0;memcpy(&value,(const char *)(__bridge const void *)object+offset,sizeof(value));if(value<=128)return @(value);
    }
    return nil;
}
static NSNumber *VLGBool(id object,NSString *name) {
    if(VLGScalarMethod(object,name,@encode(BOOL),NULL)) return @(((BOOL(*)(id,SEL))objc_msgSend)(object,NSSelectorFromString(name)));
    return nil;
}
static void VLGSetInteger(id object,NSString *name,NSNumber *value) {
    if(value && value.integerValue>=0 && value.integerValue<=128 && VLGScalarMethod(object,name,"v",@encode(NSInteger)))
        ((void(*)(id,SEL,NSInteger))objc_msgSend)(object,NSSelectorFromString(name),value.integerValue);
    else if(value && value.integerValue>=0 && value.integerValue<=128 && VLGScalarMethod(object,name,"v",@encode(NSUInteger)))
        ((void(*)(id,SEL,NSUInteger))objc_msgSend)(object,NSSelectorFromString(name),value.unsignedIntegerValue);
}
static NSArray *VLGChildren(UIView *view) {
    NSMutableArray *result=[NSMutableArray array];
    for(UIView *child in view.subviews) if(!V26IsOwnedDecoration(child)) [result addObject:child];
    return result;
}
static BOOL VLGEffectCodingClass(Class cls) {
    if(!cls)return NO;
#if defined(V26_STYLE_HOST)
    return [cls isSubclassOfClass:UIVisualEffect.class] || [cls isSubclassOfClass:NSArray.class] || [cls isSubclassOfClass:NSDictionary.class] || [cls isSubclassOfClass:NSString.class] || [cls isSubclassOfClass:NSNumber.class] || [cls isSubclassOfClass:NSData.class];
#else
    NSString *path=[NSBundle bundleForClass:cls].bundlePath;
    if(![path hasPrefix:@"/System/Library/"])return NO;
    for(NSString *framework in @[@"UIKit",@"Foundation",@"CoreFoundation",@"QuartzCore",@"CoreUI",@"UIFoundation",@"CoreGraphics"])
        if([path containsString:[framework stringByAppendingString:@".framework"]] || [path containsString:[framework stringByAppendingString:@"Core.framework"]])return YES;
    return NO;
#endif
}
static NSData *VLGArchiveEffect(id object) {
    if(!object)return nil;
    if([object isKindOfClass:NSArray.class]) {
        if([object count]>8)return nil;
        for(id item in object)if(!VLGEffectCodingClass([item class]))return nil;
    } else if(![object isKindOfClass:UIVisualEffect.class])return nil;
    NSError *error=nil;
    NSData *data=[NSKeyedArchiver archivedDataWithRootObject:object requiringSecureCoding:YES error:&error];
    if(error)V26Report(@"template.archiveError",error.localizedDescription);
    return data.length && data.length<=65536 ? data : nil;
}
static id VLGDecodeEffect(NSData *data,Class expected) {
    if(![data isKindOfClass:NSData.class] || !data.length || data.length>65536)return nil;
    id archive=[NSPropertyListSerialization propertyListWithData:data options:0 format:NULL error:NULL];
    if(![archive isKindOfClass:NSDictionary.class] || ![archive[@"$objects"] isKindOfClass:NSArray.class] || [archive[@"$objects"] count]>2048)return nil;
    NSMutableSet *classes=[NSMutableSet setWithObjects:expected,NSArray.class,NSDictionary.class,NSString.class,NSNumber.class,NSData.class,NSValue.class,NSSet.class,nil];
    for(id entry in archive[@"$objects"]) if([entry isKindOfClass:NSDictionary.class] && entry[@"$classname"]) {
        if(![entry[@"$classname"] isKindOfClass:NSString.class])return nil;
        Class cls=NSClassFromString(entry[@"$classname"]);if(!VLGEffectCodingClass(cls))return nil;[classes addObject:cls];
    }
    NSError *error=nil;id object=[NSKeyedUnarchiver unarchivedObjectOfClasses:classes fromData:data error:&error];
    if(error)V26Report(@"template.decodeError",error.localizedDescription);
    if(![object isKindOfClass:expected])return nil;
    if([object isKindOfClass:NSArray.class] && [object count]>8)return nil;
    return object;
}
static void VLGEffects(UIView *root,UIView *content,NSArray *path,NSMutableArray *effects,unsigned *budget) {
    if(!*budget || effects.count>=4 || path.count>8 || (root==content && ![root isKindOfClass:UIVisualEffectView.class])) return;--*budget;
    // Copy only effect descriptions, including split background/content
    // arrays. A modern effect view can legitimately have effect == nil.
    if([root isKindOfClass:UIVisualEffectView.class]) {
        NSMutableDictionary *row=[@{@"path":path,@"hidden":@(root.hidden),@"alpha":@(root.alpha),@"class":NSStringFromClass(root.class)} mutableCopy];
        NSData *single=VLGArchiveEffect(((UIVisualEffectView *)root).effect);BOOL meaningful=single!=nil;
        if(single)row[@"effect"]=single;
        for(NSString *key in @[@"backgroundEffects",@"contentEffects"]) {
            id values=V26Object(root,key);
            if([values isKindOfClass:NSArray.class]) {if([values count])meaningful=YES;NSData *data=VLGArchiveEffect(values);if(data)row[key]=data;}
        }
        if(meaningful && (row[@"effect"] || row[@"backgroundEffects"] || row[@"contentEffects"])) [effects addObject:row];
        return;
    }
    NSArray *children=VLGChildren(root);
    for(NSUInteger i=0;i<children.count && *budget;++i) VLGEffects(children[i],content,[path arrayByAddingObject:@(i)],effects,budget);
}
static NSDictionary *VLGDocument(void) {
    NSData *data=[NSData dataWithContentsOfFile:VLGTemplatePath()];
    if(!data.length || data.length>1048576) return nil;
    id doc=[NSPropertyListSerialization propertyListWithData:data options:0 format:NULL error:NULL];
    return [doc isKindOfClass:NSDictionary.class] && [doc[@"schema"] isEqual:@2] && [doc[@"os"] isEqual:VLGOS()] ? doc : nil;
}
static void VLGRecordBannerTemplate(UIView *root) {
    if(!NSThread.isMainThread || !root.window || root.bounds.size.width<100 || root.bounds.size.height<30) return;
    static NSUInteger captureAttempts;
    if(captureAttempts>=32)return;
    unsigned ancestorDepth=0;
    for(UIView *ancestor=root;ancestor && ancestorDepth<20;ancestor=ancestor.superview,++ancestorDepth) {
        if(ancestor.hidden || ancestor.layer.opacity<.99)return;
        if(ancestor==root.window)break;
    }
    @try {
        UIView *platter=V26Object(root,@"platterView");
        if(![platter isKindOfClass:UIView.class] || ![platter isDescendantOfView:root]) return;
        NSMutableDictionary *profile=[NSMutableDictionary dictionary];
        NSNumber *supports=VLGBool(root,@"supportsGlass"),*recipe=VLGInteger(root,@"materialRecipe"),*mode=VLGInteger(root,@"glassMode");
        if(supports) profile[@"supportsGlass"]=supports;if(recipe)profile[@"recipe"]=recipe;if(mode)profile[@"glassMode"]=mode;
        // No archive or filesystem work on an unchanged layout pass. Only
        // capture a small number of actual material/trait transitions per root.
        static char signatureKey,countKey;
        NSMutableArray *signature=[NSMutableArray arrayWithObjects:supports ?: NSNull.null,recipe ?: NSNull.null,mode ?: NSNull.null,@(root.traitCollection.userInterfaceStyle),nil];
        UIView *content=V26Object(platter,@"customContentView");
        NSMutableArray *queue=[NSMutableArray arrayWithObject:platter];
        for(NSUInteger i=0;i<queue.count && i<64;++i) {
            UIView *view=queue[i];
            if(view==content && ![view isKindOfClass:UIVisualEffectView.class])continue;
            if([view isKindOfClass:UIVisualEffectView.class]) {
                [signature addObject:[NSValue valueWithNonretainedObject:((UIVisualEffectView *)view).effect]];
                for(NSString *name in @[@"backgroundEffects",@"contentEffects"]) {
                    id values=V26Object(view,name);[signature addObject:[values isKindOfClass:NSArray.class] ? [values copy] : NSNull.null];
                }
                [signature addObject:@(view.hidden)];[signature addObject:@(view.alpha)];
            } else if(queue.count<64) [queue addObjectsFromArray:VLGChildren(view)];
        }
        if([objc_getAssociatedObject(root,&signatureKey) isEqual:signature] || [objc_getAssociatedObject(root,&countKey) unsignedIntegerValue]>=6)return;
        objc_setAssociatedObject(root,&signatureKey,signature,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(root,&countKey,@([objc_getAssociatedObject(root,&countKey) unsignedIntegerValue]+1),OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        ++captureAttempts;
        NSMutableArray *effects=[NSMutableArray array];unsigned budget=64;
        VLGEffects(platter,content,@[],effects,&budget);
        profile[@"effects"]=effects;
        UIView *material=V26Object(platter,@"backgroundMaterialView");
        if([material isKindOfClass:UIView.class]) {profile[@"materialHidden"]=@(material.hidden);profile[@"materialAlpha"]=@(material.alpha);}
        profile[@"style"]=@(root.traitCollection.userInterfaceStyle);
        NSString *style=root.traitCollection.userInterfaceStyle==UIUserInterfaceStyleLight ? @"light" : @"dark";
        static NSMutableDictionary *pending,*last;static BOOL scheduled;static NSUInteger writes;
        if(!last)last=[VLGDocument() mutableCopy] ?: [NSMutableDictionary dictionary];
        if(!pending) pending=[NSMutableDictionary dictionary];
        NSDictionary *old=last[style];
        if([old isEqual:profile])return;
        pending[style]=profile;last[style]=profile;
        if(scheduled || writes>=24)return;scheduled=YES;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW,NSEC_PER_SEC/2),dispatch_get_main_queue(),^{
            scheduled=NO;++writes;
            NSMutableDictionary *document=[VLGDocument() mutableCopy] ?: [NSMutableDictionary dictionary];
            document[@"schema"]=@2;document[@"os"]=VLGOS();[document addEntriesFromDictionary:pending];[pending removeAllObjects];
            NSString *path=VLGTemplatePath();NSError *error=nil;
            [NSFileManager.defaultManager createDirectoryAtPath:path.stringByDeletingLastPathComponent withIntermediateDirectories:YES attributes:nil error:&error];
            BOOL saved=!error && [document writeToFile:path atomically:YES];
#if !defined(V26_STYLE_HOST)
            if(saved) CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),CFSTR("com.sahinkaa.velvetliquidglass/bannerTemplateUpdate"),NULL,NULL,YES);
#endif
            V26Event(@"bannerTemplate",@{@"saved":@(saved),@"lightEffects":@([document[@"light"][@"effects"] count]),@"darkEffects":@([document[@"dark"][@"effects"] count])});
        });
    } @catch(NSException *exception){V26Report(@"template.captureError",exception.name);}
}
void VLGCaptureBannerTemplate(UIView *root) {
    if(!NSThread.isMainThread || !root)return;
    static char pendingKey;
    if([objc_getAssociatedObject(root,&pendingKey) boolValue])return;
    objc_setAssociatedObject(root,&pendingKey,@YES,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    __weak UIView *weakRoot=root;
    // Run after the native layout/trait transaction. No repeating timer and
    // no archive work in the banner's initial paint callback.
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,NSEC_PER_SEC/10),dispatch_get_main_queue(),^{
        UIView *view=weakRoot;if(!view)return;
        objc_setAssociatedObject(view,&pendingKey,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        VLGRecordBannerTemplate(view);
    });
}
NSDictionary *VLGReadBannerTemplate(UIUserInterfaceStyle style) {
    if(!NSThread.isMainThread)return nil;
#if !defined(V26_STYLE_HOST)
    static dispatch_once_t once;dispatch_once(&once,^{CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(),NULL,VLGTemplateChanged,CFSTR("com.sahinkaa.velvetliquidglass/bannerTemplateUpdate"),NULL,CFNotificationSuspensionBehaviorCoalesce);});
#endif
    NSTimeInterval now=NSProcessInfo.processInfo.systemUptime;
    if(VLGReadChecked==0 || now-VLGReadChecked>.5) {VLGReadCache=VLGDocument();VLGReadChecked=now;}
    NSDictionary *profile=VLGReadCache[style==UIUserInterfaceStyleLight ? @"light" : @"dark"];
    return [profile isKindOfClass:NSDictionary.class] ? profile : nil;
}
BOOL VLGApplyBannerTemplate(UIView *platter,NSDictionary *profile) {
    if(!NSThread.isMainThread || !platter || !profile)return NO;
    @try {
        NSNumber *supports=profile[@"supportsGlass"];
        if([supports isKindOfClass:NSNumber.class] && VLGScalarMethod(platter,@"setSupportsGlass:","v",@encode(BOOL)))
            ((void(*)(id,SEL,BOOL))objc_msgSend)(platter,NSSelectorFromString(@"setSupportsGlass:"),supports.boolValue);
        for(NSArray *pair in @[@[@"setMaterialRecipe:",@"recipe"],@[@"updateWithGlassMode:",@"glassMode"]]) {
            id value=profile[pair[1]];if([value isKindOfClass:NSNumber.class])VLGSetInteger(platter,pair[0],value);
        }
        [platter layoutIfNeeded];
        NSUInteger applied=0;
        id effects=profile[@"effects"];
        if([effects isKindOfClass:NSArray.class] && [effects count]<=4) for(id row in effects) {
            if(![row isKindOfClass:NSDictionary.class] || ![row[@"path"] isKindOfClass:NSArray.class] || [row[@"path"] count]>8)continue;
            UIView *view=platter;
            for(id component in row[@"path"]) {
                if(![component isKindOfClass:NSNumber.class]){view=nil;break;}
                NSArray *children=VLGChildren(view);NSUInteger i=[component unsignedIntegerValue];
                view=i<children.count ? children[i] : nil;if(!view)break;
            }
            if(![view isKindOfClass:UIVisualEffectView.class] || ![NSStringFromClass(view.class) isEqual:row[@"class"]])continue;
            BOOL restored=NO;
            if(row[@"effect"]) {
                UIVisualEffect *effect=VLGDecodeEffect(row[@"effect"],UIVisualEffect.class);
                if(effect){((UIVisualEffectView *)view).effect=effect;restored=YES;}
            }
            for(NSArray *pair in @[@[@"backgroundEffects",@"setBackgroundEffects:"],@[@"contentEffects",@"setContentEffects:"]]) {
                if(!row[pair[0]])continue;
                NSArray *values=VLGDecodeEffect(row[pair[0]],NSArray.class);
                SEL setter=NSSelectorFromString(pair[1]);
                if(values && V26Method(object_getClass(view),setter,"v",1)) {((void(*)(id,SEL,id))objc_msgSend)(view,setter,values);restored=YES;}
            }
            if(!restored)continue;
            if([row[@"hidden"] isKindOfClass:NSNumber.class])view.hidden=[row[@"hidden"] boolValue];
            if([row[@"alpha"] isKindOfClass:NSNumber.class]) {double alpha=[row[@"alpha"] doubleValue];if(isfinite(alpha)&&alpha>=0&&alpha<=1)view.alpha=alpha;}
            ++applied;
        }
        UIView *material=V26Object(platter,@"backgroundMaterialView");
        if([material isKindOfClass:UIView.class]) {
            if([profile[@"materialHidden"] isKindOfClass:NSNumber.class]) material.hidden=[profile[@"materialHidden"] boolValue];
            if([profile[@"materialAlpha"] isKindOfClass:NSNumber.class]) {double alpha=[profile[@"materialAlpha"] doubleValue];if(isfinite(alpha)&&alpha>=0&&alpha<=1)material.alpha=alpha;}
        }
        V26Event(@"previewBannerTemplate",@{@"effectsApplied":@(applied),@"recipe":profile[@"recipe"] ?: @(-1),@"glassMode":profile[@"glassMode"] ?: @(-1),@"supportsGlass":supports ?: @NO});
        return applied>0;
    } @catch(NSException *exception) {V26Report(@"template.applyError",exception.name);return NO;}
}
