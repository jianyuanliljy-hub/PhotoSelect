import SwiftUI

struct PhotoSelectToolbar: ToolbarContent {
    @ObservedObject var store: PhotoLibraryStore
    @Binding var showTrashConfirmation: Bool

    var body: some ToolbarContent {
        ToolbarItemGroup(placement: .navigation) {
            Button { store.previous() } label: {
                Label("Previous Photo", systemImage: "chevron.left")
            }
            .labelStyle(.iconOnly)
            .disabled(!store.canNavigateBackward)
            .help("Previous photo (←)")

            Button { store.next() } label: {
                Label("Next Photo", systemImage: "chevron.right")
            }
            .labelStyle(.iconOnly)
            .disabled(!store.canNavigateForward)
            .help("Next photo (→)")
        }

        ToolbarItem(placement: .principal) {
            VStack(spacing: 1) {
                Text(store.filter.title)
                    .font(.headline)
                    .lineLimit(1)

                if !store.assets.isEmpty {
                    Text(statusText)
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
            .accessibilityElement(children: .combine)
        }

        ToolbarItemGroup(placement: .primaryAction) {
            Toggle(isOn: $store.autoAdvance) {
                Label("Auto Advance", systemImage: store.autoAdvance ? "forward.end.circle.fill" : "forward.end.circle")
            }
            .toggleStyle(.button)
            .help(store.autoAdvance ? "Auto Advance on" : "Auto Advance off")

            Button {
                store.showFilmstrip.toggle()
            } label: {
                Label(
                    store.showFilmstrip ? "Hide Filmstrip" : "Show Filmstrip",
                    systemImage: "rectangle.bottomthird.inset.filled"
                )
            }
            .disabled(store.focusMode)
            .help("Toggle filmstrip (⌥⌘F)")

            Button {
                store.focusMode.toggle()
            } label: {
                Label(
                    store.focusMode ? "Exit Focus Mode" : "Focus Mode",
                    systemImage: store.focusMode ? "rectangle.compress.vertical" : "rectangle.expand.vertical"
                )
            }
            .help("Focus Mode (F)")

            if store.filter == .reject && store.count(for: .reject) > 0 {
                Button(role: .destructive) {
                    showTrashConfirmation = true
                } label: {
                    Label("Move Rejected to Trash", systemImage: "trash")
                }
                .disabled(store.isMovingToTrash)
                .help("Review and move rejected originals to macOS Trash")
            }
        }
    }

    private var statusText: String {
        if let index = store.currentIndex, store.visibleCount > 0 {
            return "\(index + 1) of \(store.visibleCount)  ·  \(store.reviewedCount) reviewed"
        }
        return "\(store.reviewedCount) of \(store.assets.count) reviewed"
    }
}
