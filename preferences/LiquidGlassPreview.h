#import <UIKit/UIKit.h>
@interface VLGLivePreviewView : UIView
- (instancetype)initWithFrame:(CGRect)frame identifier:(NSString *)identifier;
- (void)updatePreview;
- (CGFloat)preferredHeightForWidth:(CGFloat)width;
- (void)configureIdentifier:(NSString *)identifier;
@property(nonatomic, copy) void (^appChanged)(void);
@end
