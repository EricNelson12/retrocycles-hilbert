import Cocoa
import Carbon
import Foundation

let kInjectedTag: Int64 = 0xDEAD
let unitDelay = 0.2  // seconds per Hilbert grid unit

func simulateKey(keyCode: CGKeyCode, shift: Bool = false) {
    let source = CGEventSource(stateID: .hidSystemState)
    source?.userData = kInjectedTag
    let down = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true)
    let up   = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)
    if shift {
        down?.flags = .maskShift
        up?.flags   = .maskShift
    }
    down?.post(tap: .cghidEventTap)
    up?.post(tap: .cghidEventTap)
}

func hilbertCurve(order: Int) -> [(Int, Int)] {
    guard order > 0 else { return [(0, 0)] }
    let previous = hilbertCurve(order: order - 1)
    let size = 1 << (order - 1)
    let bottomLeft  = previous.map { ($0.1, $0.0) }
    let topLeft     = previous.map { ($0.0, $0.1 + size) }
    let topRight    = previous.map { ($0.0 + size, $0.1 + size) }
    let bottomRight = previous.map { (2 * size - 1 - $0.1, size - 1 - $0.0) }
    return bottomLeft + topLeft + topRight + bottomRight
}

func computeHilbertMoves(order: Int = 3) -> [(steps: Int, isLeft: Bool?)] {
    let points = hilbertCurve(order: order)
    guard points.count >= 2 else { return [(1, nil)] }
    var result: [(steps: Int, isLeft: Bool?)] = []
    var forwardCount = 1
    for i in 1..<(points.count - 1) {
        let dx1 = points[i].0 - points[i-1].0
        let dy1 = points[i].1 - points[i-1].1
        let dx2 = points[i+1].0 - points[i].0
        let dy2 = points[i+1].1 - points[i].1
        let cross = dx1 * dy2 - dy1 * dx2
        if cross == 0 {
            forwardCount += 1
        } else {
            result.append((steps: forwardCount, isLeft: cross > 0))
            forwardCount = 1
        }
    }
    result.append((steps: forwardCount, isLeft: nil))
    return result
}

func computeSpiralMoves(loops: Int = 4) -> [(steps: Int, isLeft: Bool?)] {
    var result: [(steps: Int, isLeft: Bool?)] = []
    let total = loops * 2
    for i in 1...total {
        result.append((steps: (i + 1) / 2, isLeft: i < total ? true : nil))
    }
    return result
}

func injectSpiral() {
    for _ in 0..<5 { simulateKey(keyCode: 51) }

    let moves = computeSpiralMoves()

    var events: [(offset: Double, keyCode: CGKeyCode)] = []
    var elapsed = 0.05
    for move in moves {
        elapsed += Double(move.steps) * unitDelay
        if let isLeft = move.isLeft {
            events.append((elapsed, isLeft ? 123 : 124))
        }
    }

    DispatchQueue.global(qos: .userInteractive).async {
        var tb = mach_timebase_info_data_t()
        mach_timebase_info(&tb)

        let t0 = mach_absolute_time()
        for event in events {
            let ns = UInt64(event.offset * 1_000_000_000)
            let ticks = ns * UInt64(tb.denom) / UInt64(tb.numer)
            mach_wait_until(t0 + ticks)
            simulateKey(keyCode: event.keyCode)
        }
    }
}

func injectExpansion() {
    for _ in 0..<5 { simulateKey(keyCode: 51) }

    let moves = computeHilbertMoves()

    // Precompute (offset_seconds, keyCode) for every turn, all relative to a single t0.
    var events: [(offset: Double, keyCode: CGKeyCode)] = []
    var elapsed = 0.05
    for move in moves {
        elapsed += Double(move.steps) * unitDelay
        if let isLeft = move.isLeft {
            events.append((elapsed, isLeft ? 123 : 124))  // 123 = left, 124 = right
        }
    }

    DispatchQueue.global(qos: .userInteractive).async {
        var tb = mach_timebase_info_data_t()
        mach_timebase_info(&tb)

        let t0 = mach_absolute_time()
        for event in events {
            let ns = UInt64(event.offset * 1_000_000_000)
            let ticks = ns * UInt64(tb.denom) / UInt64(tb.numer)
            mach_wait_until(t0 + ticks)
            simulateKey(keyCode: event.keyCode)
        }
    }
}

var buffer: [Int] = []

func startListening() {
    let eventMask = CGEventMask(1 << CGEventType.keyDown.rawValue)
    guard let tap = CGEvent.tapCreate(
        tap: .cgSessionEventTap,
        place: .headInsertEventTap,
        options: .defaultTap,
        eventsOfInterest: eventMask,
        callback: { _, type, event, _ in
            guard type == .keyDown else { return Unmanaged.passRetained(event) }

            // Ignore events we injected ourselves
            if event.getIntegerValueField(.eventSourceUserData) == kInjectedTag {
                return Unmanaged.passRetained(event)
            }

            let key = Int(event.getIntegerValueField(.keyboardEventKeycode))
            buffer.append(key)

            if buffer.suffix(5) == [41, 4, 34, 37, 36] { // :hil + Enter
                buffer.removeAll()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    injectExpansion()
                }
            }

            if buffer.suffix(5) == [41, 1, 35, 34, 36] { // :spi + Enter
                buffer.removeAll()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    injectSpiral()
                }
            }

            return Unmanaged.passRetained(event)
        },
        userInfo: nil
    ) else {
        print("Failed to create event tap.")
        return
    }

    let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
    CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
    CGEvent.tapEnable(tap: tap, enable: true)
    print("Listening — type :hil and press Enter in any app.")
    CFRunLoopRun()
}

if AXIsProcessTrusted() {
    startListening()
} else {
    print("Please ensure that Accessibility permissions are granted for this program.")
    print("1. Open System Settings > Privacy & Security > Accessibility.")
    print("2. Add the executable located at: \(CommandLine.arguments[0])")
    print("3. Enable the checkbox next to it.")
}
