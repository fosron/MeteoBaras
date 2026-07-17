import AppKit

/// Maps meteo.lt condition codes to SF Symbol names and display labels.
enum WeatherConditionIcon {
    
    static func sfSymbol(for conditionCode: String?) -> String {
        guard let code = conditionCode else { return "questionmark.circle" }
        
        switch code {
        case "clear":
            return "sun.max.fill"
        case "mainly-clear":
            return "sun.max.fill"
        case "partly-cloudy":
            return "cloud.sun.fill"
        case "mostly-cloudy":
            return "cloud.sun.fill"
        case "cloudy":
            return "cloud.fill"
        case "cloudy-with-sunny-intervals":
            return "cloud.sun.fill"
        case "fog":
            return "cloud.fog.fill"
        case "drizzle":
            return "cloud.drizzle.fill"
        case "light-drizzle":
            return "cloud.drizzle.fill"
        case "moderate-drizzle":
            return "cloud.drizzle.fill"
        case "dense-drizzle":
            return "cloud.heavyrain.fill"
        case "light-rain":
            return "cloud.rain.fill"
        case "moderate-rain":
            return "cloud.rain.fill"
        case "heavy-rain":
            return "cloud.heavyrain.fill"
        case "violent-rain":
            return "cloud.heavyrain.fill"
        case "rain-showers":
            return "cloud.rain.fill"
        case "sleet":
            return "cloud.sleet.fill"
        case "snow":
            return "cloud.snow.fill"
        case "light-snow":
            return "cloud.snow.fill"
        case "moderate-snow":
            return "cloud.snow.fill"
        case "heavy-snow":
            return "cloud.heavyrain.fill"
        case "snow-showers":
            return "cloud.snow.fill"
        case "rain-and-hail":
            return "cloud.bolt.fill"
        case "thunderstorm":
            return "cloud.bolt.fill"
        case "thunderstorm-with-rain":
            return "cloud.bolt.fill"
        case "thunderstorm-with-hail":
            return "cloud.bolt.fill"
        default:
            return "questionmark.circle"
        }
    }
    
    static func label(for conditionCode: String?) -> String {
        guard let code = conditionCode else { return "Unknown" }
        
        // Return a human-readable label by replacing hyphens with spaces and capitalizing.
        let words = code.split(separator: "-").map { String($0) }
        let formatted = words.enumerated().map { index, word in
            index == 0 ? word.capitalized : word.lowercased()
        }.joined(separator: " ")
        
        return formatted
    }
}
