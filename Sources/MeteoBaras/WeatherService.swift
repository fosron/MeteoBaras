import Foundation

/// Fetches weather data from the meteo.lt API.
@MainActor
class WeatherService {
    
    static let shared = WeatherService()
    private let baseURL = "https://api.meteo.lt/v1"
    private let decoder = JSONDecoder()
    
    /// Cached list of all available places.
    private var cachedPlaces: [Place]?
    
    /// Fetches all available places from the API.
    func fetchPlaces() async throws -> [Place] {
        if let cached = cachedPlaces {
            return cached
        }
        let url = URL(string: "\(baseURL)/places")!
        let (data, _) = try await URLSession.shared.data(from: url)
        let places = try decoder.decode([Place].self, from: data)
        cachedPlaces = places
        return places
    }
    
    /// Finds the nearest place to the given coordinates.
    func findNearestPlace(to coordinates: Coordinates) async throws -> Place {
        let places = try await fetchPlaces()
        return places.min(by: {
            $0.coordinates.distance(to: coordinates) <
                $1.coordinates.distance(to: coordinates)
        })!
    }
    
    /// Fetches the long-term forecast for a place.
    func fetchForecast(for placeCode: String) async throws -> ForecastResponse {
        let url = URL(string: "\(baseURL)/places/\(placeCode)/forecasts/long-term")!
        let (data, _) = try await URLSession.shared.data(from: url)
        return try decoder.decode(ForecastResponse.self, from: data)
    }
    
    /// Fetches the latest observations from a station.
    func fetchObservations(for stationCode: String) async throws -> ObservationResponse {
        let url = URL(string: "\(baseURL)/stations/\(stationCode)/observations/latest")!
        let (data, _) = try await URLSession.shared.data(from: url)
        return try decoder.decode(ObservationResponse.self, from: data)
    }
}
