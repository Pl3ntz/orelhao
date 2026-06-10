# Dialtone

Softphone SIP nativo para macOS — "MicroSIP do Mac" com UI própria em SwiftUI.
Motor [PJSIP 2.17](https://github.com/pjsip/pjproject) (mesmo do MicroSIP), bridge Obj-C++ (PJSUA2), GUI SwiftUI moderna.

> **Status: ARQUIVADO (2026-06-10), funcional.** MVP completo e validado: registro SIP,
> chamadas de áudio in/out, DTMF, mute, GUI completa. Desenvolvimento pausado porque
> alcançar telefones convencionais (PSTN) exige tronco SIP contratado (~R$20/mês) —
> decisão adiada. Reativável em minutos: tudo abaixo continua funcionando.

## O que funciona (validado)

- Registro com auth digest em Asterisk (200 OK, contato visível no servidor)
- Chamada de áudio echo test: CONFIRMED em ~20ms, ~1000 pkt RTP/20s, 0% loss
- GUI: dialer com keypad, tela de chamada com timer, banner de chamada entrante,
  settings com Keychain, mute/DTMF — 13 views SwiftUI
- Smoke test automatizado (`swift run DialtoneSmoke`) e 6 testes unitários da FSM

## Arquitetura

```
DialtoneApp (SwiftUI)          ← GUI, só conhece SIPCore
  └─ SIPCore (Swift)           ← protocolo SIPEngine congelado, FSM pura,
      │                          CallStore @Observable, Keychain, FakeSIPEngine
      └─ SIPCoreReal           ← RealSIPEngine: delegate → AsyncStream
          └─ PJSIPBridge (Obj-C++) ← PSEngine sobre PJSUA2; fila serial GCD
              └─ libpjproject 2.17 (estática; CoreAudio, OpenSSL TLS, SRTP, Opus)
```

Decisões e trade-offs: ver memória do PE (`dialtone-project.md`) — PJSUA2 vs PJSUA,
GCD serial vs actor, áudio 100% PJSIP, GPL vs App Store.

## Instalação rápida (sem compilar nada)

O app pronto está versionado em **`dist/Dialtone-0.1.0.dmg`** (4,6MB, self-contained —
dylibs de opus/openssl embutidas, não precisa de Homebrew). Montar o DMG, arrastar
pro Applications, abrir. Primeira abertura: clique-direito → Abrir (assinatura ad-hoc,
sem notarização). Configurar a conta SIP na engrenagem.

Lembrete: o app sozinho é o "telefone" — pra ele tocar/discar você precisa de um
servidor SIP (o Asterisk abaixo) ou uma conta de provedor (ver Roadmap).

## Como rodar do zero

```bash
# 1. Compilar PJSIP (uma vez, ~5 min; baixa nada — tarball vendored em third_party/)
./scripts/build-pjsip.sh

# 2. Asterisk de teste (ramais 6001/test6001 e 6002/test6002; echo no 600)
docker compose up -d

# 3. Testes + smoke (registra e liga pro echo com null-audio)
swift test && swift run DialtoneSmoke

# 4. App
./scripts/make-app.sh && open build/Dialtone.app
# Abre registrado como 6001. Disque 600 → echo test (pede microfone na 1ª vez).
# GUI sem rede: DIALTONE_FAKE_ENGINE=1 swift run DialtoneApp
```

## Gotchas que custaram debug (não repetir)

1. **`pjsua` binda 5060 por default** → em teste localhost responde a si mesmo
   (200 sem 401). Sempre `--local-port 5070`.
2. **INVITE >1300 bytes migra pra TCP** (RFC 3261 §18.1.1) → Asterisk precisa de
   transporte TCP além de UDP, senão "Connection refused" silencioso.
3. **Docker Desktop/Mac não entrega UDP com `network_mode: host`** → port mapping +
   `external_media_address=127.0.0.1` + `local_net=172.16.0.0/12` no pjsip.conf.
4. **Threading PJSIP**: toda chamada pjlib confinada à fila serial do PSEngine com
   guard `pj_thread_register` (GCD não garante a mesma pthread entre blocos).

## Roadmap para reativar (chamadas pra telefones reais)

1. **Contratar tronco SIP** (Directcall/BR DID nacional, ou Twilio/Telnyx pay-as-you-go).
2. **Asterisk no VPS** (IP público resolve NAT): mesmos arquivos de `asterisk/`,
   trocando senhas e adicionando o tronco:
   ```ini
   ; pjsip.conf — tronco (credenciais do provedor)
   [tronco] ... type=registration/auth/endpoint conforme provedor
   ```
   ```ini
   ; extensions.conf — rota de saída
   exten => _0X.,1,Dial(PJSIP/${EXTEN}@tronco)
   ```
3. **Pendências técnicas no app** (1-2 sessões): transporte TLS na bridge (OpenSSL já
   linkado), STUN/ICE se for direto sem VPS, normalização E.164 no dialer.
4. Pendência menor: teste de áudio com microfone real (smoke usa null-audio);
   F5 original (notarização/universal binary) só se for distribuir.

**Limite regulatório**: número celular pessoal não vira DID (portabilidade Anatel é
só dentro da mesma modalidade). Caller ID com número próprio: Twilio Verified Caller IDs.

## Licença

PJSIP é GPLv2 → este projeto é GPL. Incompatível com Mac App Store; distribuição
seria DMG notarizado. Para fechar código no futuro: baresip (BSD) ou licença
comercial Teluu.
