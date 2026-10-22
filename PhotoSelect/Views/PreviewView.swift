import SwiftUI

struct PreviewView: View {
    @EnvironmentObject private var store: PhotoLibraryStore

    var body: some View {
        GeometryReader { _ in
            ZStack {
                Color.black
                    .ignoresSafeArea()

                if let asset = store.currentAsset {
                    ZoomablePhotoView(url: asset.url, zoomScale: $store.previewZoomScale)
                    .padding(store.focusMode ? 4 : 10)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()

                    overlayChrome(for: asset)
                } else {
                    stateView
                }
            }
        }
    }

    @ViewBuilder
    private func overlayChrome(for asset: PhotoAsset) -> some View {
        VStack(spacing: 0) {
            HStack(alignment: .top) {
                infoPill(asset)
                Spacer()
                DecisionBadge(decision: asset.decision)
            }
            .padding(14)

            Spacer()

            ZStack(alignment: .bottom) {
                DecisionHUD(currentDecision: asset.decision)

                HStack {
                    Spacer()
                    ZoomHUD()
                }
            }
            .padding(.horizontal, 14)
            .padding(.bottom, store.focusMode ? 18 : 14)
        }
        .allowsHitTesting(true)
    }

    private func infoPill(_ asset: PhotoAsset) -> some View {
        HStack(spacing: 8) {
            Text(asset.filename)
                .lineLimit(1)
                .truncationMode(.middle)

            if let index = store.currentIndex {
                Divider()
                    .frame(height: 12)

                Text("\(index + 1) / \(store.visibleCount)")
                    .monospacedDigit()
            }
        }
        .font(.caption.weight(.medium))
        .foregroundStyle(.white.opacity(0.88))
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(.black.opacity(0.64), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(.white.opacity(0.10))
        }
        .frame(maxWidth: 360, alignment: .leading)
    }

    @ViewBuilder
    private var stateView: some View {
        if store.isLoading {
            VStack(spacing: 12) {
                ProgressView()
                    .tint(.white)
                Text(store.indexedCount == 0 ? "Finding photos…" : "Indexing \(store.indexedCount) photos…")
                    .font(.callout)
                    .foregroundStyle(.white.opacity(0.58))
            }
        } else if store.currentFolder == nil {
            emptyState(
                title: "Open a shoot",
                symbol: "photo.stack",
                message: "Choose a folder of photos. PhotoSelect reads them in place and keeps the originals untouched."
            ) {
                Button {
                    store.chooseFolder()
                } label: {
                    Label("Open Folder…", systemImage: "folder")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
        } else if store.filter == .unreviewed && !store.assets.isEmpty {
            emptyState(
                title: "First pass complete",
                symbol: "checkmark.circle",
                message: "There are no unreviewed photos left in this shoot. Review your strongest frames or return to all photos."
            ) {
                HStack(spacing: 10) {
                    Button("Review Selects") { store.setFilter(.select) }
                        .buttonStyle(.borderedProminent)
                    Button("All Photos") { store.setFilter(.all) }
                        .buttonStyle(.bordered)
                }
            }
        } else {
            emptyState(
                title: store.filter == .all ? "No supported photos" : "No photos in \(store.filter.title)",
                symbol: store.filter == .all ? "photo.badge.exclamationmark" : store.filter.symbol,
                message: store.filter == .all
                    ? "Choose another folder containing JPEG, HEIC, TIFF, PNG, or a camera RAW format supported by macOS."
                    : "Choose another filter to continue."
            ) {
                EmptyView()
            }
        }
    }

    private func emptyState<Actions: View>(
        title: String,
        symbol: String,
        message: String,
        @ViewBuilder actions: () -> Actions
    ) -> some View {
        VStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(.white.opacity(0.50))

            Text(title)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white.opacity(0.92))

            Text(message)
                .font(.callout)
                .foregroundStyle(.white.opacity(0.52))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 470)

            actions()
                .padding(.top, 4)
        }
        .padding(28)
    }
}

private struct ZoomHUD: View {
    @EnvironmentObject private var store: PhotoLibraryStore

    var body: some View {
        HStack(spacing: 2) {
            Button { store.zoomOut() } label: {
                Image(systemName: "minus.magnifyingglass")
            }
            .disabled(store.previewZoomScale <= 1)

            Button { store.zoomToFit() } label: {
                Text(store.previewZoomScale <= 1.01 ? "Fit" : "\(Int((store.previewZoomScale * 100).rounded()))%")
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .frame(minWidth: 38)
            }

            Button { store.zoomIn() } label: {
                Image(systemName: "plus.magnifyingglass")
            }
            .disabled(store.previewZoomScale >= 8)
        }
        .buttonStyle(.borderless)
        .foregroundStyle(.white.opacity(0.86))
        .padding(.horizontal, 7)
        .frame(height: 34)
        .background(.black.opacity(0.64), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .strokeBorder(.white.opacity(0.10))
        }
        .help("Pinch or scroll to inspect · ⌘+ / ⌘− · ⌘0 to fit")
    }
}

private struct DecisionHUD: View {
    @EnvironmentObject private var store: PhotoLibraryStore
    let currentDecision: PhotoDecision

    var body: some View {
        HStack(spacing: 4) {
            decisionButton(.reject, key: "1")
            decisionButton(.keep, key: "2")
            decisionButton(.select, key: "3")
            decisionButton(.hero, key: "4")
        }
        .padding(5)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .environment(\.colorScheme, .dark)
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(.white.opacity(0.11))
        }
        .shadow(color: .black.opacity(0.30), radius: 18, y: 8)
    }

    private func decisionButton(_ decision: PhotoDecision, key: String) -> some View {
        let selected = currentDecision == decision

        return Button {
            store.apply(decision)
        } label: {
            HStack(spacing: 7) {
                Text(key)
                    .font(.caption2.monospaced().weight(.bold))
                    .foregroundStyle(.white.opacity(0.64))
                    .frame(width: 20, height: 20)
                    .background(.white.opacity(0.09), in: RoundedRectangle(cornerRadius: 5, style: .continuous))

                Image(systemName: selected ? decision.filledSymbol : decision.symbol)
                    .foregroundStyle(selected ? decision.tint : .white.opacity(0.72))

                Text(decision.title)
                    .foregroundStyle(.white.opacity(selected ? 0.98 : 0.78))
            }
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 9)
            .frame(height: 34)
            .background(
                selected ? decision.tint.opacity(0.16) : .clear,
                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(store.currentAsset == nil)
        .help("\(decision.title) (\(key))")
    }
}
