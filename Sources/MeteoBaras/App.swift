import Cocoa

@MainActor
class App: NSObject, NSApplicationDelegate {
    
    private let statusBarManager = StatusBarManager()
    private let locationUpdater = LocationUpdater()
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        
        // Load Vilnius immediately as a default so the app works right away.
        // We'll update to the user's real location if we can get it.
        let defaultPlace = Place(
            code: "vilnius",
            name: "Vilnius",
            coordinates: Coordinates(latitude: 54.68705, longitude: 25.28291)
        )
        statusBarManager.updateFor(place: defaultPlace)
        
        // Try to resolve the user's real location in the background.
        // If location permission is granted, we'll switch to the nearest place.
        locationUpdater.start { [weak self] place in
            self?.statusBarManager.updateFor(place: place)
        }
    }
}
