import SwiftUI

/// Signed-out popover content: username → browser handoff.
struct SignInView: View {
    @ObservedObject var auth = AuthManager.shared
    @State private var username = ""

    var body: some View {
        VStack(spacing: 14) {
            Spacer()
            Text("🐕")
                .font(.system(size: 40))
            Text("Get paid to review repos.")
                .font(.system(size: 14, weight: .semibold))
            Text("Sign in with your GitHub account —\nyour public activity becomes your score.")
                .font(.system(size: 11.5))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            VStack(spacing: 8) {
                TextField("GitHub username", text: $username)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 220)
                    .onSubmit(submit)
                Button(action: submit) {
                    if auth.state == .signingIn {
                        Text("Waiting for the browser…")
                    } else {
                        Text("Sign in with GitHub")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(auth.state == .signingIn)
            }

            if let error = auth.lastError {
                Text(error)
                    .font(.system(size: 11))
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
            }
            if auth.state == .signingIn {
                Button("Cancel") { auth.signOut() }
                    .buttonStyle(.plain)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    private func submit() {
        auth.beginSignIn(username: username)
    }
}
