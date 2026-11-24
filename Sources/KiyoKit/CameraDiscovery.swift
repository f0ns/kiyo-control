import Foundation
import IOKit

/// A USB camera found on the Mac, supported or not. Lets the app explain why it can't connect
/// (no camera, a model it doesn't know yet, another brand) and pick one of several Kiyos.
public struct USBCamera: Equatable, Sendable, Identifiable {
    public let name: String
    public let vendorID: UInt16
    public let productID: UInt16
    /// The USB port path; tells two cameras of the same model apart.
    public let locationID: UInt32
    public let link: USBLink

    public init(name: String, vendorID: UInt16, productID: UInt16, locationID: UInt32, link: USBLink) {
        self.name = name
        self.vendorID = vendorID
        self.productID = productID
        self.locationID = locationID
        self.link = link
    }

    public var id: UInt32 { locationID }

    public enum Status: Equatable, Sendable {
        case supported(KiyoDevice)
        /// A Razer camera without a known control map, e.g. the original Kiyo.
        case unsupportedRazer
        case other
    }

    public var status: Status {
        if let device = KiyoDevice.all.first(where: { $0.vendorID == vendorID && $0.productID == productID }) {
            return .supported(device)
        }
        return vendorID == KiyoDevice.razerVendorID ? .unsupportedRazer : .other
    }

    public var device: KiyoDevice? {
        if case .supported(let device) = status { return device }
        return nil
    }

    /// USB ids as people write them, e.g. "1532:0E0C".
    public var usbID: String { String(format: "%04X:%04X", vendorID, productID) }
}

public enum CameraDiscovery {
    /// Every plugged-in USB device that has a video interface. Needs no camera permission.
    public static func scan() -> [USBCamera] {
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("IOUSBHostDevice"), &iterator) == KERN_SUCCESS else {
            return []
        }
        defer { IOObjectRelease(iterator) }
        var cameras: [USBCamera] = []
        while case let service = IOIteratorNext(iterator), service != 0 {
            defer { IOObjectRelease(service) }
            guard hasVideoInterface(service),
                  let vendor = number(service, "idVendor"), let product = number(service, "idProduct"),
                  let location = number(service, "locationID") else { continue }
            let name = IORegistryEntryCreateCFProperty(service, "USB Product Name" as CFString, kCFAllocatorDefault, 0)?
                .takeRetainedValue() as? String
            cameras.append(USBCamera(
                name: name ?? "USB camera", vendorID: UInt16(truncatingIfNeeded: vendor.intValue),
                productID: UInt16(truncatingIfNeeded: product.intValue), locationID: location.uint32Value,
                link: link(service)))
        }
        return cameras.sorted { $0.locationID < $1.locationID }
    }

    /// The camera to connect to: the preferred one if it's plugged in and supported, otherwise the first supported one.
    public static func choose(_ cameras: [USBCamera], preferring location: UInt32?) -> USBCamera? {
        let supported = cameras.filter { $0.device != nil }
        return supported.first { $0.locationID == location } ?? supported.first
    }

    /// A prefilled GitHub issue asking for support of a camera, with the information needed to add it.
    public static func supportRequestURL(for camera: USBCamera) -> URL {
        var c = URLComponents(string: "https://github.com/f0ns/kiyo-control/issues/new")!
        c.queryItems = [
            URLQueryItem(name: "title", value: "Support \(camera.name) (\(camera.usbID))"),
            URLQueryItem(name: "body", value: """
                Camera: \(camera.name)
                USB id: \(camera.usbID)

                Output of `tools/uvc-dump \(String(format: "%04X %04X", camera.vendorID, camera.productID))` \
                (build it as described at the top of tools/uvc-dump.c):

                ```
                paste here
                ```
                """),
        ]
        return c.url!
    }

    /// Link speed, firmware and USB version, as the IO registry reports them.
    static func link(_ service: io_service_t) -> USBLink {
        USBLink(bitsPerSecond: number(service, "UsbLinkSpeed")?.intValue ?? 0,
                firmware: number(service, "bcdDevice").map { USBLink.firmwareVersion(bcd: $0.intValue) },
                usbVersion: number(service, "bcdUSB")?.intValue)
    }

    private static func number(_ service: io_service_t, _ key: String) -> NSNumber? {
        IORegistryEntryCreateCFProperty(service, key as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? NSNumber
    }

    /// True if any interface of the device is USB video class (0x0E).
    private static func hasVideoInterface(_ device: io_service_t) -> Bool {
        var children: io_iterator_t = 0
        guard IORegistryEntryGetChildIterator(device, kIOServicePlane, &children) == KERN_SUCCESS else { return false }
        defer { IOObjectRelease(children) }
        while case let child = IOIteratorNext(children), child != 0 {
            defer { IOObjectRelease(child) }
            if number(child, "bInterfaceClass")?.intValue == 0x0E { return true }
        }
        return false
    }
}
