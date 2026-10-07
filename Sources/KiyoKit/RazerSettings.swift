/// The Razer-specific settings. `nil` means unknown: the camera can't be asked for these, so the app
/// leaves them as they are (e.g. as set in Synapse) until the user changes them.
public struct RazerSettings: Codable, Equatable, Sendable {
    public var mirror: Bool?
    public var noiseReduction3D: Bool?
    public var noiseReduction2D: Bool?
    public var metering: RazerCommand.Metering?
    /// Tenths of a stop, -30...30.
    public var exposureCompensation: Int?
    public var faceFocus: Bool?
    public var stylizedLighting: Bool?
    public var responsiveTracking: Bool?
    public var lensCorrection: Bool?
    public var iso: Int?
    public var shutterMicroseconds: Int?

    public init(mirror: Bool? = nil, noiseReduction3D: Bool? = nil, noiseReduction2D: Bool? = nil,
                metering: RazerCommand.Metering? = nil, exposureCompensation: Int? = nil,
                faceFocus: Bool? = nil, stylizedLighting: Bool? = nil, responsiveTracking: Bool? = nil,
                lensCorrection: Bool? = nil, iso: Int? = nil, shutterMicroseconds: Int? = nil) {
        self.mirror = mirror
        self.noiseReduction3D = noiseReduction3D
        self.noiseReduction2D = noiseReduction2D
        self.metering = metering
        self.exposureCompensation = exposureCompensation
        self.faceFocus = faceFocus
        self.stylizedLighting = stylizedLighting
        self.responsiveTracking = responsiveTracking
        self.lensCorrection = lensCorrection
        self.iso = iso
        self.shutterMicroseconds = shutterMicroseconds
    }

    /// Commands for every known setting. ISO and shutter only apply in manual exposure.
    public func commands(manualExposure: Bool) -> [[UInt8]] {
        var out: [[UInt8]] = []
        if let mirror { out.append(RazerCommand.mirror(mirror)) }
        if let noiseReduction3D { out.append(RazerCommand.noiseReduction3D(noiseReduction3D)) }
        if let noiseReduction2D { out.append(RazerCommand.noiseReduction2D(noiseReduction2D)) }
        if let metering { out.append(RazerCommand.metering(metering)) }
        if let exposureCompensation {
            // Face metering only supports -1.0...+3.0 EV.
            let low = metering == .face ? -10 : -30
            out.append(RazerCommand.exposureCompensation(max(exposureCompensation, low)))
        }
        if faceFocus != nil || stylizedLighting != nil {
            out.append(RazerCommand.focus(face: faceFocus ?? false, stylized: stylizedLighting ?? false))
        }
        if let responsiveTracking { out.append(RazerCommand.tracking(responsive: responsiveTracking)) }
        if let lensCorrection { out.append(RazerCommand.lensCorrection(lensCorrection)) }
        if manualExposure {
            out += exposureCommands
        }
        return out
    }

    /// Manual ISO and shutter, for when the camera switches to manual exposure.
    public var exposureCommands: [[UInt8]] {
        var out: [[UInt8]] = []
        if let iso { out.append(RazerCommand.iso(iso)) }
        if let shutterMicroseconds { out.append(RazerCommand.shutter(microseconds: shutterMicroseconds)) }
        return out
    }
}
