import SwiftUI

/// Per-type body preview inside a card.
struct CardPreview: View {
    let item: ClipItem

    var body: some View {
        switch item.kind {
        case .text:
            textPreview
        case .code:
            codePreview
        case .link:
            linkPreview
        case .color:
            colorPreview
        case .image:
            imagePreview
        case .file:
            filePreview
        }
    }

    private var textPreview: some View {
        Text(item.plainText ?? "")
            .font(.callout)
            .lineLimit(9)
            .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private var codePreview: some View {
        Text(item.plainText ?? "")
            .font(.caption.monospaced())
            .lineLimit(10)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(8)
            .background(.black.opacity(0.25), in: .rect(cornerRadius: 8))
    }

    private var linkPreview: some View {
        LinkCardPreview(urlString: item.plainText ?? "")
    }

    private var colorPreview: some View {
        VStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(hexString: item.plainText ?? ""))
                .overlay {
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(.separator, lineWidth: 1)
                }
            Text(item.plainText ?? "")
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
        }
    }

    private var imagePreview: some View {
        Group {
            if let data = item.thumbnailData, let image = NSImage(data: data) {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .clipShape(.rect(cornerRadius: 8))
            } else {
                Image(systemName: "photo")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    fileprivate struct LinkCardPreview: View {
        let urlString: String
        @State private var metadata: LinkMetadataCache.Metadata?

        var body: some View {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    if let data = metadata?.iconData, let icon = NSImage(data: data) {
                        Image(nsImage: icon)
                            .resizable()
                            .frame(width: 16, height: 16)
                            .clipShape(.rect(cornerRadius: 3))
                    } else {
                        Image(systemName: "globe")
                            .foregroundStyle(.tint)
                    }
                    Text(metadata?.title ?? URL(string: urlString)?.host() ?? "Link")
                        .font(.callout.weight(.semibold))
                        .lineLimit(2)
                }
                Text(urlString)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .task(id: urlString) {
                if let hit = LinkMetadataCache.shared.cached(for: urlString) {
                    metadata = hit
                } else {
                    metadata = await LinkMetadataCache.shared.fetch(urlString: urlString)
                }
            }
        }
    }

    private var filePreview: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(item.fileURLPaths.prefix(4), id: \.self) { path in
                HStack(spacing: 6) {
                    Image(nsImage: NSWorkspace.shared.icon(forFile: path))
                        .resizable()
                        .frame(width: 20, height: 20)
                    Text(URL(fileURLWithPath: path).lastPathComponent)
                        .font(.caption)
                        .lineLimit(1)
                }
            }
            if item.fileURLPaths.count > 4 {
                Text("+ \(item.fileURLPaths.count - 4) more")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}
