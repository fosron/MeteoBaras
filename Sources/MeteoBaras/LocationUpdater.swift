import CoreLocation

/// Tries to resolve the user's location and find the nearest weather place.
/// Runs in the background — does not block the app from loading a default place.
class LocationUpdater: NSObject, CLLocationManagerDelegate {
    
    private let manager = CLLocationManager()
    nonisolated(unsafe) private var callback: (@Sendable (Place) -> Void)?
    
    /// Start location resolution. Calls the callback once with the nearest place.
    func start(_ completion: @Sendable @escaping (Place) -> Void) {
        callback = completion
        
        // Set usage description programmatically before requesting authorization.
        // This is needed because SPM doesn't bundle Info.plist.
        if var info = Bundle.main.infoDictionary {
            info["NSLocationWhenInUseUsageDescription"] =
                "MeteoBaras needs your location to show weather for your area."
        }
        
        // Request authorization — if the user grants it, we'll get their location.
        // If denied, we silently keep the default (Vilnius).
        manager.requestWhenInUseAuthorization()
    }
    
    // MARK: - CLLocationManagerDelegate
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            manager.startUpdatingLocation()
        case .denied, .restricted, .notDetermined:
            break // Keep default place
        @unknown default:
            break
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        manager.stopUpdatingLocation()
        
        let latitude = location.coordinate.latitude
        let longitude = location.coordinate.longitude
        let callback = self.callback // Capture before Task
        
        Task {
            do {
                let coordinates = Coordinates(latitude: latitude, longitude: longitude)
                let place = try await WeatherService.shared.findNearestPlace(to: coordinates)
                await MainActor.run { callback?(place) }
            } catch {
                // Keep default place on error
                _ = error
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        _ = error
    }
}
