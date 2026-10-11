import Testing
@testable import KiyoKit

@Suite struct VideoModeTests {
    // What the Kiyo Pro Ultra reports on macOS: two pixel formats for some sizes, odd frame rates.
    let reported: [VideoMode.Format] = [
        .init(width: 640, height: 360, frameRates: [30.00003000003, 24.00003840006144, 15.000015000015]),
        .init(width: 640, height: 360, frameRates: [60.000240000960005, 30.00003000003]),
        .init(width: 1920, height: 1080, frameRates: [60.000240000960005, 30.00003000003, 5.0]),
        .init(width: 1280, height: 720, frameRates: [60.000240000960005, 30.00003000003]),
    ]

    @Test func listsEachSizeAndRateOnceLargestFirst() {
        #expect(VideoMode.options(reported) == [
            VideoMode(width: 1920, height: 1080, fps: 60), VideoMode(width: 1920, height: 1080, fps: 30),
            VideoMode(width: 1920, height: 1080, fps: 5),
            VideoMode(width: 1280, height: 720, fps: 60), VideoMode(width: 1280, height: 720, fps: 30),
            VideoMode(width: 640, height: 360, fps: 60), VideoMode(width: 640, height: 360, fps: 30),
            VideoMode(width: 640, height: 360, fps: 24), VideoMode(width: 640, height: 360, fps: 15),
        ])
    }

    @Test func defaultIsLargestAt30fps() {
        #expect(VideoMode.preferred(VideoMode.options(reported), saved: nil) == VideoMode(width: 1920, height: 1080, fps: 30))
    }

    @Test func savedChoiceWinsWhenStillOffered() {
        let options = VideoMode.options(reported)
        let saved = VideoMode(width: 1280, height: 720, fps: 60)
        #expect(VideoMode.preferred(options, saved: saved) == saved)
        #expect(VideoMode.preferred(options, saved: VideoMode(width: 3840, height: 2160, fps: 30))
            == VideoMode(width: 1920, height: 1080, fps: 30))
    }

    @Test func labelsLikeSynapse() {
        #expect(VideoMode(width: 1920, height: 1080, fps: 60).label == "1080p 60FPS")
        #expect(VideoMode(width: 3840, height: 2160, fps: 30).label == "4K 30FPS")
    }

    @Test func roundTripsThroughSettingsString() {
        let mode = VideoMode(width: 1280, height: 720, fps: 60)
        #expect(VideoMode(mode.stored) == mode)
        #expect(VideoMode("junk") == nil)
    }
}
