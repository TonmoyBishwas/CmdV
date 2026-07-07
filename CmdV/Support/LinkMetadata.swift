import AppKit
import LinkPresentation

/// Fetches and caches page titles + favicons for link cards.
/// In-memory cache only — link previews are a nicety, not state.
@MainActor
final class LinkMetadataCache {
    static let shared = LinkMetadataCache()

    struct Metadata {
        var title: String?
        var iconData: Data?
    }

    private var cache: [String: Metadata] = [:]
    private var inFlight: Set<String> = []

    func cached(for urlString: String) -> Metadata? {
        cache[urlString]
    }

    func fetch(urlString: String) async -> Metadata? {
        if let hit = cache[urlString] { return hit }
        guard !inFlight.contains(urlString), let url = URL(string: urlString) else { return nil }
        inFlight.insert(urlString)
        defer { inFlight.remove(urlString) }

        let provider = LPMetadataProvider()
        provider.timeout = 8
        guard let metadata = try? await provider.startFetchingMetadata(for: url) else {
            let miss = Metadata(title: nil, iconData: nil)
            cache[urlString] = miss
            return miss
        }

        var iconData: Data?
        if let iconProvider = metadata.iconProvider {
            iconData = await withCheckedContinuation { continuation in
                iconProvider.loadDataRepresentation(forTypeIdentifier: "public.image") { data, _ in
                    continuation.resume(returning: data)
                }
            }
        }
        let result = Metadata(title: metadata.title, iconData: iconData)
        cache[urlString] = result
        return result
    }
}
