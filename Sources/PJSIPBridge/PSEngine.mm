#import "PSEngine.h"

#include <pjsua2.hpp>
#include <map>
#include <mutex>

using namespace pj;

// REGRA DE OURO (Zero Assumption + docs PJSIP): toda chamada pjlib acontece na
// _queue serial. GCD não garante a mesma pthread entre blocos, então CADA bloco
// passa por PSEnsureThreadRegistered() antes de tocar o PJSIP.
static bool gLibCreated = false;

static void PSEnsureThreadRegistered(void) {
    if (!gLibCreated) return;
    if (pj_thread_is_registered()) return;
    static thread_local pj_thread_desc desc;
    pj_thread_t *thread = NULL;
    pj_bzero(desc, sizeof(desc));
    pj_thread_register("dialtone-queue", desc, &thread);
}

static NSError *PSError(NSString *message) {
    return [NSError errorWithDomain:@"dev.vplentz.dialtone.pjsip"
                               code:1
                           userInfo:@{NSLocalizedDescriptionKey : message}];
}

static PSCallState PSStateFromInvState(pjsip_inv_state state) {
    switch (state) {
        case PJSIP_INV_STATE_CALLING: return PSCallStateCalling;
        case PJSIP_INV_STATE_INCOMING: return PSCallStateIncoming;
        case PJSIP_INV_STATE_EARLY: return PSCallStateEarly;
        case PJSIP_INV_STATE_CONNECTING: return PSCallStateConnecting;
        case PJSIP_INV_STATE_CONFIRMED: return PSCallStateConfirmed;
        case PJSIP_INV_STATE_DISCONNECTED: return PSCallStateDisconnected;
        default: return PSCallStateIdle;
    }
}

@implementation PSCallEvent

- (instancetype)initWithCallId:(NSInteger)callId
                         state:(PSCallState)state
                    statusCode:(NSInteger)statusCode
                     remoteURI:(NSString *)remoteURI
                    isIncoming:(BOOL)isIncoming {
    if ((self = [super init])) {
        _callId = callId;
        _state = state;
        _statusCode = statusCode;
        _remoteURI = [remoteURI copy];
        _isIncoming = isIncoming;
    }
    return self;
}

@end

class PSCall;
class PSAccount;

@interface PSEngine () {
  @public
    dispatch_queue_t _queue;
    Endpoint *_endpoint;
    PSAccount *_account;
    std::map<int, PSCall *> _calls;
    std::mutex _callsMutex;
    BOOL _useNullAudio;
    BOOL _started;
}
- (void)onRegStateActive:(BOOL)active code:(NSInteger)code reason:(NSString *)reason;
- (void)onIncomingCall:(PSCall *)call callId:(int)callId remote:(NSString *)remote;
- (void)onCallEvent:(PSCallEvent *)event;
- (void)onMediaActive:(NSInteger)callId;
- (void)scheduleDestroyCall:(int)callId;
@end

// ---- Subclasses PJSUA2 (callbacks chegam em threads internas do PJSIP) ----

class PSCall : public Call {
  public:
    PSCall(Account &account, PSEngine *engine, int callId = PJSUA_INVALID_ID)
        : Call(account, callId), engine_(engine) {}

    virtual void onCallState(OnCallStateParam &prm) override {
        CallInfo info;
        try {
            info = getInfo();
        } catch (Error &) {
            return;
        }
        PSCallEvent *event = [[PSCallEvent alloc]
            initWithCallId:info.id
                     state:PSStateFromInvState(info.state)
                statusCode:(NSInteger)info.lastStatusCode
                 remoteURI:[NSString stringWithUTF8String:info.remoteUri.c_str()]
                isIncoming:(info.role == PJSIP_ROLE_UAS)];
        [engine_ onCallEvent:event];
        if (info.state == PJSIP_INV_STATE_DISCONNECTED) {
            [engine_ scheduleDestroyCall:(int)info.id];
        }
    }

    virtual void onCallMediaState(OnCallMediaStateParam &prm) override {
        CallInfo info;
        try {
            info = getInfo();
        } catch (Error &) {
            return;
        }
        for (unsigned i = 0; i < info.media.size(); i++) {
            if (info.media[i].type != PJMEDIA_TYPE_AUDIO) continue;
            if (info.media[i].status != PJSUA_CALL_MEDIA_ACTIVE) continue;
            try {
                AudioMedia audio = getAudioMedia((int)i);
                AudDevManager &devices = Endpoint::instance().audDevManager();
                audio.startTransmit(devices.getPlaybackDevMedia());
                devices.getCaptureDevMedia().startTransmit(audio);
                [engine_ onMediaActive:info.id];
            } catch (Error &err) {
                // sem mídia não há chamada útil; o estado da chamada segue reportado
            }
        }
    }

  private:
    __unsafe_unretained PSEngine *engine_;  // engine possui as calls; nunca o inverso
};

class PSAccount : public Account {
  public:
    explicit PSAccount(PSEngine *engine) : engine_(engine) {}

    virtual void onRegState(OnRegStateParam &prm) override {
        AccountInfo info;
        try {
            info = getInfo();
        } catch (Error &) {
            return;
        }
        [engine_ onRegStateActive:(info.regIsActive ? YES : NO)
                             code:(NSInteger)prm.code
                           reason:[NSString stringWithUTF8String:prm.reason.c_str()]];
    }

    virtual void onIncomingCall(OnIncomingCallParam &iprm) override {
        PSCall *call = new PSCall(*this, engine_, iprm.callId);
        NSString *remote = @"";
        try {
            CallInfo info = call->getInfo();
            remote = [NSString stringWithUTF8String:info.remoteUri.c_str()];
        } catch (Error &) {
        }
        [engine_ onIncomingCall:call callId:iprm.callId remote:remote];
    }

  private:
    __unsafe_unretained PSEngine *engine_;
};

// ---- Fachada ----

@implementation PSEngine

- (instancetype)initWithNullAudio:(BOOL)useNullAudio {
    if ((self = [super init])) {
        _queue = dispatch_queue_create("dev.vplentz.dialtone.pjsip", DISPATCH_QUEUE_SERIAL);
        _useNullAudio = useNullAudio;
        _endpoint = NULL;
        _account = NULL;
        _started = NO;
    }
    return self;
}

- (BOOL)startAndReturnError:(NSError **)error {
    __block NSError *failure = nil;
    dispatch_sync(_queue, ^{
        if (self->_started) return;
        try {
            self->_endpoint = new Endpoint();
            self->_endpoint->libCreate();
            gLibCreated = true;

            EpConfig config;
            config.uaConfig.userAgent = "Dialtone/0.1";
            config.logConfig.level = 3;
            config.logConfig.consoleLevel = 3;
            self->_endpoint->libInit(config);

            TransportConfig udpConfig;
            udpConfig.port = 0;  // efêmera: NUNCA bindar 5060 (gotcha do spike)
            self->_endpoint->transportCreate(PJSIP_TRANSPORT_UDP, udpConfig);
            TransportConfig tcpConfig;
            tcpConfig.port = 0;
            self->_endpoint->transportCreate(PJSIP_TRANSPORT_TCP, tcpConfig);

            self->_endpoint->libStart();
            if (self->_useNullAudio) {
                self->_endpoint->audDevManager().setNullDev();
            }
            self->_started = YES;
        } catch (Error &err) {
            failure = PSError([NSString stringWithUTF8String:err.info().c_str()]);
        }
    });
    if (failure) {
        if (error) *error = failure;
        return NO;
    }
    return YES;
}

- (BOOL)registerAccountWithURI:(NSString *)idURI
                     registrar:(NSString *)registrarURI
                      username:(NSString *)username
                      password:(NSString *)password
                        useTCP:(BOOL)useTCP
                         error:(NSError **)error {
    __block NSError *failure = nil;
    dispatch_sync(_queue, ^{
        PSEnsureThreadRegistered();
        if (!self->_started) {
            failure = PSError(@"Engine não iniciada");
            return;
        }
        try {
            if (self->_account) {
                delete self->_account;
                self->_account = NULL;
            }
            AccountConfig config;
            config.idUri = std::string(idURI.UTF8String);
            std::string registrar = std::string(registrarURI.UTF8String);
            if (useTCP) registrar += ";transport=tcp";
            config.regConfig.registrarUri = registrar;
            config.sipConfig.authCreds.push_back(
                AuthCredInfo("digest", "*", std::string(username.UTF8String), 0,
                             std::string(password.UTF8String)));
            self->_account = new PSAccount(self);
            self->_account->create(config);
        } catch (Error &err) {
            failure = PSError([NSString stringWithUTF8String:err.info().c_str()]);
        }
    });
    if (failure) {
        if (error) *error = failure;
        return NO;
    }
    return YES;
}

- (void)unregisterAccount {
    dispatch_async(_queue, ^{
        PSEnsureThreadRegistered();
        if (!self->_account) return;
        try {
            self->_account->setRegistration(false);
        } catch (Error &) {
        }
    });
}

- (NSInteger)makeCallTo:(NSString *)destURI error:(NSError **)error {
    __block NSInteger result = -1;
    __block NSError *failure = nil;
    dispatch_sync(_queue, ^{
        PSEnsureThreadRegistered();
        if (!self->_started || !self->_account) {
            failure = PSError(@"Sem conta registrada");
            return;
        }
        PSCall *call = new PSCall(*self->_account, self);
        CallOpParam param(true);
        param.opt.audioCount = 1;
        param.opt.videoCount = 0;
        try {
            call->makeCall(std::string(destURI.UTF8String), param);
            int callId = call->getId();
            {
                std::lock_guard<std::mutex> hold(self->_callsMutex);
                self->_calls[callId] = call;
            }
            result = callId;
        } catch (Error &err) {
            delete call;
            failure = PSError([NSString stringWithUTF8String:err.info().c_str()]);
        }
    });
    if (failure && error) *error = failure;
    return result;
}

- (void)answerCall:(NSInteger)callId {
    dispatch_async(_queue, ^{
        PSEnsureThreadRegistered();
        PSCall *call = [self callForId:(int)callId];
        if (!call) return;
        CallOpParam param;
        param.statusCode = PJSIP_SC_OK;
        try {
            call->answer(param);
        } catch (Error &) {
        }
    });
}

- (void)hangupCall:(NSInteger)callId {
    dispatch_async(_queue, ^{
        PSEnsureThreadRegistered();
        PSCall *call = [self callForId:(int)callId];
        if (!call) return;
        CallOpParam param;
        try {
            call->hangup(param);
        } catch (Error &) {
        }
    });
}

- (void)sendDTMF:(NSString *)digits toCall:(NSInteger)callId {
    NSString *copied = [digits copy];
    dispatch_async(_queue, ^{
        PSEnsureThreadRegistered();
        PSCall *call = [self callForId:(int)callId];
        if (!call) return;
        try {
            call->dialDtmf(std::string(copied.UTF8String));
        } catch (Error &) {
        }
    });
}

- (void)setMuted:(BOOL)muted {
    dispatch_async(_queue, ^{
        PSEnsureThreadRegistered();
        if (!self->_started) return;
        std::lock_guard<std::mutex> hold(self->_callsMutex);
        for (auto &entry : self->_calls) {
            try {
                AudioMedia audio = entry.second->getAudioMedia(-1);
                AudioMedia &capture =
                    Endpoint::instance().audDevManager().getCaptureDevMedia();
                if (muted) {
                    capture.stopTransmit(audio);
                } else {
                    capture.startTransmit(audio);
                }
            } catch (Error &) {
            }
        }
    });
}

- (void)shutdown {
    dispatch_sync(_queue, ^{
        PSEnsureThreadRegistered();
        if (!self->_endpoint) return;
        try {
            self->_endpoint->hangupAllCalls();
        } catch (Error &) {
        }
        {
            std::lock_guard<std::mutex> hold(self->_callsMutex);
            for (auto &entry : self->_calls) delete entry.second;
            self->_calls.clear();
        }
        if (self->_account) {
            delete self->_account;
            self->_account = NULL;
        }
        try {
            self->_endpoint->libDestroy();
        } catch (Error &) {
        }
        delete self->_endpoint;
        self->_endpoint = NULL;
        self->_started = NO;
        gLibCreated = false;
    });
}

// ---- Internos ----

- (PSCall *)callForId:(int)callId {
    std::lock_guard<std::mutex> hold(_callsMutex);
    auto found = _calls.find(callId);
    return found == _calls.end() ? NULL : found->second;
}

- (void)scheduleDestroyCall:(int)callId {
    // NUNCA deletar a Call dentro do callback dela (use-after-free no PJSIP).
    dispatch_async(_queue, ^{
        PSEnsureThreadRegistered();
        PSCall *call = NULL;
        {
            std::lock_guard<std::mutex> hold(self->_callsMutex);
            auto found = self->_calls.find(callId);
            if (found != self->_calls.end()) {
                call = found->second;
                self->_calls.erase(found);
            }
        }
        delete call;
    });
}

- (void)onRegStateActive:(BOOL)active code:(NSInteger)code reason:(NSString *)reason {
    id<PSEngineDelegate> delegate = self.delegate;
    dispatch_async(dispatch_get_main_queue(), ^{
        [delegate engineRegistrationChangedWithActive:active statusCode:code reason:reason];
    });
}

- (void)onIncomingCall:(PSCall *)call callId:(int)callId remote:(NSString *)remote {
    {
        std::lock_guard<std::mutex> hold(_callsMutex);
        _calls[callId] = call;
    }
    PSCallEvent *event = [[PSCallEvent alloc] initWithCallId:callId
                                                       state:PSCallStateIncoming
                                                  statusCode:0
                                                   remoteURI:remote
                                                  isIncoming:YES];
    id<PSEngineDelegate> delegate = self.delegate;
    dispatch_async(dispatch_get_main_queue(), ^{
        [delegate engineIncomingCall:event];
    });
}

- (void)onCallEvent:(PSCallEvent *)event {
    id<PSEngineDelegate> delegate = self.delegate;
    dispatch_async(dispatch_get_main_queue(), ^{
        [delegate engineCallChanged:event];
    });
}

- (void)onMediaActive:(NSInteger)callId {
    id<PSEngineDelegate> delegate = self.delegate;
    dispatch_async(dispatch_get_main_queue(), ^{
        [delegate engineMediaActiveForCall:callId];
    });
}

@end
