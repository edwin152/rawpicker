import Foundation

final class NavigationPaceTracker {
    private var events: [NavigationEvent] = []

    func record(direction: Int) {
        let now = Date()
        events.append(NavigationEvent(time: now, direction: direction))
        events.removeAll { now.timeIntervalSince($0.time) > 0.9 }
    }

    func strategy(for direction: Int) -> PreloadStrategy {
        let recent = events.filter { $0.direction == direction }
        guard recent.count >= 2 else {
            return .slow(direction: direction)
        }

        let duration = max(0.05, recent.last!.time.timeIntervalSince(recent.first!.time))
        let speed = Double(recent.count - 1) / duration

        if speed >= 7 {
            return .veryFast(direction: direction)
        }
        if speed >= 3 {
            return .fast(direction: direction)
        }
        return .slow(direction: direction)
    }
}

private struct NavigationEvent: Sendable {
    let time: Date
    let direction: Int
}
