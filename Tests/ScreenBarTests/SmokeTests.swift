import Testing
@testable import ScreenBar

@Suite("Smoke")
struct SmokeTests {
    @Test("DeviceMode 能力判定")
    func deviceModeCapabilities() {
        #expect(DeviceMode.screen.canScreen)
        #expect(!DeviceMode.screen.canView)
        #expect(DeviceMode.view.canView)
        #expect(!DeviceMode.view.canScreen)
        #expect(DeviceMode.both.canScreen && DeviceMode.both.canView)
    }
}
