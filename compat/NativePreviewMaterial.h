#pragma once
#if defined(V26_STYLE_HOST)
#import "../tests/StyleUIKit.h"
#else
#import <UIKit/UIKit.h>
#endif
BOOL VLGNativePlatterABI(Class cls);
UIView *VLGCreateNativePlatter(Class cls);
