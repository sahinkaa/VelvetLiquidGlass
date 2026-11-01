#pragma once
#import <Foundation/Foundation.h>
double V26NormalizeNumeric(double value, double minimum, double maximum);
BOOL V26ParseNumeric(NSString *text, double minimum, double maximum, double *result);
NSString *V26NumericText(double value, BOOL percent);
