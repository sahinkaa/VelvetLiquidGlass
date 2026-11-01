#import <UIKit/UIKit.h>
@interface VLGNumericSliderCell : UITableViewCell
@property(nonatomic, copy) void (^changed)(double value, BOOL final);
@property(nonatomic, copy) void (^enterValue)(void);
@property(nonatomic, readonly) double value;
- (void)configureTitle:(NSString *)title minimum:(double)minimum maximum:(double)maximum value:(double)value percent:(BOOL)percent;
- (void)setNumericValue:(double)value;
- (void)setOverrideHighlighted:(BOOL)highlight;
@end
