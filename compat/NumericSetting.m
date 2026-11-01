#import "NumericSetting.h"
#include <math.h>
double V26NormalizeNumeric(double value, double minimum, double maximum) {
    if (!isfinite(minimum) || !isfinite(maximum) || maximum<minimum) return 0;
    if (!isfinite(value)) return minimum;
    double normalized=fmax(minimum,fmin(maximum,round(value*100)/100));
    return normalized==0 ? 0 : normalized;
}
BOOL V26ParseNumeric(NSString *text, double minimum, double maximum, double *result) {
    if (![text isKindOfClass:NSString.class] || !result || !isfinite(minimum) || !isfinite(maximum) || maximum<minimum) return NO;
    NSString *value=[[text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet] stringByReplacingOccurrencesOfString:@"," withString:@"."];
    if (!value.length) return NO;
    NSScanner *scanner=[NSScanner scannerWithString:value];scanner.locale=[NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
    double number;
    if (![scanner scanDouble:&number] || !scanner.isAtEnd || !isfinite(number) || number<minimum || number>maximum) return NO;
    *result=V26NormalizeNumeric(number,minimum,maximum);return YES;
}
NSString *V26NumericText(double value, BOOL percent) {
    NSString *text=[NSString stringWithFormat:@"%.2f",isfinite(value) ? value : 0];
    while ([text hasSuffix:@"0"]) text=[text substringToIndex:text.length-1];
    if ([text hasSuffix:@"."]) text=[text substringToIndex:text.length-1];
    return percent ? [text stringByAppendingString:@"%"] : text;
}
