import SwiftUI
import PDFKit
import UniformTypeIdentifiers

enum MergeState {
    case idle
    case processing
    case success(URL)
    case error(String)
}

struct ContentView: View {
    @State private var mergeState: MergeState = .idle
    @State private var isDragging = false
    @State private var safekeepingURL: URL? = nil
    @State private var showFilePicker = false
    @State private var droppedLabelURL: URL? = nil
    private let redactedKeyword = "confidential"

    private var canClear: Bool {
        switch mergeState {
        case .processing:
            return false
        case .idle:
            return droppedLabelURL != nil
        case .success, .error:
            return true
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            Divider()
            dropZone
                .frame(width: 320, height: 200)
                .padding(16)
            Divider()
            bottomBar
                .frame(height: 36)
                .padding(.horizontal, 16)
        }
        .frame(width: 352)
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear { loadSafekeeping() }
        .fileImporter(isPresented: $showFilePicker, allowedContentTypes: [.pdf], allowsMultipleSelection: false) { result in
            if case .success(let urls) = result, let url = urls.first {
                saveSafekeepingBookmark(url: url)
            }
        }
    }

    // MARK: - Header

    var headerBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Label Merger")
                    .font(.system(size: 13, weight: .semibold))
                Text("Drop label -> auto-merge overlay")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            Spacer()
            Button(action: { showFilePicker = true }) {
                HStack(spacing: 4) {
                    Circle()
                        .fill(safekeepingURL != nil ? Color.secondary.opacity(0.8) : Color.secondary.opacity(0.45))
                        .frame(width: 6, height: 6)
                    Text(safekeepingURL != nil ? "Overlay set" : "Set overlay")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(RoundedRectangle(cornerRadius: 6).fill(Color(NSColor.controlBackgroundColor)))
            }
            .buttonStyle(.plain)
            .help("Click to change the overlay PDF")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Drop Zone

    var dropZone: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(
                    borderColor,
                    style: StrokeStyle(lineWidth: 1.5, dash: isDragging ? [] : [6, 4])
                )
                .background(RoundedRectangle(cornerRadius: 12).fill(fillColor))
                .animation(.easeInOut(duration: 0.15), value: isDragging)

            dropZoneContent
        }
        .onDrop(of: [UTType.fileURL], isTargeted: $isDragging) { providers in
            handleDrop(providers: providers)
        }
    }

    @ViewBuilder
    var dropZoneContent: some View {
        switch mergeState {
        case .idle:
            VStack(spacing: 10) {
                Image(systemName: isDragging ? "arrow.down.doc.fill" : "doc.badge.plus")
                    .font(.system(size: 32, weight: .light))
                    .foregroundColor(isDragging ? .accentColor : Color.secondary.opacity(0.6))
                    .scaleEffect(isDragging ? 1.1 : 1.0)
                    .animation(.spring(response: 0.2), value: isDragging)
                Text(isDragging ? "Release to merge" : "Drop label PDF here")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(isDragging ? .accentColor : .secondary)
                if !isDragging {
                    Text("Sensitive marker text is removed automatically")
                        .font(.system(size: 10))
                        .foregroundColor(Color.secondary.opacity(0.5))
                        .multilineTextAlignment(.center)
                }
            }

        case .processing:
            VStack(spacing: 10) {
                ProgressView().scaleEffect(0.8)
                Text("Merging...")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }

        case .success(let url):
            VStack(spacing: 10) {
                Image(systemName: "checkmark.circle")
                    .font(.system(size: 32))
                    .foregroundColor(.secondary)
                Text("Merged successfully")
                    .font(.system(size: 13, weight: .medium))
                Button("Open in Finder") {
                    NSWorkspace.shared.activateFileViewerSelecting([url])
                }
                .buttonStyle(.plain)
                .font(.system(size: 11))
                .foregroundColor(.accentColor)
                Button("Drop another") {
                    mergeState = .idle
                }
                .buttonStyle(.plain)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            }

        case .error(let msg):
            VStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 28))
                    .foregroundColor(.secondary)
                Text(msg)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                Button("Try again") {
                    mergeState = .idle
                }
                .buttonStyle(.plain)
                .font(.system(size: 11))
                .foregroundColor(.accentColor)
            }
            .padding()
        }
    }

    var borderColor: Color {
        switch mergeState {
        case .success:
            return Color.secondary.opacity(0.4)
        case .error:
            return Color.secondary.opacity(0.35)
        default:
            return isDragging ? .accentColor : Color.secondary.opacity(0.25)
        }
    }

    var fillColor: Color {
        switch mergeState {
        case .success:
            return Color.secondary.opacity(0.05)
        case .error:
            return Color.secondary.opacity(0.04)
        default:
            return isDragging ? Color.accentColor.opacity(0.06) : Color(NSColor.controlBackgroundColor).opacity(0.5)
        }
    }

    // MARK: - Bottom Bar

    var bottomBar: some View {
        HStack {
            Text("Output saved to Desktop")
                .font(.system(size: 10))
                .foregroundColor(Color.secondary.opacity(0.5))

            Spacer()

            Button("Clear") {
                clearDroppedData()
            }
            .buttonStyle(.plain)
            .font(.system(size: 10))
            .foregroundColor(canClear ? .secondary : Color.secondary.opacity(0.4))
            .disabled(!canClear)

            if case .success(let url) = mergeState {
                Button(action: { NSWorkspace.shared.open(url) }) {
                    Label("Open PDF", systemImage: "eye")
                        .font(.system(size: 10))
                }
                .buttonStyle(.plain)
                .foregroundColor(.accentColor)
            }
        }
    }

    // MARK: - Safekeeping Bookmark (survives sandbox restarts)

    func saveSafekeepingBookmark(url: URL) {
        _ = url.startAccessingSecurityScopedResource()
        defer { url.stopAccessingSecurityScopedResource() }
        do {
            let bookmark = try url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
            UserDefaults.standard.set(bookmark, forKey: "safekeepingBookmark")
            safekeepingURL = url
        } catch {
            // Fallback: save plain path (works when sandbox is off)
            UserDefaults.standard.set(url.path, forKey: "safekeepingPath")
            safekeepingURL = url
        }
    }

    func loadSafekeeping() {
        // 1. Try security-scoped bookmark
        if let bookmarkData = UserDefaults.standard.data(forKey: "safekeepingBookmark") {
            var isStale = false
            if let url = try? URL(
                resolvingBookmarkData: bookmarkData,
                options: .withSecurityScope,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            ) {
                safekeepingURL = url
                if isStale {
                    saveSafekeepingBookmark(url: url)
                }
                return
            }
        }

        // 2. Plain path fallback (no sandbox)
        if let path = UserDefaults.standard.string(forKey: "safekeepingPath") {
            let url = URL(fileURLWithPath: path)
            if FileManager.default.fileExists(atPath: url.path) {
                safekeepingURL = url
                return
            }
        }

        // 3. Bundled resource
        if let url = Bundle.main.url(forResource: "SAFEKEEPING_LOGO_FOR_STAND_ALONE", withExtension: "pdf") {
            safekeepingURL = url
        }
    }

    // MARK: - Drop Handler

    func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }

        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
            var resolvedURL: URL?

            // NSData -> URL (most common from Finder drag)
            if let data = item as? Data {
                resolvedURL = URL(dataRepresentation: data, relativeTo: nil)
            }
            // NSURL directly
            else if let url = item as? URL {
                resolvedURL = url
            }
            // String path fallback
            else if let str = item as? String {
                resolvedURL = URL(fileURLWithPath: str)
            }

            guard let url = resolvedURL, url.pathExtension.lowercased() == "pdf" else {
                DispatchQueue.main.async {
                    mergeState = .error("Drop a PDF file.")
                }
                return
            }

            DispatchQueue.main.async {
                droppedLabelURL = url
                mergePDFs(labelURL: url)
            }
        }
        return true
    }

    // MARK: - Merge

    func mergePDFs(labelURL: URL) {
        guard let safekeepingURL else {
            mergeState = .error("No overlay set.\nClick 'Set overlay' above.")
            return
        }

        mergeState = .processing

        DispatchQueue.global(qos: .userInitiated).async {
            let labelScoped = labelURL.startAccessingSecurityScopedResource()
            let overlayScoped = safekeepingURL.startAccessingSecurityScopedResource()
            defer {
                if labelScoped {
                    labelURL.stopAccessingSecurityScopedResource()
                }
                if overlayScoped {
                    safekeepingURL.stopAccessingSecurityScopedResource()
                }
            }

            guard let labelDoc = PDFDocument(url: labelURL) else {
                DispatchQueue.main.async {
                    mergeState = .error("Cannot read label PDF.")
                }
                return
            }

            guard let overlayDoc = PDFDocument(url: safekeepingURL) else {
                DispatchQueue.main.async {
                    mergeState = .error("Cannot read overlay PDF.\nTry clicking 'Set overlay' again.")
                }
                return
            }

            let mergedDoc = PDFDocument()
            let overlayPage = overlayDoc.page(at: 0)

            for i in 0 ..< labelDoc.pageCount {
                guard let labelPage = labelDoc.page(at: i) else { continue }

                let labelBounds = labelPage.bounds(for: .mediaBox)
                let pdfData = NSMutableData()
                guard let consumer = CGDataConsumer(data: pdfData as CFMutableData) else { continue }

                var mediaBox = CGRect(origin: .zero, size: labelBounds.size)
                guard let ctx = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else { continue }

                ctx.beginPDFPage(nil)

                // Draw base label page.
                labelPage.draw(with: .mediaBox, to: ctx)

                var overlayScale = CGAffineTransform.identity
                if let overlayPage {
                    let overlayBounds = overlayPage.bounds(for: .mediaBox)
                    if overlayBounds.width > 0, overlayBounds.height > 0 {
                        let sx = labelBounds.width / overlayBounds.width
                        let sy = labelBounds.height / overlayBounds.height
                        overlayScale = CGAffineTransform(scaleX: sx, y: sy)

                        ctx.saveGState()
                        ctx.scaleBy(x: sx, y: sy)
                        overlayPage.draw(with: .mediaBox, to: ctx)
                        ctx.restoreGState()
                    }
                }

                // Remove all occurrences of the confidential marker text.
                paintRedactions(for: redactedKeyword, from: labelPage, in: ctx)
                if let overlayPage {
                    paintRedactions(for: redactedKeyword, from: overlayPage, in: ctx, transform: overlayScale)
                }

                ctx.endPDFPage()
                ctx.closePDF()

                if let page = PDFDocument(data: pdfData as Data)?.page(at: 0) {
                    mergedDoc.insert(page, at: mergedDoc.pageCount)
                }
            }

            let baseName = labelURL.deletingPathExtension().lastPathComponent
                .replacingOccurrences(of: "_merged", with: "")
            let outputName = baseName + "_merged.pdf"
            let desktop = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first
                ?? FileManager.default.temporaryDirectory
            let outputURL = desktop.appendingPathComponent(outputName)

            if mergedDoc.write(to: outputURL) {
                DispatchQueue.main.async {
                    mergeState = .success(outputURL)
                    NSWorkspace.shared.open(outputURL)
                }
            } else {
                DispatchQueue.main.async {
                    mergeState = .error("Failed to write output PDF.")
                }
            }
        }
    }

    // MARK: - Cleanup

    func clearDroppedData() {
        mergeState = .idle
        droppedLabelURL = nil
    }

    // MARK: - Redaction

    func paintRedactions(for keyword: String, from page: PDFPage, in context: CGContext, transform: CGAffineTransform = .identity) {
        let rects = redactionRects(for: keyword, in: page)
        guard !rects.isEmpty else { return }

        context.saveGState()
        context.setFillColor(NSColor.white.cgColor)
        for rect in rects {
            let padded = rect.insetBy(dx: -1.5, dy: -1.5)
            context.fill(padded.applying(transform))
        }
        context.restoreGState()
    }

    func redactionRects(for keyword: String, in page: PDFPage) -> [CGRect] {
        guard let pageString = page.string else { return [] }

        var results: [CGRect] = []
        let nsText = pageString as NSString
        var searchRange = NSRange(location: 0, length: nsText.length)

        while searchRange.length > 0 {
            let match = nsText.range(of: keyword, options: [.caseInsensitive], range: searchRange)
            guard match.location != NSNotFound, match.length > 0 else {
                break
            }

            if let selection = page.selection(for: match) {
                let bounds = selection.bounds(for: page)
                if !bounds.isNull, !bounds.isEmpty {
                    results.append(bounds)
                }
            }

            let nextLocation = match.location + max(match.length, 1)
            if nextLocation >= nsText.length {
                break
            }
            searchRange = NSRange(location: nextLocation, length: nsText.length - nextLocation)
        }

        return results
    }
}
