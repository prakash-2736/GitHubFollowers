import UIKit

@MainActor
final class ImageLoader {

    // MARK: - Shared Instance

    static let shared = ImageLoader()

    // MARK: - Properties

    private let imageCache = NSCache<NSURL, UIImage>()

    private let session: URLSession

    // MARK: - Initialization

    private init(session: URLSession = .shared) {
        self.session = session
        imageCache.totalCostLimit = 50 * 1024 * 1024
        imageCache.countLimit = 200
    }

    // MARK: - Load Image

    func loadImage(from url: URL) async throws -> UIImage {

        try Task.checkCancellation()

        let cacheKey = url as NSURL

        // 1. Check memory cache.
        if let cachedImage = imageCache.object(forKey: cacheKey) {
            return cachedImage
        }

        // 2. Create a resized avatar URL.
        let resizedURL = try makeResizedURL(from: url)

        // 3. Download image data.
        let (data, response) = try await session.data(from: resizedURL)

        try Task.checkCancellation()

        // 4. Validate HTTP response.
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw ImageLoaderError.invalidResponse
        }

        // 5. Decode image away from the main actor.
        let decodedImage = await Task.detached(
            priority: .userInitiated
        ) {
            UIImage(data: data)
        }.value

        try Task.checkCancellation()

        guard let image = decodedImage else {
            throw ImageLoaderError.invalidImage
        }

        // 6. Store image in memory cache.
        imageCache.setObject(
            image,
            forKey: cacheKey,
            cost: data.count
        )

        return image
    }

    // MARK: - Resize Avatar URL

    private func makeResizedURL(from url: URL) throws -> URL {

        guard var components = URLComponents(
            url: url,
            resolvingAgainstBaseURL: false
        ) else {
            throw ImageLoaderError.invalidURL
        }

        var queryItems = components.queryItems ?? []

        queryItems.removeAll { $0.name == "s" }

        queryItems.append(
            URLQueryItem(name: "s", value: "140")
        )

        components.queryItems = queryItems

        guard let resizedURL = components.url else {
            throw ImageLoaderError.invalidURL
        }

        return resizedURL
    }
}

// MARK: - Errors

enum ImageLoaderError: Error {
    case invalidURL
    case invalidResponse
    case invalidImage
}
