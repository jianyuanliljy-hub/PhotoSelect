import SwiftUI

struct FilmstripView: View {
    @EnvironmentObject private var store: PhotoLibraryStore

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 7) {
                    ForEach(store.visibleAssets) { asset in
                        thumbnail(asset)
                            .id(asset.id)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 9)
            }
            .background(Color(red: 0.040, green: 0.043, blue: 0.050))
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(.white.opacity(0.09))
                    .frame(height: 1)
            }
            .onChange(of: store.currentID) { _, newID in
                guard let newID else { return }
                withAnimation(.easeOut(duration: 0.16)) {
                    proxy.scrollTo(newID, anchor: .center)
                }
            }
        }
        .frame(height: 94)
    }

    private func thumbnail(_ asset: PhotoAsset) -> some View {
        Button {
            store.select(asset.id)
        } label: {
            ZStack(alignment: .bottomTrailing) {
                AsyncPhotoView(url: asset.url, maxPixel: ImagePipeline.filmstripMaxPixel, contentMode: .fill)
                    .frame(width: 108, height: 72)
                    .background(.black)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

                if asset.decision != .unreviewed {
                    Image(systemName: asset.decision.filledSymbol)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(asset.decision.tint)
                        .frame(width: 20, height: 20)
                        .background(.black.opacity(0.72), in: Circle())
                        .padding(4)
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .strokeBorder(store.currentID == asset.id ? Color.accentColor : .white.opacity(0.10), lineWidth: store.currentID == asset.id ? 2 : 1)
            }
            .shadow(color: store.currentID == asset.id ? .black.opacity(0.45) : .clear, radius: 4, y: 2)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(asset.filename)
        .accessibilityValue(store.currentID == asset.id ? "Current photo, \(asset.decision.title)" : asset.decision.title)
    }
}
