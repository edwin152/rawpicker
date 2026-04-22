import Foundation

actor ImageCache {
    private var storage: [CacheKey: DecodedImage] = [:]
    private var order: [CacheKey] = []
    private let capacity: Int

    init(capacity: Int = 24) {
        self.capacity = capacity
    }

    func image(for key: CacheKey) -> DecodedImage? {
        guard let image = storage[key] else { return nil }
        touch(key)
        return image
    }

    func insert(_ image: DecodedImage, for key: CacheKey) {
        storage[key] = image
        touch(key)
        trimIfNeeded()
    }

    func removeAll() {
        storage.removeAll(keepingCapacity: true)
        order.removeAll(keepingCapacity: true)
    }

    private func touch(_ key: CacheKey) {
        order.removeAll { $0 == key }
        order.append(key)
    }

    private func trimIfNeeded() {
        while order.count > capacity, let oldest = order.first {
            order.removeFirst()
            storage.removeValue(forKey: oldest)
        }
    }
}
