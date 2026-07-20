import AppKit

/// Maps meteo.lt condition codes to SF Symbol names and display labels.
enum WeatherConditionIcon {
    
    /// Condition codes per api.meteo.lt's documented values ("Galimos
    /// reikšmės"), covering both the forecast and observation endpoints.
    static func sfSymbol(for conditionCode: String?) -> String {
        guard let code = conditionCode else { return "questionmark.circle" }

        switch code {
        case "clear":
            return "sun.max.fill"
        case "partly-cloudy", "variable-cloudiness", "cloudy-with-sunny-intervals":
            return "cloud.sun.fill"
        case "cloudy":
            return "cloud.fill"
        case "light-rain", "light-rain-at-times":
            return "cloud.drizzle.fill"
        case "rain", "rain-at-times", "rain-showers":
            return "cloud.rain.fill"
        case "heavy-rain":
            return "cloud.heavyrain.fill"
        case "thunder", "isolated-thunderstorms", "thunderstorms":
            return "cloud.bolt.fill"
        case "heavy-rain-with-thunderstorms":
            return "cloud.bolt.rain.fill"
        case "light-sleet", "sleet", "sleet-showers", "sleet-at-times":
            return "cloud.sleet.fill"
        case "freezing-rain", "hail":
            return "cloud.hail.fill"
        case "light-snow", "light-snow-at-times", "snow-at-times", "snow-showers":
            return "cloud.snow.fill"
        case "snow", "heavy-snow":
            return "snowflake"
        case "snowstorm":
            return "wind.snow"
        case "fog":
            return "cloud.fog.fill"
        case "squall":
            return "wind"
        default:
            return "questionmark.circle"
        }
    }
    
    static func label(for conditionCode: String?) -> String {
        guard let code = conditionCode else { return "Unknown" }

        let words = code.split(separator: "-").map { String($0) }
        let formatted = words.enumerated().map { index, word in
            index == 0 ? word.capitalized : word.lowercased()
        }.joined(separator: " ")
        
        return formatted
    }
}
