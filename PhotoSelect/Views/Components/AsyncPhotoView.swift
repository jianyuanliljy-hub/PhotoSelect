import AppKit
import SwiftUI

struct AsyncPhotoView: View {
    let url: URL
    let maxPixel: CGFloat
    var contentMode: ContentMode = .fit

    @State private var image: NSImage?
    @State private var isLoading = false
    @State private var failed = false
    @State private var loadedURL: URL?

    var body: some View {
        ZStack {
            if let image, loadedURL == url {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else if failed {
                Image(systemName: "exclamationmark.triangle")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            } else {
                ProgressView()
                    .controlSize(.small)
                    .opacity(isLoading ? 1 : 0)
            }
        }
        .task(id: "\(url.path)|\(Int(maxPixel))") {
            let requestedURL = url
            failed = false
            if let cached = ImagePipeline.shared.cachedImage(for: requestedURL, maxPixel: maxPixel) {
                image = cached
                loadedURL = requestedURL
                isLoading = false
                return
            }

            image = nil
            loadedURL = nil
            isLoading = true
            let loadedImage = await ImagePipeline.shared.load(url: requestedURL, maxPixel: maxPixel)
            guard !Task.isCancelled, requestedURL == url else { return }
            image = loadedImage
            loadedURL = loadedImage == nil ? nil : requestedURL
            failed = loadedImage == nil
            isLoading = false
        }
    }
}

/// A photo-first inspection surface backed by NSScrollView so trackpad pinch,
/// inertial two-finger panning, elastic limits, and point-anchored zoom all use
/// the same native behavior as other macOS image viewers.
struct ZoomablePhotoView: View {
    let url: URL
    @Binding var zoomScale: CGFloat

    @State private var previewImage: NSImage?
    @State private var inspectionImage: NSImage?
    @State private var loadedURL: URL?
    @State private var failed = false

    var body: some View {
        ZStack {
            if let image = inspectionImage ?? previewImage, loadedURL == url {
                NativeZoomPhotoView(
                    image: image,
                    identity: url.standardizedFileURL.path,
                    zoomScale: $zoomScale
                )
            } else if failed {
                Image(systemName: "exclamationmark.triangle")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            } else {
                ProgressView()
                    .controlSize(.small)
                    .tint(.white)
            }
        }
        .task(id: url.standardizedFileURL.path) {
            zoomScale = 1
            previewImage = nil
            inspectionImage = nil
            loadedURL = nil
            failed = false

            let requestedURL = url
            let image = await ImagePipeline.shared.load(
                url: requestedURL,
                maxPixel: ImagePipeline.previewMaxPixel
            )
            guard !Task.isCancelled, requestedURL == url else { return }
            previewImage = image
            loadedURL = image == nil ? nil : requestedURL
            failed = image == nil
        }
        .task(id: inspectionRequestID) {
            guard zoomScale > 1.05, loadedURL == url else { return }
            let requestedURL = url
            let image = await ImagePipeline.shared.load(
                url: requestedURL,
                maxPixel: ImagePipeline.inspectionMaxPixel
            )
            guard !Task.isCancelled, requestedURL == url else { return }
            inspectionImage = image
        }
    }

    private var inspectionRequestID: String {
        "\(url.standardizedFileURL.path)|\(zoomScale > 1.05)"
    }
}

private struct NativeZoomPhotoView: NSViewRepresentable {
    let image: NSImage
    let identity: String
    @Binding var zoomScale: CGFloat

    func makeCoordinator() -> Coordinator {
        Coordinator(zoomScale: $zoomScale)
    }

    func makeNSView(context: Context) -> PhotoZoomContainerView {
        let container = PhotoZoomContainerView()
        let scrollView = container.scrollView
        scrollView.wantsLayer = true
        scrollView.layer?.masksToBounds = true
        scrollView.drawsBackground = true
        scrollView.backgroundColor = .black
        scrollView.borderType = .noBorder
        scrollView.hasHorizontalScroller = false
        scrollView.hasVerticalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.allowsMagnification = true
        scrollView.horizontalScrollElasticity = .automatic
        scrollView.verticalScrollElasticity = .automatic
        scrollView.usesPredominantAxisScrolling = false

        let clipView = CenteringClipView()
        clipView.wantsLayer = true
        clipView.layer?.masksToBounds = true
        clipView.drawsBackground = true
        clipView.backgroundColor = .black
        scrollView.contentView = clipView

        let imageView = NSImageView()
        imageView.imageScaling = .scaleAxesIndependently
        imageView.imageAlignment = .alignCenter
        scrollView.documentView = imageView
        scrollView.imageView = imageView
        scrollView.onLayout = { [weak coordinator = context.coordinator] scrollView in
            coordinator?.refreshFit(in: scrollView, preserveZoom: true)
        }

        context.coordinator.attach(to: scrollView)
        context.coordinator.update(
            scrollView: scrollView,
            image: image,
            identity: identity,
            requestedZoom: zoomScale
        )
        return container
    }

    func updateNSView(_ container: PhotoZoomContainerView, context: Context) {
        context.coordinator.update(
            scrollView: container.scrollView,
            image: image,
            identity: identity,
            requestedZoom: zoomScale
        )
    }

    final class Coordinator {
        private var zoomScale: Binding<CGFloat>
        private var identity: String?
        private var fitMagnification: CGFloat = 1
        private var viewportSize: CGSize = .zero
        private var documentSize: CGSize = .zero
        private var observation: NSKeyValueObservation?
        private var isUpdating = false

        init(zoomScale: Binding<CGFloat>) {
            self.zoomScale = zoomScale
        }

        func attach(to scrollView: PhotoScrollView) {
            observation = scrollView.observe(\.magnification, options: [.new]) { [weak self, weak scrollView] _, change in
                guard let self, let scrollView, !self.isUpdating,
                      let magnification = change.newValue,
                      self.fitMagnification > 0 else { return }
                let normalized = PhotoLibraryStore.clampedZoom(magnification / self.fitMagnification)
                guard abs(normalized - self.zoomScale.wrappedValue) > 0.005 else { return }
                DispatchQueue.main.async {
                    self.zoomScale.wrappedValue = normalized
                }
            }
        }

        func update(
            scrollView: PhotoScrollView,
            image: NSImage,
            identity: String,
            requestedZoom: CGFloat
        ) {
            let imageChanged = self.identity != identity
            let isReplacingResolution = !imageChanged && scrollView.imageView?.image !== image
            let relativeCenter = relativeVisibleCenter(in: scrollView)
            self.identity = identity

            if scrollView.imageView?.image !== image {
                scrollView.imageView?.image = image
                scrollView.imageView?.frame = NSRect(origin: .zero, size: image.size)
            }

            refreshFit(in: scrollView, preserveZoom: !imageChanged)
            let targetCenter = if imageChanged {
                imageCenter(in: scrollView)
            } else if isReplacingResolution {
                scaledCenter(relativeCenter, in: scrollView)
            } else {
                visibleCenter(in: scrollView)
            }
            apply(
                PhotoLibraryStore.clampedZoom(imageChanged ? 1 : requestedZoom),
                to: scrollView,
                centeredAt: targetCenter
            )
        }

        func refreshFit(in scrollView: PhotoScrollView, preserveZoom: Bool) {
            guard let imageView = scrollView.imageView,
                  imageView.bounds.width > 0,
                  imageView.bounds.height > 0,
                  scrollView.contentSize.width > 0,
                  scrollView.contentSize.height > 0 else { return }

            let newViewportSize = scrollView.contentSize
            let newDocumentSize = imageView.bounds.size
            guard newViewportSize != viewportSize
                    || newDocumentSize != documentSize
                    || fitMagnification == 1 else { return }

            let normalized = preserveZoom && fitMagnification > 0
                ? PhotoLibraryStore.clampedZoom(scrollView.magnification / fitMagnification)
                : 1
            viewportSize = newViewportSize
            documentSize = newDocumentSize
            fitMagnification = min(
                newViewportSize.width / imageView.bounds.width,
                newViewportSize.height / imageView.bounds.height
            )
            fitMagnification = max(fitMagnification, 0.01)
            scrollView.minMagnification = fitMagnification
            scrollView.maxMagnification = fitMagnification * 8
            apply(normalized, to: scrollView, centeredAt: visibleCenter(in: scrollView))
        }

        private func apply(_ normalizedZoom: CGFloat, to scrollView: NSScrollView, centeredAt point: NSPoint) {
            let target = fitMagnification * normalizedZoom
            guard abs(scrollView.magnification - target) > 0.0005 else { return }
            isUpdating = true
            scrollView.setMagnification(target, centeredAt: point)
            isUpdating = false
        }

        private func visibleCenter(in scrollView: NSScrollView) -> NSPoint {
            NSPoint(
                x: scrollView.documentVisibleRect.midX,
                y: scrollView.documentVisibleRect.midY
            )
        }

        private func relativeVisibleCenter(in scrollView: PhotoScrollView) -> NSPoint {
            guard let imageView = scrollView.imageView,
                  imageView.bounds.width > 0,
                  imageView.bounds.height > 0 else {
                return NSPoint(x: 0.5, y: 0.5)
            }
            let center = visibleCenter(in: scrollView)
            return NSPoint(
                x: min(max(center.x / imageView.bounds.width, 0), 1),
                y: min(max(center.y / imageView.bounds.height, 0), 1)
            )
        }

        private func scaledCenter(_ relativeCenter: NSPoint, in scrollView: PhotoScrollView) -> NSPoint {
            NSPoint(
                x: (scrollView.imageView?.bounds.width ?? 0) * relativeCenter.x,
                y: (scrollView.imageView?.bounds.height ?? 0) * relativeCenter.y
            )
        }

        private func imageCenter(in scrollView: PhotoScrollView) -> NSPoint {
            NSPoint(
                x: scrollView.imageView?.bounds.midX ?? 0,
                y: scrollView.imageView?.bounds.midY ?? 0
            )
        }
    }
}

private final class PhotoZoomContainerView: NSView {
    let scrollView = PhotoScrollView()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.masksToBounds = true
        addSubview(scrollView)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()
        scrollView.frame = bounds
    }
}

private final class PhotoScrollView: NSScrollView {
    weak var imageView: NSImageView?
    var onLayout: ((PhotoScrollView) -> Void)?

    override func layout() {
        super.layout()
        onLayout?(self)
    }
}

private final class CenteringClipView: NSClipView {
    override func constrainBoundsRect(_ proposedBounds: NSRect) -> NSRect {
        var bounds = super.constrainBoundsRect(proposedBounds)
        guard let documentView else { return bounds }

        if bounds.width > documentView.frame.width {
            bounds.origin.x = (documentView.frame.width - bounds.width) / 2
        }
        if bounds.height > documentView.frame.height {
            bounds.origin.y = (documentView.frame.height - bounds.height) / 2
        }
        return bounds
    }
}
