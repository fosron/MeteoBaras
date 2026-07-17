import Cocoa

@MainActor
class App: NSObject, NSApplicationDelegate {

    private let statusBarManager = StatusBarManager()
    private let locationUpdater = LocationUpdater()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        // Show Vilnius immediately so the status bar isn't empty while we
        // wait on the location permission prompt / a location fix.
        let vilnius = Place(
            code: "vilnius",
            name: "Vilnius",
            coordinates: Coordinates(latitude: 54.68705, longitude: 25.28291)
        )
        statusBarManager.updateFor(place: vilnius)

        locationUpdater.start { [weak statusBarManager] place in
            Task { @MainActor in
                statusBarManager?.updateFor(place: place)
            }
        }
    }
}
