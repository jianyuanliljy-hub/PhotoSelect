import SwiftUI

/// Deferred secondary inspector. It is intentionally not part of the default MVP
/// workspace; the culling surface should stay photo-first.
struct MetadataInspectorView: View {
    @EnvironmentObject private var store: PhotoLibraryStore
    @State private var metadata: PhotoMetadata?

    var body: some View {
        Group {
            if let asset = store.currentAsset {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(spacing: 12) {
                            AsyncPhotoView(
                                url: asset.url,
                                maxPixel: ImagePipeline.filmstripMaxPixel,
                                contentMode: .fill
                            )
                            .frame(width: 64, height: 64)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                            VStack(alignment: .leading, spacing: 3) {
                                Text(asset.filename)
                                    .font(.headline)
                                    .lineLimit(2)
                                    .truncationMode(.middle)
                                Text(metadata?.subheadline ?? "Reading metadata…")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        if let metadata {
                            ForEach(metadata.sections.prefix(2)) { section in
                                VStack(alignment: .leading, spacing: 7) {
                                    Label(section.title, systemImage: section.symbol)
                                        .font(.subheadline.weight(.semibold))

                                    ForEach(section.fields) { field in
                                        LabeledContent(field.label, value: field.value)
                                            .font(.caption)
                                    }
                                }
                                .padding(12)
                                .background(.quaternary, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                            }
                        }
                    }
                    .padding(14)
                }
                .task(id: asset.id) {
                    metadata = nil
                    metadata = await PhotoMetadataReader.shared.metadata(for: asset.url)
                }
            } else {
                ContentUnavailableView("No Photo Selected", systemImage: "info.circle")
            }
        }
    }
}
