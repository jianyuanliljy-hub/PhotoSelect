import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: PhotoLibraryStore

    var body: some View {
        Form {
            Section("Culling") {
                Toggle("Advance after making a decision", isOn: $store.autoAdvance)
                Toggle("Show filmstrip", isOn: $store.showFilmstrip)

                Text("Focus Mode temporarily hides the sidebar and filmstrip so the photograph gets the maximum useful area.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Keyboard") {
                LabeledContent("Previous / Next", value: "←  →")
                LabeledContent("First / Last", value: "⌘ ←   ⌘ →")
                LabeledContent("Clear decision", value: "0")
                LabeledContent("Reject / Keep / Select / Hero", value: "1  2  3  4")
                LabeledContent("Focus Mode", value: "F")
                LabeledContent("Undo", value: "⌘ Z")
                LabeledContent("Open folder", value: "⌘ O")
                LabeledContent("Filmstrip", value: "⌥ ⌘ F")
                LabeledContent("Zoom", value: "⌘ +   ⌘ −")
                LabeledContent("Zoom to Fit", value: "⌘ 0")
            }
        }
        .formStyle(.grouped)
        .padding()
        .frame(width: 520)
    }
}
