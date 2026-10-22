import SwiftUI

@main
struct PhotoSelectApp: App {
    @StateObject private var store = PhotoLibraryStore()

    var body: some Scene {
        WindowGroup {
            MainView()
                .environmentObject(store)
                .frame(minWidth: 900, minHeight: 560)
        }
        .defaultSize(width: 1320, height: 840)
        .windowToolbarStyle(.unified)
        .commands {
            PhotoSelectCommands(store: store)
        }

        Settings {
            SettingsView()
                .environmentObject(store)
        }
    }
}

struct PhotoSelectCommands: Commands {
    @ObservedObject var store: PhotoLibraryStore

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("Open Folder…") { store.chooseFolder() }
                .keyboardShortcut("o", modifiers: [.command])

            Menu("Open Recent") {
                if store.recentFolders.isEmpty {
                    Text("No Recent Folders")
                } else {
                    ForEach(store.recentFolders, id: \.standardizedFileURL.path) { folder in
                        Button(folder.lastPathComponent) {
                            store.openRecentFolder(folder)
                        }
                    }

                    Divider()

                    Button("Clear Menu") {
                        store.clearRecentFolders()
                    }
                }
            }
        }

        CommandGroup(replacing: .undoRedo) {
            Button("Undo Last Decision") { store.undo() }
                .keyboardShortcut("z", modifiers: [.command])
                .disabled(!store.canUndo)
        }

        CommandMenu("Culling") {
            Button("Clear Decision") { store.apply(.unreviewed) }
                .keyboardShortcut("0", modifiers: [])
            Button("Reject") { store.apply(.reject) }
                .keyboardShortcut("1", modifiers: [])
            Button("Keep") { store.apply(.keep) }
                .keyboardShortcut("2", modifiers: [])
            Button("Select") { store.apply(.select) }
                .keyboardShortcut("3", modifiers: [])
            Button("Hero") { store.apply(.hero) }
                .keyboardShortcut("4", modifiers: [])

            Divider()

            Button("Previous Photo") { store.previous() }
                .keyboardShortcut(.leftArrow, modifiers: [])
            Button("Next Photo") { store.next() }
                .keyboardShortcut(.rightArrow, modifiers: [])
            Button("First Photo") { store.first() }
                .keyboardShortcut(.leftArrow, modifiers: [.command])
            Button("Last Photo") { store.last() }
                .keyboardShortcut(.rightArrow, modifiers: [.command])

            Divider()

            Button(store.focusMode ? "Exit Focus Mode" : "Enter Focus Mode") {
                store.focusMode.toggle()
            }
            .keyboardShortcut("f", modifiers: [])

            Button(store.showFilmstrip ? "Hide Filmstrip" : "Show Filmstrip") {
                store.showFilmstrip.toggle()
            }
            .keyboardShortcut("f", modifiers: [.command, .option])

            Divider()

            Button("Zoom In") { store.zoomIn() }
                .keyboardShortcut("+", modifiers: [.command])
            Button("Zoom Out") { store.zoomOut() }
                .keyboardShortcut("-", modifiers: [.command])
            Button("Zoom to Fit") { store.zoomToFit() }
                .keyboardShortcut("0", modifiers: [.command])
        }
    }
}
