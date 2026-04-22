enum PreloadStrategy: Sendable {
    case slow(direction: Int)
    case fast(direction: Int)
    case veryFast(direction: Int)

    var offsets: [Int] {
        switch self {
        case .slow:
            return [0, -1, 1, -2, 2]
        case .fast(let direction):
            return [0] + directionalOffsets(direction: direction, count: 4)
        case .veryFast(let direction):
            return [0] + directionalOffsets(direction: direction, count: 7)
        }
    }
}

private func directionalOffsets(direction: Int, count: Int) -> [Int] {
    guard direction != 0 else {
        return [-1, 1, -2, 2]
    }

    return (1...count).map { $0 * direction }
}
