#import "ExceptionCatcher.h"

BOOL JJRunCatchingException(void (NS_NOESCAPE ^block)(void), NSError **error) {
    @try {
        block();
        return YES;
    } @catch (NSException *exception) {
        if (error != NULL) {
            *error = [NSError errorWithDomain:exception.name ?: @"NSException"
                                         code:0
                                     userInfo:@{
                NSLocalizedDescriptionKey: exception.reason ?: exception.name ?: @"Exception"
            }];
        }
        return NO;
    }
}
