import Testing
@testable import KiyoKit

@Suite struct FieldOfViewTests {
    @Test func matchesSynapseReadingAtTwoTimesZoom() {
        #expect(FieldOfView.degrees(zoom: 200).rounded() == 44)
    }

    @Test func fullWidthAtNoZoom() {
        #expect(FieldOfView.degrees(zoom: 100).rounded() == 78)
    }

    @Test func narrowsWithZoom() {
        #expect(FieldOfView.degrees(zoom: 400) < FieldOfView.degrees(zoom: 140))
    }

    @Test func presetsSetZoom() {
        #expect(FieldOfView.Preset.wide.zoom == 100)
        #expect(FieldOfView.Preset.medium.zoom == 140)
        #expect(FieldOfView.Preset.narrow.zoom == 200)
    }

    @Test func presetIsRecognisedOnlyAtItsExactZoom() {
        #expect(FieldOfView.Preset(zoom: 140) == .medium)
        #expect(FieldOfView.Preset(zoom: 150) == nil)
    }
}
