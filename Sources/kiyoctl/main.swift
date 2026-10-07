import Foundation
import KiyoKit

let usage = """
usage: kiyoctl list                 show every control with current value and range
       kiyoctl get <control>
       kiyoctl set <control> <value>
       kiyoctl backup              save a snapshot to the app's backup folder
       kiyoctl restore <file.json> apply a saved profile or backup
       kiyoctl isp <hex bytes>      send a known Razer setting command, print reply
       kiyoctl isp-read             print the ISP result register
       kiyoctl snap <file.jpg>      save one camera frame (960 px wide)
       kiyoctl stats <a.jpg> [b.jpg] brightness and noise of a; with b: difference, and difference to b mirrored
"""

func fail(_ msg: String) -> Never {
    FileHandle.standardError.write(Data((msg + "\n").utf8))
    exit(1)
}

let args = Array(CommandLine.arguments.dropFirst())
guard let cmd = args.first else { fail(usage) }
guard let cam = UVCCamera() else { fail("Kiyo Pro Ultra not found") }

func control(_ id: String) -> UVCControl {
    guard let c = KiyoProUltra.control(id) else {
        fail("unknown control '\(id)'. Known: \(KiyoProUltra.all.map(\.id).joined(separator: ", "))")
    }
    return c
}

func ranges() -> [String: UVCRange] {
    var out: [String: UVCRange] = [:]
    for c in KiyoProUltra.all { out[c.id] = try? cam.range(c) }
    return out
}

switch cmd {
case "list":
    for c in KiyoProUltra.all {
        let cur = (try? cam.get(c)).map(String.init) ?? "--"
        let r = try? cam.range(c)
        let range = r.map { "min \($0.min)  max \($0.max)  step \($0.step)  default \($0.defaultValue)" } ?? "(range unavailable)"
        print(c.id.padding(toLength: 18, withPad: " ", startingAt: 0), cur.padding(toLength: 10, withPad: " ", startingAt: 0), range)
    }
case "get" where args.count == 2:
    do { print(try cam.get(control(args[1]))) } catch { fail("\(error)") }
case "set" where args.count == 3:
    let c = control(args[1])
    guard let v = Int(args[2]) else { fail("value must be an integer") }
    if case .range = c.kind, let r = try? cam.range(c), !(r.min...r.max).contains(v) {
        fail("\(v) is outside \(r.min)...\(r.max)")
    }
    do { try cam.set(c, v); print("\(c.id) = \(try cam.get(c))") } catch { fail("\(error)") }
case "backup":
    do { print(try ProfileStore().backup(cam.snapshot(), reason: "kiyoctl").path) } catch { fail("\(error)") }
case "restore" where args.count == 2:
    guard let data = FileManager.default.contents(atPath: args[1]) else { fail("cannot read \(args[1])") }
    let dec = JSONDecoder()
    dec.dateDecodingStrategy = .iso8601
    guard let p = try? dec.decode(Profile.self, from: data) else { fail("not a profile file") }
    let failed = cam.apply(p.values, ranges: ranges())
    if !failed.isEmpty { fail("failed: \(failed)") }
    print("restored \(p.values.count) values")
case "isp" where args.count >= 2:
    // Razer extension unit 6: selector 1 takes an 8-byte command, selector 2 returns the result.
    // Only command families documented for this camera (cameractrls issue #19) are allowed.
    // Anything else, including the c0 03 a8 save-to-NVRAM command, is refused.
    let hex = args.dropFirst().joined().replacingOccurrences(of: " ", with: "")
    var bytes = stride(from: 0, to: hex.count, by: 2).compactMap { i -> UInt8? in
        let start = hex.index(hex.startIndex, offsetBy: i)
        return UInt8(hex[start..<hex.index(start, offsetBy: min(2, hex.count - i))], radix: 16)
    }
    let allowed: [[UInt8]] = [
        [0xC0, 0x0E, 0x01], [0xC0, 0x0E, 0x02], [0xC0, 0x0E, 0x03], [0xC0, 0x0E, 0x04], [0xC0, 0x0E, 0x05],
        [0xC0, 0x09, 0x01], [0xC0, 0x09, 0x05], [0xC0, 0x0A, 0x01], [0xFF, 0x01], [0xFF, 0x02], [0xFF, 0x06],
    ]
    guard bytes.count <= 8, allowed.contains(where: { bytes.starts(with: $0) }) else {
        fail("refusing: not a known setting command")
    }
    bytes += [UInt8](repeating: 0, count: 8 - bytes.count)
    do {
        try cam.rawSet(unit: 6, selector: 1, bytes: bytes)
        let reply = try cam.raw(.getCur, unit: 6, selector: 2, length: 8)
        print("sent ", bytes.map { String(format: "%02x", $0) }.joined(separator: " "))
        print("reply", reply.map { String(format: "%02x", $0) }.joined(separator: " "))
    } catch { fail("\(error)") }
case "snap" where args.count == 2:
    do { try snap(to: args[1]); print("saved \(args[1])") } catch { fail("\(error)") }
case "stats" where args.count == 2 || args.count == 3:
    do {
        let a = try ImageStats.load(args[1])
        var out = String(format: "brightness %.1f  noise %.2f", ImageStats.mean(a), ImageStats.noise(a))
        if args.count == 3 {
            let b = try ImageStats.load(args[2])
            out += String(format: "  diff %.1f  diff-to-mirrored %.1f", ImageStats.difference(a, b), ImageStats.difference(a, ImageStats.flipped(b)))
        }
        print(out)
    } catch { fail("\(error)") }
case "isp-read":
    do {
        print(try cam.raw(.getCur, unit: 6, selector: 2, length: 8).map { String(format: "%02x", $0) }.joined(separator: " "))
    } catch { fail("\(error)") }
default:
    fail(usage)
}
