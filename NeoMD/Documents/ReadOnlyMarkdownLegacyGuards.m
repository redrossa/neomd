#import <AppKit/AppKit.h>
#import "NeoMD-Swift.h"

// Public NSDocument APIs deprecated before Swift existed are unavailable to Swift
// overrides. Guard them on our class only, before any superclass filesystem work.
@interface ReadOnlyMarkdownNSDocument (LegacyWriteGuards)
@end

@implementation ReadOnlyMarkdownNSDocument (LegacyWriteGuards)
- (BOOL)writeWithBackupToFile:(NSString *)path ofType:(NSString *)type saveOperation:(NSSaveOperationType)operation { return NO; }
- (BOOL)writeToFile:(NSString *)path ofType:(NSString *)type { return NO; }
- (BOOL)writeToFile:(NSString *)path ofType:(NSString *)type originalFile:(NSString *)original saveOperation:(NSSaveOperationType)operation { return NO; }
- (BOOL)writeToURL:(NSURL *)url ofType:(NSString *)type { return NO; }
- (BOOL)saveToURL:(NSURL *)url ofType:(NSString *)type forSaveOperation:(NSSaveOperationType)operation error:(NSError **)error {
    if (error) {
        *error = [NSError errorWithDomain:NSCocoaErrorDomain code:NSFileWriteNoPermissionError
                                userInfo:@{NSLocalizedDescriptionKey: @"NeoMD opens documents for reading only."}];
    }
    return NO;
}
- (void)saveToFile:(NSString *)path saveOperation:(NSSaveOperationType)operation delegate:(id)delegate didSaveSelector:(SEL)selector contextInfo:(void *)context {
    if (delegate && selector && [delegate respondsToSelector:selector]) {
        void (*callback)(id, SEL, NSDocument *, BOOL, void *) = (void *)[delegate methodForSelector:selector];
        callback(delegate, selector, self, NO, context);
    }
}
@end
