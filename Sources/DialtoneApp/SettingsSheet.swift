import SwiftUI
import SIPCore

/// Form da conta SIP. Persiste via AccountManager e devolve a conta salva ao pai.
struct SettingsSheet: View {
    @Environment(\.dismiss) private var dismiss

    let initialAccount: SIPAccount
    let initialPassword: String
    let onSave: (SIPAccount, String) -> Void

    @State private var displayName = ""
    @State private var username = ""
    @State private var domain = ""
    @State private var portText = ""
    @State private var transport: SIPTransport = .udp
    @State private var password = ""
    @State private var validationError: String?

    private var isValid: Bool {
        !username.trimmingCharacters(in: .whitespaces).isEmpty
            && !domain.trimmingCharacters(in: .whitespaces).isEmpty
            && Int(portText).map { (1...65535).contains($0) } == true
    }

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section("Conta SIP") {
                    TextField("Nome de exibição", text: $displayName)
                    TextField("Usuário", text: $username)
                    TextField("Domínio", text: $domain)
                    TextField("Porta", text: $portText)
                    Picker("Transporte", selection: $transport) {
                        ForEach(SIPTransport.allCases, id: \.self) { transport in
                            Text(transport.rawValue.uppercased()).tag(transport)
                        }
                    }
                    .pickerStyle(.segmented)
                    SecureField("Senha", text: $password)
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)

            if let validationError {
                Text(validationError)
                    .font(.caption)
                    .foregroundStyle(Theme.dangerRed)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 6)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack {
                Button("Cancelar") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Salvar e registrar") { save() }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.callGreen)
                    .disabled(!isValid)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
        }
        .frame(width: 380, height: 430)
        .onAppear(perform: populate)
    }

    private func populate() {
        displayName = initialAccount.displayName
        username = initialAccount.username
        domain = initialAccount.domain
        portText = String(initialAccount.port)
        transport = initialAccount.transport
        password = initialPassword
    }

    private func save() {
        guard let port = Int(portText), (1...65535).contains(port) else {
            validationError = "Porta inválida — use um valor entre 1 e 65535."
            return
        }
        let account = SIPAccount(
            id: initialAccount.id,
            displayName: displayName.trimmingCharacters(in: .whitespaces),
            username: username.trimmingCharacters(in: .whitespaces),
            domain: domain.trimmingCharacters(in: .whitespaces),
            port: port,
            transport: transport
        )
        do {
            try AccountManager().save(account, password: password)
            onSave(account, password)
            dismiss()
        } catch {
            validationError = "Falha ao salvar a conta: \(error.localizedDescription)"
        }
    }
}
