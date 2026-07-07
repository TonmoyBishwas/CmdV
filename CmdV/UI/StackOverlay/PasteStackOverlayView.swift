import SwiftUI

/// The floating Paste Stack overlay: queued entries in paste order, with
/// glass morph animations as entries are consumed.
struct PasteStackOverlayView: View {
    @Bindable var controller: PasteStackController
    @Namespace private var glassNamespace

    var body: some View {
        GlassEffectContainer(spacing: 8) {
            VStack(alignment: .leading, spacing: 10) {
                header
                entryList
                Spacer(minLength: 0)
                footer
            }
            .padding(14)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .glassEffect(.regular, in: .rect(cornerRadius: 22))
        .padding(2)
    }

    private var header: some View {
        HStack {
            Image(systemName: "square.stack.3d.up.fill")
                .foregroundStyle(.tint)
            Text("Paste Stack")
                .font(.headline)
            Spacer()
            Button {
                controller.deactivate()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("End Paste Stack (⇧⌘C)")
        }
    }

    private var entryList: some View {
        ScrollView {
            VStack(spacing: 6) {
                ForEach(Array(controller.queue.pasteOrder.enumerated()), id: \.element.id) { index, entry in
                    HStack(spacing: 8) {
                        Text("\(index + 1)")
                            .font(.caption.monospacedDigit().weight(.bold))
                            .foregroundStyle(index == 0 ? AnyShapeStyle(.tint) : AnyShapeStyle(.tertiary))
                            .frame(width: 18)
                        Image(systemName: entry.kind.symbolName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(entry.label.isEmpty ? "Untitled" : entry.label)
                            .font(.callout)
                            .lineLimit(1)
                        Spacer(minLength: 0)
                        Button {
                            controller.remove(id: entry.id)
                        } label: {
                            Image(systemName: "xmark")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .glassEffect(
                        index == 0 ? .regular.tint(.accentColor.opacity(0.25)) : .regular,
                        in: .rect(cornerRadius: 10)
                    )
                    .glassEffectID(entry.id, in: glassNamespace)
                }
            }
        }
    }

    private var footer: some View {
        HStack {
            if controller.queue.isEmpty {
                Text("Copy things, then press ⌘V to paste them in order.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("⌘V pastes #1")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    controller.toggleReversed()
                } label: {
                    Label(
                        controller.queue.isReversed ? "Newest first" : "Oldest first",
                        systemImage: "arrow.up.arrow.down"
                    )
                    .font(.caption)
                }
                .buttonStyle(.plain)
                .help("Reverse paste order")
            }
        }
    }
}
