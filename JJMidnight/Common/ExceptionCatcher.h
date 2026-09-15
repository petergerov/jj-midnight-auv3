#import <Foundation/Foundation.h>

#ifdef __cplusplus
extern "C" {
#endif

NS_ASSUME_NONNULL_BEGIN

/// Runs `block` and returns NO if an Objective-C exception is thrown.
/// AVAudioEngine asserts with NSException; those cannot be caught in Swift.
BOOL JJRunCatchingException(void (NS_NOESCAPE ^block)(void), NSError * _Nullable * _Nullable error);

NS_ASSUME_NONNULL_END

#ifdef __cplusplus
}
#endif
