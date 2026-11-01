#import <Foundation/Foundation.h>

// Only object getters with verified signatures or object ivars are read.
// A missing private property is an optional feature, never a KVC exception.
id V26Object(id object, NSString *key);
BOOL V26Method(Class cls, SEL selector, const char *result, unsigned arguments);
void V26Report(NSString *key, id value);
NSString *V26RootPath(NSString *path);

void V26Event(NSString *event, NSDictionary *fields);

#if defined(V26_HOST)
NSDictionary *V26TestReportSnapshot(void);
#endif
