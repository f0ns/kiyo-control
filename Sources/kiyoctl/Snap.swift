@preconcurrency import AVFoundation
import CoreImage
import Foundation

/// Grabs one frame from the Kiyo after letting auto exposure settle, and writes it as JPEG.
final class FrameGrabber: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, @unchecked Sendable {
    private let session = AVCaptureSession()
    private let queue = DispatchQueue(label: "snap")
    private let done = DispatchSemaphore(value: 0)
    private var frames = 0
    private var image: CIImage?
    private let skip: Int

    init(skipFrames: Int) { skip = skipFrames }

    func grab() throws -> CIImage {
        let devices = AVCaptureDevice.DiscoverySession(deviceTypes: [.external], mediaType: .video, position: .unspecified).devices
        guard let device = devices.first(where: { $0.localizedName.localizedCaseInsensitiveContains("Kiyo") }) else {
            throw NSError(domain: "snap", code: 1, userInfo: [NSLocalizedDescriptionKey: "camera not found"])
        }
        session.addInput(try AVCaptureDeviceInput(device: device))
        let output = AVCaptureVideoDataOutput()
        output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        output.setSampleBufferDelegate(self, queue: queue)
        session.addOutput(output)
        session.startRunning()
        guard done.wait(timeout: .now() + 15) == .success, let image else {
            throw NSError(domain: "snap", code: 2, userInfo: [NSLocalizedDescriptionKey: "no frame within 15s"])
        }
        session.stopRunning()
        return image
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        frames += 1
        guard frames == skip, let buffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        image = CIImage(cvPixelBuffer: buffer)
        done.signal()
    }
}

func snap(to path: String) throws {
    let image = try FrameGrabber(skipFrames: 45).grab()
    let scaled = image.transformed(by: CGAffineTransform(scaleX: 960 / image.extent.width, y: 960 / image.extent.width))
    try CIContext().writeJPEGRepresentation(of: scaled, to: URL(fileURLWithPath: path),
                                            colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!)
}

/// Simple image measurements for checking that a setting changed the picture.
enum ImageStats {
    static let context = CIContext()

    static func load(_ path: String) throws -> CIImage {
        guard let i = CIImage(contentsOf: URL(fileURLWithPath: path)) else {
            throw NSError(domain: "stats", code: 1, userInfo: [NSLocalizedDescriptionKey: "cannot read \(path)"])
        }
        return i
    }

    /// Mean of R, G, B over the image, 0...255.
    static func mean(_ image: CIImage) -> Double {
        let f = CIFilter(name: "CIAreaAverage", parameters: [kCIInputImageKey: image, kCIInputExtentKey: CIVector(cgRect: image.extent)])!
        var px = [Float](repeating: 0, count: 4)
        context.render(f.outputImage!, toBitmap: &px, rowBytes: 16, bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
                       format: .RGBAf, colorSpace: nil)
        return Double(px[0] + px[1] + px[2]) / 3 * 255
    }

    static func difference(_ a: CIImage, _ b: CIImage) -> Double {
        mean(b.applyingFilter("CIDifferenceBlendMode", parameters: [kCIInputBackgroundImageKey: a]).cropped(to: a.extent))
    }

    static func flipped(_ i: CIImage) -> CIImage {
        i.transformed(by: CGAffineTransform(scaleX: -1, y: 1).translatedBy(x: -i.extent.width, y: 0))
    }

    /// Fine detail energy: difference between the image and a slightly blurred copy (higher = more noise/detail).
    static func noise(_ i: CIImage) -> Double {
        difference(i, i.clampedToExtent().applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: 1.5]).cropped(to: i.extent)) * 10
    }
}
