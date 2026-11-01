#import "../compat/NumericSetting.h"
#include <assert.h>
#include <math.h>
int main(void) { @autoreleasepool {
    double n=-1;
    assert(V26ParseNumeric(@"0",0,100,&n) && n==0);assert(V26ParseNumeric(@"100",0,100,&n) && n==100);
    assert(V26ParseNumeric(@" 77.16 ",0,100,&n) && n==77.16);assert(V26ParseNumeric(@"3,15",1,10,&n) && n==3.15);
    assert(!V26ParseNumeric(@"101",0,100,&n));assert(!V26ParseNumeric(@"-1",0,100,&n));assert(!V26ParseNumeric(@"NaN",0,100,&n));assert(!V26ParseNumeric(@"12abc",0,100,&n));assert(!V26ParseNumeric(@"",0,100,&n));
    assert(V26NormalizeNumeric(99.999999,0,100)==100 && V26NormalizeNumeric(.0000001,0,100)==0);
    assert(V26NormalizeNumeric(3.1465,1,10)==3.15);
    assert([V26NumericText(0,YES) isEqual:@"0%"] && [V26NumericText(100,YES) isEqual:@"100%"]);
    assert([V26NumericText(3.15,NO) isEqual:@"3.15"]);
    assert(V26ParseNumeric(@"-100",-100,100,&n) && n==-100);
    assert(V26ParseNumeric(@"+37.5",-100,100,&n) && n==37.5);
    assert(!V26ParseNumeric(@"-100.01",-100,100,&n));
    assert(V26NormalizeNumeric(-.00001,-100,100)==0 && !signbit(V26NormalizeNumeric(-.00001,-100,100)));
    puts("PASS: exact numeric endpoints, decimal/comma entry, two-decimal normalization, range/invalid-input rejection and live display formatting");
} return 0; }
