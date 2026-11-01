#import "SettingsTransfer.h"
#import "SettingsStore.h"
#import <CoreFoundation/CoreFoundation.h>
#include <math.h>
NSString *const VLGSettingsExportFilename=@"Velvet - Liquid Glass settings.plist";
const NSUInteger VLGSettingsMaxFileSize=1024*1024;
static BOOL VLGTransferError(NSError **error,NSString *message) {
    if(error)*error=[NSError errorWithDomain:@"VelvetLiquidGlass.SettingsTransfer" code:1 userInfo:@{NSLocalizedDescriptionKey:message}];return NO;
}
static BOOL VLGFiniteNumber(id value,BOOL boolean) {
    if([value isKindOfClass:NSNumber.class])return isfinite([value doubleValue]);
    if(![value isKindOfClass:NSString.class])return NO;
    if(boolean && [@[@"yes",@"no",@"true",@"false"] containsObject:[value lowercaseString]])return YES;
    NSScanner *scanner=[NSScanner scannerWithString:value];scanner.locale=[NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
    double number=0;return [scanner scanDouble:&number] && scanner.isAtEnd && isfinite(number);
}
static BOOL VLGPropertyShape(id value,NSUInteger depth,NSUInteger *nodes) {
    if(depth>16 || ++*nodes>20000)return NO;
    if([value isKindOfClass:NSDictionary.class]) {
        for(id key in value)if(![key isKindOfClass:NSString.class] || [key length]>1024 || !VLGPropertyShape(value[key],depth+1,nodes))return NO;
        return YES;
    }
    if([value isKindOfClass:NSArray.class]) {for(id item in value)if(!VLGPropertyShape(item,depth+1,nodes))return NO;return YES;}
    if([value isKindOfClass:NSNumber.class])return isfinite([value doubleValue]);
    return [value isKindOfClass:NSString.class] || [value isKindOfClass:NSData.class] || [value isKindOfClass:NSDate.class];
}
BOOL VLGValidateSettings(NSDictionary *settings,NSError **error) {
    if(error)*error=nil;
    NSUInteger nodes=0;
    if(![settings isKindOfClass:NSDictionary.class] || !VLGPropertyShape(settings,0,&nodes) || ![NSPropertyListSerialization propertyList:settings isValidForFormat:NSPropertyListXMLFormat_v1_0])return VLGTransferError(error,@"The file is not a valid settings plist.");
    for(NSString *key in settings) {
        if(!key.length)return VLGTransferError(error,@"The file contains an invalid setting name.");
        NSString *base=[[key componentsSeparatedByString:@"_"] firstObject];id expected=V26Defaults()[base],value=settings[key];
        if([expected isKindOfClass:NSNumber.class]) {
            BOOL boolean=CFGetTypeID((__bridge CFTypeRef)expected)==CFBooleanGetTypeID();
            if(!VLGFiniteNumber(value,boolean))return VLGTransferError(error,[NSString stringWithFormat:@"The value for %@ is invalid.",key]);
        } else if([expected isKindOfClass:NSString.class] || [base hasSuffix:@"Color"] || [base hasSuffix:@"Gradient1"] || [base hasSuffix:@"Gradient2"] || [base isEqual:@"currentIcon"]) {
            if(![value isKindOfClass:NSString.class])return VLGTransferError(error,[NSString stringWithFormat:@"The value for %@ is invalid.",key]);
            BOOL color=NO;
            for(NSString *part in @[@"background",@"bannerBorder",@"shadow",@"title",@"message",@"date"]) {
                if([base isEqual:[part stringByAppendingString:@"Color"]] || [base isEqual:[part stringByAppendingString:@"Gradient1"]] || [base isEqual:[part stringByAppendingString:@"Gradient2"]]){color=YES;break;}
            }
            if(color) {
                NSArray *components=[[value componentsSeparatedByCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet] filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"length > 0"]];
                if(components.count!=4)return VLGTransferError(error,[NSString stringWithFormat:@"The color for %@ is invalid.",key]);
                for(NSString *component in components)if(!VLGFiniteNumber(component,NO))return VLGTransferError(error,[NSString stringWithFormat:@"The color for %@ is invalid.",key]);
                double alpha=[components[3] doubleValue];if(alpha<0 || alpha>1)return VLGTransferError(error,[NSString stringWithFormat:@"The color opacity for %@ is invalid.",key]);
            }
        }
    }
    return YES;
}
NSData *VLGEncodeSettings(NSDictionary *settings,NSError **error) {
    if(!VLGValidateSettings(settings,error))return nil;
    NSData *data=[NSPropertyListSerialization dataWithPropertyList:settings format:NSPropertyListXMLFormat_v1_0 options:0 error:error];
    if(data.length>VLGSettingsMaxFileSize){VLGTransferError(error,@"The settings file is too large.");return nil;}return data;
}
NSDictionary *VLGDecodeSettings(NSData *data,NSError **error) {
    if(error)*error=nil;
    if(![data isKindOfClass:NSData.class] || !data.length || data.length>VLGSettingsMaxFileSize){VLGTransferError(error,@"The settings file is empty or too large.");return nil;}
    id settings=[NSPropertyListSerialization propertyListWithData:data options:NSPropertyListImmutable format:NULL error:error];
    return VLGValidateSettings(settings,error) ? settings : nil;
}
