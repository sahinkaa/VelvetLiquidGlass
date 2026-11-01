#pragma once
#ifdef V26_STYLE_HOST
#import "../tests/StyleUIKit.h"
#else
#import <UIKit/UIKit.h>
#endif
UIView *VLGCardPlatter(UIView *root);
UIView *VLGCardContent(UIView *root);
CGRect VLGCardFrame(UIView *root,UIView *material);
BOOL VLGPlaceCardTint(UIView *tint,UIView *root,UIView *material,UIView *content);
