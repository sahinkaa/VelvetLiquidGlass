#import <Foundation/Foundation.h>

BOOL VLGRequestTestBanner(NSString *identifier, NSError **error);
void VLGCancelTestBanner(void);
void VLGInstallTestBannerService(void);
// Shared production validation/request assembly, also exercised on the host.
BOOL VLGValidTestIdentifier(id identifier);
NSDictionary *VLGValidateTestCommand(id command, NSDate *now);
BOOL VLGTestObjectMethod(id receiver, NSString *selector, const char *result, unsigned arguments);
id VLGMakeTestNotification(Class requestClass, Class optionsClass, NSString *identifier,
    NSString *notificationID, NSString *destination, NSString *title, id icon, NSError **error);
NSString *VLGTestCommandPath(void);

void VLGTestBannerReply(NSString *nonce, NSString *message);
