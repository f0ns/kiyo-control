import Testing
@testable import KiyoKit

/// Byte layouts from USB captures of Synapse with a Kiyo Pro Ultra (cameractrls issue #19).
@Suite struct RazerCommandTests {
    func hex(_ b: [UInt8]) -> String { b.map { String(format: "%02x", $0) }.joined() }

    @Test func mirror() {
        #expect(hex(RazerCommand.mirror(true)) == "c00e030100000000")
        #expect(hex(RazerCommand.mirror(false)) == "c00e030000000000")
    }

    @Test func noiseReduction() {
        #expect(hex(RazerCommand.noiseReduction3D(true)) == "c00e010100000000")
        #expect(hex(RazerCommand.noiseReduction2D(false)) == "c00e020000000000")
    }

    @Test func metering() {
        #expect(hex(RazerCommand.metering(.average)) == "c00e040000000000")
        #expect(hex(RazerCommand.metering(.center)) == "c00e040100000000")
        #expect(hex(RazerCommand.metering(.face)) == "c00e040500000000")
    }

    @Test func exposureCompensationInTenthsOfAStop() {
        #expect(hex(RazerCommand.exposureCompensation(-30)) == "c00e050000000000")
        #expect(hex(RazerCommand.exposureCompensation(0)) == "c00e051e00000000")
        #expect(hex(RazerCommand.exposureCompensation(30)) == "c00e053c00000000")
        #expect(hex(RazerCommand.exposureCompensation(99)) == "c00e053c00000000")  // clamped
    }

    @Test func iso() {
        #expect(hex(RazerCommand.iso(100)) == "c009010100000000")
        #expect(hex(RazerCommand.iso(6400)) == "c009010700000000")
        #expect(RazerCommand.isoSteps == [100, 200, 400, 800, 1600, 3200, 6400])
    }

    @Test func shutterInMicroseconds() {
        #expect(hex(RazerCommand.shutter(microseconds: 500)) == "c00905000001f400")
        #expect(hex(RazerCommand.shutter(microseconds: 100_000)) == "c00905000186a000")
        #expect(hex(RazerCommand.shutter(microseconds: 16_666)) == "c009050000411a00")
    }

    @Test func focusModeAndLightingShareOneCommand() {
        #expect(hex(RazerCommand.focus(face: false, stylized: false)) == "c00a010000000000")
        #expect(hex(RazerCommand.focus(face: true, stylized: false)) == "c00a010100000000")
        #expect(hex(RazerCommand.focus(face: false, stylized: true)) == "c00a010000000001")
    }

    @Test func trackingAndLensCorrection() {
        #expect(hex(RazerCommand.tracking(responsive: true)) == "ff06000000000000")
        #expect(hex(RazerCommand.tracking(responsive: false)) == "ff06010000000000")
        #expect(hex(RazerCommand.lensCorrection(true)) == "ff01010300000000")
        #expect(hex(RazerCommand.lensCorrection(false)) == "ff01000300000000")
    }

    @Test func sendsToExtensionUnitSixSelectorOne() throws {
        let fake = FakeTransport()
        try UVCCamera(transport: fake).send(RazerCommand.mirror(true))
        #expect(fake.setLog == [.init(unit: 6, selector: 1)])
        #expect(fake.current[.init(unit: 6, selector: 1)] == RazerCommand.mirror(true))
    }
}
