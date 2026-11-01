#pragma once
#ifdef V26_STYLE_HOST
#import "../tests/StyleUIKit.h"
#else
#import <UIKit/UIKit.h>
#endif
// Capture background styling only. Never capture content views or screenshots.
void VLGCaptureBannerTemplate(UIView *root);
NSDictionary *VLGReadBannerTemplate(UIUserInterfaceStyle style);
BOOL VLGApplyBannerTemplate(UIView *platter, NSDictionary *profile);
