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
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "globe")
                    .foregroundStyle(.tint)
                Text(URL(string: item.plainText ?? "")?.host() ?? "Link")
                    .font(.callout.weight(.semibold))
                    .lineLimit(1)
            }
            Text(item.plainText ?? "")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(4)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
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
