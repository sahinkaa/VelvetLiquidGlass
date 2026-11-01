#import <Foundation/Foundation.h>
extern NSString *const VLGSettingsExportFilename;
extern const NSUInteger VLGSettingsMaxFileSize;
BOOL VLGValidateSettings(NSDictionary *settings,NSError **error);
NSData *VLGEncodeSettings(NSDictionary *settings,NSError **error);
NSDictionary *VLGDecodeSettings(NSData *data,NSError **error);
