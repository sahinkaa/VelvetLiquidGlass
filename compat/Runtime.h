#import <Foundation/Foundation.h>

// Only object getters with verified signatures or object ivars are read.
// A missing private property is an optional feature, never a KVC exception.
id V26Object(id object, NSString *key);
BOOL V26Method(Class cls, SEL selector, const char *result, unsigned arguments);
#if defined(V26_HOST)
void V26Report(NSString *key, id value);
#else
void V26Report(NSString *key, id value);
#define V26Report(...) ((void)sizeof((V26Report(__VA_ARGS__), 0)))
#endif
NSString *V26RootPath(NSString *path);

#if defined(V26_HOST)
void V26Event(NSString *event, NSDictionary *fields);
#else
void V26Event(NSString *event, NSDictionary *fields);
#define V26Event(...) ((void)sizeof((V26Event(__VA_ARGS__), 0)))
#endif

#if defined(V26_HOST)
NSDictionary *V26TestReportSnapshot(void);
#endif
