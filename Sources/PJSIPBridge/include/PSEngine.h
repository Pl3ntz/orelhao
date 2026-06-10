#import <Foundation/Foundation.h>

// Fachada Obj-C pura sobre o PJSUA2. Header NÃO pode incluir nada de C++/PJSIP —
// é o que o SwiftPM expõe pro Swift via module map automático.

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

// Callbacks SEMPRE entregues na main queue.
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

/// nullAudio=YES roda sem device de som (testes/CI, sem prompt de microfone).
- (instancetype)initWithNullAudio:(BOOL)useNullAudio;

- (BOOL)startAndReturnError:(NSError **)error;

- (BOOL)registerAccountWithURI:(NSString *)idURI
                     registrar:(NSString *)registrarURI
                      username:(NSString *)username
                      password:(NSString *)password
                        useTCP:(BOOL)useTCP
                         error:(NSError **)error;
- (void)unregisterAccount;

/// Retorna callId do PJSIP, ou -1 em erro.
- (NSInteger)makeCallTo:(NSString *)destURI error:(NSError **)error;
- (void)answerCall:(NSInteger)callId;
- (void)hangupCall:(NSInteger)callId;
- (void)sendDTMF:(NSString *)digits toCall:(NSInteger)callId;
- (void)setMuted:(BOOL)muted;

- (void)shutdown;

@end

NS_ASSUME_NONNULL_END
