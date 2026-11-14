import SwiftUI

@MainActor
struct LoginView: View {
    @Bindable var model: LoginModel
    @Environment(\.scenePhase) private var scenePhase
    @FocusState private var focusedField: Field?
    @State private var signInTask: Task<Void, Never>?

    private enum Field: Hashable { case username, password }

    var body: some View {
        Form {
            Section {
                Text("login.intro")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("login.username").font(.headline)
                    TextField("login.username", text: $model.username)
                        .textContentType(.username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($focusedField, equals: .username)
                        .submitLabel(.next)
                        .onSubmit { focusedField = .password }
                        .accessibilityIdentifier("login.username")
                }
                .padding(.vertical, 8)

                VStack(alignment: .leading, spacing: 8) {
                    Text("login.password").font(.headline)
                    SecureField("login.password", text: $model.password)
                        .textContentType(.password)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($focusedField, equals: .password)
                        .submitLabel(.go)
                        .onSubmit(submit)
                        .accessibilityIdentifier("login.password")
                }
                .padding(.vertical, 8)
            }
            .disabled(model.isLoading)

            if case .failed(let error) = model.state {
                Section {
                    Label(LocalizedStringKey(error.localizationKey), systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("login.error")
                }
            }

            Section {
                Button(action: submit) {
                    HStack {
                        if model.isLoading {
                            ProgressView()
                                .controlSize(.small)
                        }
                        Text(LocalizedStringKey(model.isLoading ? "login.submitting" : "login.submit"))
                    }
                    .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!model.canSubmit)
                .accessibilityIdentifier("login.submit")
            } footer: {
                Text("login.privacy")
            }
        }
        .navigationTitle("login.title")
        .scrollDismissesKeyboard(.interactively)
        .accessibilityIdentifier("login.screen")
        .onChange(of: scenePhase) { _, phase in
            if phase != .active {
                model.password = ""
                signInTask?.cancel()
            }
        }
        .onDisappear {
            model.password = ""
            signInTask?.cancel()
        }
    }

    private func submit() {
        guard model.canSubmit, signInTask == nil else { return }
        focusedField = nil
        signInTask = Task {
            await model.signIn()
            signInTask = nil
        }
    }
}
