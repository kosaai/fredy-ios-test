import SwiftUI

/// Native animated sign-in / account-request presentation.
/// Only existing Fredy sign-in is enabled. Fredy v31 user creation is admin-only.
@MainActor
struct LoginView: View {
    @Bindable var model: LoginModel

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var focusedField: Field?

    @Namespace private var selectorAnimation
    @State private var mode: Mode = .signIn
    @State private var showsPassword = false
    @State private var signInTask: Task<Void, Never>?

    // Temporary, in-memory account-creation fields. No registration request.
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var email = ""
    @State private var newUsername = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""

    private enum Mode: CaseIterable {
        case signIn, signUp

        var title: String {
            switch self {
            case .signIn: "تسجيل الدخول"
            case .signUp: "إنشاء حساب"
            }
        }
    }

    private enum Field: Hashable {
        case username, password, firstName, lastName, email, newUsername, newPassword, confirmPassword
    }

    private let ink = Color(red: 0.12, green: 0.12, blue: 0.14)
    private let subdued = Color(red: 0.49, green: 0.49, blue: 0.52)
    private let inputFill = Color(red: 0.957, green: 0.957, blue: 0.964)
    private let cardFill = Color.white

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                skyBackground

                ScrollView {
                    VStack(spacing: 0) {
                        Spacer(minLength: 18)

                        VStack(spacing: 0) {
                            colorfulHeader

                            VStack(spacing: 22) {
                                selector

                                if mode == .signIn {
                                    signInFields
                                        .transition(.asymmetric(
                                            insertion: .move(edge: .bottom).combined(with: .opacity),
                                            removal: .move(edge: .top).combined(with: .opacity)
                                        ))
                                } else {
                                    signUpFields
                                        .transition(.asymmetric(
                                            insertion: .move(edge: .bottom).combined(with: .opacity),
                                            removal: .move(edge: .top).combined(with: .opacity)
                                        ))
                                }

                                footer
                            }
                            .padding(.horizontal, 24)
                            .padding(.top, 27)
                            .padding(.bottom, 31)
                            .frame(maxWidth: .infinity)
                            .background(
                                cardFill,
                                in: UnevenRoundedRectangle(
                                    topLeadingRadius: 37,
                                    bottomLeadingRadius: 37,
                                    bottomTrailingRadius: 37,
                                    topTrailingRadius: 37
                                )
                            )
                            .padding(.top, -48)
                        }
                        .frame(maxWidth: 445)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 32)

                        Spacer(minLength: 10)
                    }
                    .frame(minHeight: geometry.size.height)
                    .frame(maxWidth: .infinity)
                }
                .scrollDismissesKeyboard(.interactively)
                .scrollIndicators(.hidden)
            }
            .ignoresSafeArea(.keyboard, edges: .bottom)
        }
        .toolbar(.hidden, for: .navigationBar)
        .accessibilityIdentifier("login.screen")
        .onChange(of: scenePhase) { _, phase in
            if phase != .active {
                clearPasswords()
                signInTask?.cancel()
                focusedField = nil
            }
        }
        .onDisappear {
            clearPasswords()
            clearRegistrationDraft()
            signInTask?.cancel()
        }
    }

    private var skyBackground: some View {
        GeometryReader { proxy in
            ZStack {
                Color(red: 0.83, green: 0.89, blue: 0.96)
                Circle()
                    .fill(Color.white.opacity(0.27))
                    .frame(width: 330, height: 330)
                    .offset(x: -proxy.size.width * 0.42, y: proxy.size.height * 0.24)
                Ellipse()
                    .fill(Color.white.opacity(0.24))
                    .frame(width: 390, height: 210)
                    .rotationEffect(.degrees(-24))
                    .offset(x: proxy.size.width * 0.38, y: -proxy.size.height * 0.33)
                Circle()
                    .stroke(Color.white.opacity(0.21), lineWidth: 54)
                    .frame(width: 290, height: 290)
                    .offset(x: proxy.size.width * 0.48, y: proxy.size.height * 0.43)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .ignoresSafeArea()
        }
        .accessibilityHidden(true)
    }

    private var colorfulHeader: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 36)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.95, green: 0.56, blue: 0.44),
                            Color(red: 0.93, green: 0.46, blue: 0.37)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            GeometryReader { proxy in
                Circle()
                    .fill(Color(red: 0.93, green: 0.80, blue: 0.46))
                    .frame(width: 205, height: 205)
                    .offset(x: proxy.size.width * 0.68, y: 78)
                Circle()
                    .fill(Color(red: 0.43, green: 0.77, blue: 0.62))
                    .frame(width: 240, height: 240)
                    .offset(x: -118, y: 118)
            }
            .clipShape(RoundedRectangle(cornerRadius: 36))

            VStack(spacing: 8) {
                Image(systemName: "building.2.crop.circle")
                    .font(.system(size: 24, weight: .light))
                    .accessibilityHidden(true)
                Text(mode.title)
                    .font(.system(size: 33, weight: .bold, design: .rounded))
                    .contentTransition(.opacity)
                    .multilineTextAlignment(.center)
            }
            .foregroundStyle(.white)
            .padding(.bottom, 33)
        }
        .frame(height: 220)
        .accessibilityIdentifier("login.header")
    }

    private var selector: some View {
        HStack(spacing: 4) {
            modeButton(.signIn)
            modeButton(.signUp)
        }
        .padding(5)
        .background(inputFill, in: Capsule())
        .environment(\.layoutDirection, .rightToLeft)
        .accessibilityIdentifier("login.mode_selector")
    }

    private func modeButton(_ destination: Mode) -> some View {
        Button {
            changeMode(to: destination)
        } label: {
            Text(destination.title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(mode == destination ? ink : subdued)
                .frame(maxWidth: .infinity)
                .frame(height: 43)
                .background {
                    if mode == destination {
                        Capsule()
                            .fill(cardFill)
                            .shadow(color: Color.black.opacity(0.07), radius: 4, y: 2)
                            .matchedGeometryEffect(id: "activeMode", in: selectorAnimation)
                    }
                }
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(mode == destination ? .isSelected : [])
    }

    private var signInFields: some View {
        VStack(spacing: 14) {
            HStack(spacing: 9) {
                Image(systemName: "person")
                    .foregroundStyle(subdued)
                TextField("اسم المستخدم", text: $model.username)
                    .textContentType(.username)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($focusedField, equals: .username)
                    .submitLabel(.next)
                    .onSubmit { focusedField = .password }
                    .accessibilityIdentifier("login.username")
            }
            .modifier(PillInputStyle(fill: inputFill))

            HStack(spacing: 9) {
                Image(systemName: "lock")
                    .foregroundStyle(subdued)

                Group {
                    if showsPassword {
                        TextField("كلمة المرور", text: $model.password)
                    } else {
                        SecureField("كلمة المرور", text: $model.password)
                    }
                }
                .textContentType(.password)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($focusedField, equals: .password)
                .submitLabel(.go)
                .onSubmit(submit)
                .accessibilityIdentifier("login.password")

                Button {
                    showsPassword.toggle()
                } label: {
                    Image(systemName: showsPassword ? "eye.slash" : "eye")
                        .foregroundStyle(subdued)
                        .frame(width: 32, height: 36)
                }
                .accessibilityLabel(showsPassword ? "إخفاء كلمة المرور" : "إظهار كلمة المرور")
            }
            .modifier(PillInputStyle(fill: inputFill))

            if case .failed(let error) = model.state {
                Label(LocalizedStringKey(error.localizationKey),
                      systemImage: "exclamationmark.triangle")
                    .font(.footnote)
                    .foregroundStyle(Color(red: 0.67, green: 0.22, blue: 0.18))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("login.error")
                    .transition(.opacity)
            }

            Button(action: submit) {
                HStack(spacing: 9) {
                    if model.isLoading {
                        ProgressView()
                            .tint(.white)
                            .controlSize(.small)
                    }
                    Text(LocalizedStringKey(model.isLoading ? "login.submitting" : "login.submit"))
                        .font(.system(size: 16, weight: .bold))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 53)
            }
            .buttonStyle(BlackPillButtonStyle())
            .disabled(!model.canSubmit)
            .accessibilityIdentifier("login.submit")
            .padding(.top, 6)

            Text("login.privacy")
                .font(.caption2)
                .foregroundStyle(subdued)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 5)
        }
        .foregroundStyle(ink)
        .disabled(model.isLoading)
    }

    private var signUpFields: some View {
        VStack(spacing: 12) {
            HStack(spacing: 7) {
                textPill("الاسم الأول", text: $firstName, type: .givenName, focus: .firstName)
                textPill("اسم العائلة", text: $lastName, type: .familyName, focus: .lastName)
            }

            textPill("البريد الإلكتروني", text: $email,
                     type: .emailAddress, focus: .email, keyboard: .emailAddress)
            textPill("اسم المستخدم", text: $newUsername, type: .username, focus: .newUsername)

            HStack(spacing: 10) {
                Group {
                    if showsPassword {
                        TextField("كلمة المرور", text: $newPassword)
                    } else {
                        SecureField("كلمة المرور", text: $newPassword)
                    }
                }
                .textContentType(.newPassword)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($focusedField, equals: .newPassword)

                Button {
                    showsPassword.toggle()
                } label: {
                    Image(systemName: showsPassword ? "eye.slash" : "eye")
                        .foregroundStyle(subdued)
                        .frame(width: 29, height: 34)
                }
                .accessibilityLabel(showsPassword ? "إخفاء كلمة المرور" : "إظهار كلمة المرور")
            }
            .modifier(PillInputStyle(fill: inputFill))

            SecureField("تأكيد كلمة المرور", text: $confirmPassword)
                .textContentType(.newPassword)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($focusedField, equals: .confirmPassword)
                .modifier(PillInputStyle(fill: inputFill))

            // The Fredy v31 create-user endpoint is admin-only. Never pretend
            // that this form successfully registered a new account.
            Button("إنشاء حساب") {}
                .buttonStyle(BlackPillButtonStyle())
                .disabled(true)
                .accessibilityIdentifier("register.submit")
                .padding(.top, 6)

            Label("إنشاء حساب Fredy متاح لمسؤول الخادم من لوحة الإدارة. لا يدعم الخادم التسجيل الذاتي.",
                  systemImage: "info.circle")
                .font(.footnote)
                .foregroundStyle(subdued)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 3)
        }
        .foregroundStyle(ink)
        .accessibilityIdentifier("register.screen")
    }

    private func textPill(
        _ title: String, text: Binding<String>,
        type: UITextContentType, focus: Field,
        keyboard: UIKeyboardType = .default
    ) -> some View {
        TextField(title, text: text)
            .textContentType(type)
            .keyboardType(keyboard)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .focused($focusedField, equals: focus)
            .modifier(PillInputStyle(fill: inputFill))
    }

    private var footer: some View {
        HStack(spacing: 4) {
            Text(mode == .signIn ? "ليس لديك حساب؟" : "لديك حساب؟")
                .foregroundStyle(subdued)
            Button(mode == .signIn ? "إنشاء حساب" : "تسجيل الدخول") {
                changeMode(to: mode == .signIn ? .signUp : .signIn)
            }
            .fontWeight(.semibold)
            .foregroundStyle(ink)
            .underline()
        }
        .font(.subheadline)
        .frame(maxWidth: .infinity)
        .padding(.top, 2)
        .accessibilityIdentifier("login.mode_footer")
    }

    private func changeMode(to destination: Mode) {
        guard destination != mode, !model.isLoading else { return }
        focusedField = nil
        model.password = ""
        newPassword = ""
        confirmPassword = ""
        showsPassword = false

        withAnimation(reduceMotion ? nil : .spring(response: 0.52, dampingFraction: 0.83)) {
            mode = destination
        }
    }

    private func submit() {
        guard mode == .signIn, model.canSubmit, signInTask == nil else { return }
        focusedField = nil
        signInTask = Task {
            await model.signIn()
            signInTask = nil
        }
    }

    private func clearPasswords() {
        model.password = ""
        newPassword = ""
        confirmPassword = ""
    }

    private func clearRegistrationDraft() {
        firstName = ""
        lastName = ""
        email = ""
        newUsername = ""
    }
}

private struct PillInputStyle: ViewModifier {
    let fill: Color

    func body(content: Content) -> some View {
        content
            .font(.system(size: 15))
            .padding(.horizontal, 17)
            .frame(height: 55)
            .frame(maxWidth: .infinity)
            .background(fill, in: Capsule())
    }
}

private struct BlackPillButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .bold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(Color(red: 0.07, green: 0.07, blue: 0.08), in: Capsule())
            .opacity(configuration.isPressed ? 0.76 : 1)
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
    }
}
