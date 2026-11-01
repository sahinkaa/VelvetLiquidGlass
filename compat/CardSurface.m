#import "CardSurface.h"
#import "Runtime.h"
#import "DecorationSurface.h"
#include <math.h>
UIView *VLGCardPlatter(UIView *root) {
    if(!root || !NSThread.isMainThread)return nil;
    Class cls=NSClassFromString(@"NCPlatterView");
    if(cls && [root isKindOfClass:cls])return root;
    id known=V26Object(root,@"platterView");
    if([known isKindOfClass:UIView.class] && [known isDescendantOfView:root])return known;
    NSMutableArray *queue=[NSMutableArray arrayWithArray:root.subviews];
    for(NSUInteger i=0;i<queue.count && i<64;i++) {
        UIView *view=queue[i];if(V26IsOwnedDecoration(view))continue;
        if(cls && [view isKindOfClass:cls])return view;
        if(queue.count+view.subviews.count<=128)[queue addObjectsFromArray:view.subviews];
    }
    return root;
}
static BOOL VLGContentContainer(UIView *view) {
    Class text=NSClassFromString(@"UITextView");
    return view && ![view isKindOfClass:UILabel.class] && ![view isKindOfClass:UIImageView.class] && !(text && [view isKindOfClass:text]);
}
UIView *VLGCardContent(UIView *root) {
    UIView *platter=VLGCardPlatter(root);
    id candidate=V26Object(platter,@"customContentView") ?: V26Object(root,@"customContentView");
    UIView *host=[candidate isKindOfClass:UIView.class] && [candidate isDescendantOfView:root] ? candidate : nil;
    if([host isKindOfClass:UIVisualEffectView.class]) {
        id content=V26Object(host,@"contentView");
        host=[content isKindOfClass:UIView.class] && [content isDescendantOfView:root] ? content : nil;
    }
    return VLGContentContainer(host) ? host : nil;
}
CGRect VLGCardFrame(UIView *root,UIView *material) {
    if(!NSThread.isMainThread || !root)return CGRectNull;
    UIView *platter=VLGCardPlatter(root);
    CGRect bounds=platter.bounds;
    if(platter && isfinite(bounds.size.width) && isfinite(bounds.size.height) && bounds.size.width>0 && bounds.size.height>0 && bounds.size.width<=4096 && bounds.size.height<=4096)return [platter convertRect:bounds toView:root];
    return [material convertRect:material.bounds toView:root];
}
BOOL VLGPlaceCardTint(UIView *tint,UIView *root,UIView *material,UIView *content) {
    if(!NSThread.isMainThread || !tint || !root || !material.superview)return NO;
    UIView *host=VLGCardContent(root);
    // Native notification content is another safe foreground host. Its text and
    // icon stay above the owned tint. Never reparent or hide a native glass view.
    if(!host && content!=root && VLGContentContainer(content) && [content isDescendantOfView:root])host=content;
    BOOL foreground=host!=nil;
    if(!host)host=material.superview;
    if(foreground) {
        if(tint.superview!=host || host.subviews.firstObject!=tint)[host insertSubview:tint atIndex:0];
    } else if(tint.superview!=host || [host.subviews indexOfObjectIdenticalTo:tint]<=[host.subviews indexOfObjectIdenticalTo:material]) [host insertSubview:tint aboveSubview:material];
    CGRect frame=VLGCardFrame(root,material);
    tint.frame=[root convertRect:frame toView:host];
    V26Report(@"background.tintPlacement",foreground ? @"nativeContentForeground" : @"legacyMaterialFallback");
    return foreground;
}
