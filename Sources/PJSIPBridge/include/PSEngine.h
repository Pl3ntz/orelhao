#import <Foundation/Foundation.h>

// Pure Obj-C facade over PJSUA2. The header must NOT include anything from C++/PJSIP —
// it is what SwiftPM exposes to Swift via the automatic module map.

typedef NS_ENUM(NSInteger, PSCallState) {
    PSCallStateIdle = 0,
    PSCallStateCalling,
    PSCallStateIncoming,
    PSCallStateEarly,
    PSCallStateConnecting,
    PSCallStateConfirmed,
    PSCallStateDisconnected,
};

NS_ASSUME_NONNULL_BEGIN

@interface PSCallEvent : NSObject
@property (nonatomic, readonly) NSInteger callId;
@property (nonatomic, readonly) PSCallState state;
@property (nonatomic, readonly) NSInteger statusCode;
@property (nonatomic, readonly, copy) NSString *remoteURI;
@property (nonatomic, readonly) BOOL isIncoming;
- (instancetype)initWithCallId:(NSInteger)callId
                         state:(PSCallState)state
                    statusCode:(NSInteger)statusCode
                     remoteURI:(NSString *)remoteURI
                    isIncoming:(BOOL)isIncoming;
@end

// Callbacks are ALWAYS delivered on the main queue.
@protocol PSEngineDelegate <NSObject>
- (void)engineRegistrationChangedWithActive:(BOOL)active
                                 statusCode:(NSInteger)statusCode
                                     reason:(NSString *)reason;
- (void)engineIncomingCall:(PSCallEvent *)event;
- (void)engineCallChanged:(PSCallEvent *)event;
- (void)engineMediaActiveForCall:(NSInteger)callId;
@end

@interface PSEngine : NSObject

@property (nonatomic, weak, nullable) id<PSEngineDelegate> delegate;

/// nullAudio=YES runs without a sound device (tests/CI, no microphone prompt).
- (instancetype)initWithNullAudio:(BOOL)useNullAudio;

- (BOOL)startAndReturnError:(NSError **)error;

- (BOOL)registerAccountWithURI:(NSString *)idURI
                     registrar:(NSString *)registrarURI
                      username:(NSString *)username
                      password:(NSString *)password
                        useTCP:(BOOL)useTCP
                         error:(NSError **)error;
- (void)unregisterAccount;

/// Returns the PJSIP callId, or -1 on error.
- (NSInteger)makeCallTo:(NSString *)destURI error:(NSError **)error;
- (void)answerCall:(NSInteger)callId;
- (void)hangupCall:(NSInteger)callId;
- (void)sendDTMF:(NSString *)digits toCall:(NSInteger)callId;
- (void)setMuted:(BOOL)muted;

- (void)shutdown;

@end

NS_ASSUME_NONNULL_END
