import SwiftUI

struct MainView: View {
    @EnvironmentObject private var store: PhotoLibraryStore
    @State private var showDeleteConfirmation = false

    var body: some View {
        HSplitView {
            if !store.focusMode {
                SidebarView()
                    .frame(minWidth: 176, idealWidth: 208, maxWidth: 238)
            }

            VStack(spacing: 0) {
                PreviewView()

                if store.showFilmstrip && !store.focusMode && !store.visibleAssets.isEmpty {
                    FilmstripView()
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .frame(minWidth: 520)
        }
        .animation(.snappy(duration: 0.18), value: store.focusMode)
        .animation(.snappy(duration: 0.18), value: store.showFilmstrip)
        .navigationTitle("PhotoSelect")
        .toolbar {
            PhotoSelectToolbar(
                store: store,
                showTrashConfirmation: $showDeleteConfirmation
            )
        }
        .confirmationDialog(
            "Move rejected photos to Trash?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Move \(store.count(for: .reject)) Photos to Trash", role: .destructive) {
                Task { await store.moveRejectedToTrash() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Reject is only a PhotoSelect decision until this step. The selected originals will move to the normal macOS Trash and remain recoverable there.")
        }
        .alert("PhotoSelect", isPresented: Binding(
            get: { store.alertMessage != nil },
            set: { if !$0 { store.alertMessage = nil } }
        )) {
            Button("OK") { store.alertMessage = nil }
        } message: {
            Text(store.alertMessage ?? "")
        }
        .task {
            await store.restoreLastFolderIfAvailable()
        }
    }
}
