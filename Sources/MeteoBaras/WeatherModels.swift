import Foundation

// MARK: - Place Models

struct Place: Codable, Identifiable {
    let code: String
    let name: String
    let coordinates: Coordinates
    
    var id: String { code }
}

struct Coordinates: Codable {
    let latitude: Double
    let longitude: Double
}

// MARK: - Forecast Models

struct ForecastResponse: Codable {
    let place: PlaceInfo
    let forecastType: String
    let forecastTimestamps: [ForecastTimestamp]
}

struct PlaceInfo: Codable {
    let code: String
    let name: String
    let administrativeDivision: String?
    let country: String?
    let countryCode: String?
    let coordinates: Coordinates
}

struct ForecastTimestamp: Codable {
    let forecastTimeUtc: String
    let airTemperature: Double?
    let feelsLikeTemperature: Double?
    let windSpeed: Double?
    let windGust: Double?
    let windDirection: Int?
    let cloudCover: Int?
    let seaLevelPressure: Double?
    let relativeHumidity: Int?
    let totalPrecipitation: Double?
    let conditionCode: String?
}

// MARK: - Observation Models

struct ObservationResponse: Codable {
    let station: StationInfo
    let observations: [Observation]
}

struct StationInfo: Codable {
    let code: String
    let name: String
    let coordinates: Coordinates
}

struct Observation: Codable {
    let observationTimeUtc: String
    let airTemperature: Double?
    let feelsLikeTemperature: Double?
    let windSpeed: Double?
    let windGust: Double?
    let windDirection: Int?
    let cloudCover: Int?
    let seaLevelPressure: Double?
    let relativeHumidity: Int?
    let precipitation: Double?
    let snowDepth: Double?
    let conditionCode: String?
}

// MARK: - Utility

extension Coordinates {
    func distance(to other: Coordinates) -> Double {
        let earthRadius: Double = 6371.0
        let lat1 = latitude * .pi / 180
        let lat2 = other.latitude * .pi / 180
        let dLat = (other.latitude - latitude) * .pi / 180
        let dLon = (other.longitude - longitude) * .pi / 180
        
        let a = sin(dLat / 2) * sin(dLat / 2) +
            cos(lat1) * cos(lat2) *
            sin(dLon / 2) * sin(dLon / 2)
        let c = 2 * atan2(sqrt(a), sqrt(1 - a))
        
        return earthRadius * c
    }
}
