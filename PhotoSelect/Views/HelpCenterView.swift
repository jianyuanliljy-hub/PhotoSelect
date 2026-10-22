import SwiftUI

/// Kept as a lightweight reusable help surface for later product iterations.
/// The MVP no longer presents onboarding before the user can start culling.
struct HelpCenterView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("PhotoSelect")
                .font(.largeTitle.bold())

            Text("Open a shoot, keep your eyes on the photograph, and make one decision per keystroke.")
                .font(.title3)
                .foregroundStyle(.secondary)

            Grid(alignment: .leading, horizontalSpacing: 22, verticalSpacing: 10) {
                shortcut("← / →", "Previous / next")
                shortcut("1", "Reject")
                shortcut("2", "Keep")
                shortcut("3", "Select")
                shortcut("4", "Hero")
                shortcut("0", "Clear decision")
                shortcut("⌘Z", "Undo")
                shortcut("F", "Focus Mode")
            }

            Divider()

            Label("Reject is non-destructive until you explicitly move rejected originals to the macOS Trash.", systemImage: "checkmark.shield")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding(28)
        .frame(width: 560)
    }

    private func shortcut(_ key: String, _ action: String) -> some View {
        GridRow {
            Text(key)
                .font(.callout.monospaced().weight(.semibold))
                .frame(width: 72, alignment: .trailing)
            Text(action)
        }
    }
}

struct WelcomeGuideView: View {
    @Binding var isPresented: Bool

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "photo.stack")
                .font(.system(size: 42, weight: .light))
            Text("PhotoSelect")
                .font(.title.bold())
            Text("Open a folder and start culling with 1, 2, 3, and 4.")
                .foregroundStyle(.secondary)
            Button("Continue") { isPresented = false }
                .buttonStyle(.borderedProminent)
        }
        .padding(32)
        .frame(width: 440, height: 280)
    }
}
