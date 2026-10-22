import SwiftUI

struct SidebarView: View {
    @EnvironmentObject private var store: PhotoLibraryStore

    var body: some View {
        List(selection: Binding(
            get: { store.filter },
            set: { newValue in
                guard let newValue else { return }
                store.setFilter(newValue)
            }
        )) {
            Section("Shoot") {
                sidebarRow(.all)
                sidebarRow(.unreviewed)
            }

            Section("Picks") {
                sidebarRow(.hero)
                sidebarRow(.select)
                sidebarRow(.keep)
            }

            Section {
                sidebarRow(.reject)
            }
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .bottom) {
            VStack(alignment: .leading, spacing: 9) {
                if let folder = store.currentFolder {
                    HStack(spacing: 8) {
                        Image(systemName: "folder")
                            .foregroundStyle(.secondary)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(folder.lastPathComponent)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Text(store.isLoading ? "Indexing \(store.indexedCount)…" : "\(store.assets.count) photos")
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }
                    .font(.caption)
                }

                Button {
                    store.chooseFolder()
                } label: {
                    Label(store.currentFolder == nil ? "Open Folder…" : "Change Folder…", systemImage: "folder.badge.plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                if !store.recentFolders.isEmpty {
                    Menu {
                        ForEach(store.recentFolders, id: \.standardizedFileURL.path) { folder in
                            Button(folder.lastPathComponent) {
                                store.openRecentFolder(folder)
                            }
                        }

                        Divider()

                        Button("Clear Recent Folders") {
                            store.clearRecentFolders()
                        }
                    } label: {
                        Label("Open Recent", systemImage: "clock.arrow.circlepath")
                            .frame(maxWidth: .infinity)
                    }
                    .menuStyle(.borderlessButton)
                }
            }
            .padding(12)
            .background(.bar)
        }
    }

    @ViewBuilder
    private func sidebarRow(_ filter: LibraryFilter) -> some View {
        HStack(spacing: 8) {
            Image(systemName: filter.symbol)
                .foregroundStyle(tint(for: filter))
                .frame(width: 18)

            Text(filter.title)

            Spacer(minLength: 8)

            Text("\(store.count(for: filter))")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .contentTransition(.numericText())
        }
        .tag(filter)
    }

    private func tint(for filter: LibraryFilter) -> Color {
        switch filter {
        case .hero: .purple
        case .select: .orange
        case .keep: .green
        case .reject: .red
        case .all, .unreviewed: .secondary
        }
    }
}
