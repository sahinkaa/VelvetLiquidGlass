#ifndef V26_STYLE_HOST
#import <UIKit/UIKit.h>
#endif
void V26Refresh(id owner);
void V26RefreshForView(UIView *view);
void V26RequestChanged(id owner);

void VLGIconDidComplete(UIView *view);

void VLGNativeTextDidUpdate(UIView *view);

void VLGNativeTextProviderRegistered(UIView *content,UIView *view,NSInteger style,id provider);
