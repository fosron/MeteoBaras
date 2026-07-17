import AppKit

/// Manages the status bar item and its menu.
@MainActor
class StatusBarManager: NSObject, NSMenuDelegate {
    
    private let statusItem: NSStatusItem
    private let weatherService = WeatherService.shared
    private var currentPlaceCode: String?
    private var currentPlaceName: String = ""
    
    override init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()
        
        // Assign an empty menu so clicking the button shows a menu immediately.
        // macOS auto-shows the assigned menu on click — no manual toggle needed.
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
        
        updateStatusBarText(icon: "questionmark.circle", temperature: nil)
    }
    
    // MARK: - Public
    
    func updateFor(place: Place) {
        currentPlaceCode = place.code
        currentPlaceName = place.name
        Task {
            await updateWeather()
        }
    }
    
    // MARK: - Status Bar
    
    private func updateStatusBarText(icon: String, temperature: Double?) {
        guard let button = statusItem.button else { return }
        
        let nsImage = NSImage(systemSymbolName: icon, accessibilityDescription: "Weather")
        nsImage?.isTemplate = true
        
        button.image = nsImage
        
        if let temp = temperature {
            let tempText = String(format: "%.0f°C", temp)
            button.toolTip = tempText
            let attr = NSMutableAttributedString()
            let tempAttr: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 13, weight: .medium),
                .foregroundColor: NSColor.labelColor
            ]
            attr.append(NSAttributedString(string: tempText, attributes: tempAttr))
            button.attributedTitle = attr
        } else {
            button.title = ""
            button.toolTip = "Loading..."
        }
    }
    
    // MARK: - Menu
    
    func buildMenu(placeName: String, forecasts: [ForecastTimestamp]?, observations: Observation?) {
        let menu = NSMenu()
        menu.delegate = self
        
        // Header
        let headerItem = NSMenuItem()
        headerItem.view = placeHeaderView(placeName: placeName)
        menu.addItem(headerItem)
        
        menu.addItem(.separator())
        
        // Current conditions
        if let forecasts = forecasts, let current = forecasts.first {
            addCurrentWeather(to: menu, forecast: current)
            menu.addItem(.separator())
        }
        
        // Latest observations
        if let obs = observations {
            addObservations(to: menu, observation: obs)
            menu.addItem(.separator())
        }
        
        // Hourly forecast
        if let forecasts = forecasts {
            addHourlyForecast(to: menu, forecasts: forecasts)
            menu.addItem(.separator())
        }
        
        // Refresh
        let refreshItem = NSMenuItem(title: "Refresh", action: #selector(refreshWeather), keyEquivalent: "r")
        refreshItem.target = self
        menu.addItem(refreshItem)
        
        menu.addItem(.separator())
        
        // Quit
        let quitItem = NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate), keyEquivalent: "q")
        menu.addItem(quitItem)
        
        statusItem.menu = menu
    }
    
    // MARK: - Menu Components
    
    private func placeHeaderView(placeName: String) -> NSView {
        let stackView = NSStackView()
        stackView.orientation = .vertical
        stackView.edgeInsets = NSEdgeInsets(top: 8, left: 12, bottom: 8, right: 12)
        stackView.spacing = 2
        
        let label = NSTextField(labelWithString: placeName)
        label.font = NSFont.systemFont(ofSize: 14, weight: .semibold)
        label.isEditable = false
        label.isBordered = false
        label.drawsBackground = false
        label.alignment = .left
        
        let subLabel = NSTextField(labelWithString: "Weather from meteo.lt")
        subLabel.font = NSFont.systemFont(ofSize: 11)
        subLabel.textColor = NSColor.secondaryLabelColor
        subLabel.isEditable = false
        subLabel.isBordered = false
        subLabel.drawsBackground = false
        
        stackView.addArrangedSubview(label)
        stackView.addArrangedSubview(subLabel)
        
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 220, height: 50))
        container.addSubview(stackView)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: container.topAnchor),
            stackView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            stackView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: container.trailingAnchor)
        ])
        
        return container
    }
    
    private func addCurrentWeather(to menu: NSMenu, forecast: ForecastTimestamp) {
        let item = NSMenuItem()
        
        let stackView = NSStackView()
        stackView.orientation = .horizontal
        stackView.edgeInsets = NSEdgeInsets(top: 8, left: 12, bottom: 8, right: 12)
        stackView.spacing = 10
        
        // Icon
        let iconView = NSView(frame: NSRect(x: 0, y: 0, width: 32, height: 32))
        let iconImage = NSImage(systemSymbolName: WeatherConditionIcon.sfSymbol(for: forecast.conditionCode), accessibilityDescription: nil)
        iconImage?.isTemplate = true
        let iconImageView = NSImageView(image: iconImage ?? NSImage())
        iconImageView.imageScaling = .scaleProportionallyUpOrDown
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        iconView.addSubview(iconImageView)
        NSLayoutConstraint.activate([
            iconImageView.centerXAnchor.constraint(equalTo: iconView.centerXAnchor),
            iconImageView.centerYAnchor.constraint(equalTo: iconView.centerYAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 28),
            iconImageView.heightAnchor.constraint(equalToConstant: 28)
        ])
        
        // Temperature
        let tempLabel = NSTextField(labelWithString: String(format: "%.0f°C", forecast.airTemperature ?? 0))
        tempLabel.font = NSFont.systemFont(ofSize: 24, weight: .bold)
        tempLabel.isEditable = false
        tempLabel.isBordered = false
        tempLabel.drawsBackground = false
        
        // Details
        let detailsStack = NSStackView()
        detailsStack.orientation = .vertical
        detailsStack.spacing = 2
        
        let feelsLike = NSTextField(labelWithString: "Feels like \(String(format: "%.0f", forecast.feelsLikeTemperature ?? forecast.airTemperature ?? 0))°C")
        feelsLike.font = NSFont.systemFont(ofSize: 11)
        feelsLike.textColor = NSColor.secondaryLabelColor
        feelsLike.isEditable = false
        feelsLike.isBordered = false
        feelsLike.drawsBackground = false
        
        let conditionLabel = NSTextField(labelWithString: WeatherConditionIcon.label(for: forecast.conditionCode))
        conditionLabel.font = NSFont.systemFont(ofSize: 11)
        conditionLabel.textColor = NSColor.secondaryLabelColor
        conditionLabel.isEditable = false
        conditionLabel.isBordered = false
        conditionLabel.drawsBackground = false
        
        detailsStack.addArrangedSubview(feelsLike)
        detailsStack.addArrangedSubview(conditionLabel)
        
        let rightStack = NSStackView()
        rightStack.orientation = .vertical
        rightStack.alignment = .left
        rightStack.spacing = 4
        rightStack.addArrangedSubview(tempLabel)
        rightStack.addArrangedSubview(detailsStack)
        
        // Spacer
        let spacer = NSView(frame: NSRect(x: 0, y: 0, width: 4, height: 1))
        spacer.setFrameSize(NSSize(width: 4, height: 1))
        spacer.translatesAutoresizingMaskIntoConstraints = false
        spacer.widthAnchor.constraint(equalToConstant: 4).isActive = true
        
        stackView.addArrangedSubview(spacer)
        stackView.addArrangedSubview(iconView)
        stackView.addArrangedSubview(rightStack)
        
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 240, height: 80))
        container.addSubview(stackView)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: container.topAnchor),
            stackView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            stackView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: container.trailingAnchor)
        ])
        
        item.view = container
        menu.addItem(item)
    }
    
    private func addObservations(to menu: NSMenu, observation: Observation) {
        let titleItem = NSMenuItem(title: "Latest Observations", action: nil, keyEquivalent: "")
        titleItem.attributedTitle = NSAttributedString(
            string: "Latest Observations",
            attributes: [
                .font: NSFont.systemFont(ofSize: 12, weight: .semibold),
                .foregroundColor: NSColor.secondaryLabelColor
            ]
        )
        menu.addItem(titleItem)
        
        let details: [(String, String)] = [
            ("Temperature", observation.airTemperature.map { String(format: "%.1f°C", $0) } ?? "—"),
            ("Feels Like", observation.feelsLikeTemperature.map { String(format: "%.1f°C", $0) } ?? "—"),
            ("Humidity", observation.relativeHumidity.map { "\($0)%" } ?? "—"),
            ("Pressure", observation.seaLevelPressure.map { String(format: "%.1f hPa", $0) } ?? "—"),
            ("Wind", observation.windSpeed.map { String(format: "%.1f m/s", $0) } ?? "—"),
            ("Wind Gust", observation.windGust.map { String(format: "%.1f m/s", $0) } ?? "—"),
            ("Cloud Cover", observation.cloudCover.map { "\($0)%" } ?? "—"),
            ("Precipitation", observation.precipitation.map { String(format: "%.1f mm", $0) } ?? "—"),
        ]
        
        for (label, value) in details {
            let item = NSMenuItem(title: "", action: nil, keyEquivalent: "")
            let attr = NSMutableAttributedString()
            
            attr.append(NSAttributedString(
                string: label,
                attributes: [
                    .font: NSFont.systemFont(ofSize: 12),
                    .foregroundColor: NSColor.secondaryLabelColor
                ]
            ))
            attr.append(NSAttributedString(string: "  "))
            attr.append(NSAttributedString(
                string: value,
                attributes: [
                    .font: NSFont.systemFont(ofSize: 12, weight: .medium),
                    .foregroundColor: NSColor.labelColor
                ]
            ))
            
            item.attributedTitle = attr
            menu.addItem(item)
        }
    }
    
    private func addHourlyForecast(to menu: NSMenu, forecasts: [ForecastTimestamp]) {
        let titleItem = NSMenuItem(title: "Hourly Forecast", action: nil, keyEquivalent: "")
        titleItem.attributedTitle = NSAttributedString(
            string: "Hourly Forecast",
            attributes: [
                .font: NSFont.systemFont(ofSize: 12, weight: .semibold),
                .foregroundColor: NSColor.secondaryLabelColor
            ]
        )
        menu.addItem(titleItem)
        
        let items = Array(forecasts.prefix(12))
        
        for forecast in items {
            let item = NSMenuItem(title: "", action: nil, keyEquivalent: "")
            
            let stackView = NSStackView()
            stackView.orientation = .horizontal
            stackView.edgeInsets = NSEdgeInsets(top: 4, left: 12, bottom: 4, right: 12)
            stackView.spacing = 8
            
            let timeLabel = NSTextField(labelWithString: formatTime(forecast.forecastTimeUtc))
            timeLabel.font = NSFont.systemFont(ofSize: 11)
            timeLabel.textColor = NSColor.secondaryLabelColor
            timeLabel.isEditable = false
            timeLabel.isBordered = false
            timeLabel.drawsBackground = false
            timeLabel.frame = NSRect(x: 0, y: 0, width: 50, height: 16)
            
            let iconImage = NSImage(systemSymbolName: WeatherConditionIcon.sfSymbol(for: forecast.conditionCode), accessibilityDescription: nil)
            iconImage?.isTemplate = true
            let iconView = NSImageView(image: iconImage ?? NSImage())
            iconView.imageScaling = .scaleProportionallyUpOrDown
            iconView.frame = NSRect(x: 0, y: 0, width: 18, height: 18)
            
            let tempLabel = NSTextField(labelWithString: forecast.airTemperature.map { String(format: "%.0f°", $0) } ?? "—")
            tempLabel.font = NSFont.systemFont(ofSize: 12, weight: .medium)
            tempLabel.isEditable = false
            tempLabel.isBordered = false
            tempLabel.drawsBackground = false
            tempLabel.frame = NSRect(x: 0, y: 0, width: 40, height: 16)
            
            stackView.addArrangedSubview(timeLabel)
            stackView.addArrangedSubview(iconView)
            stackView.addArrangedSubview(tempLabel)
            
            let container = NSView(frame: NSRect(x: 0, y: 0, width: 240, height: 28))
            container.addSubview(stackView)
            stackView.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                stackView.topAnchor.constraint(equalTo: container.topAnchor),
                stackView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
                stackView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                stackView.trailingAnchor.constraint(equalTo: container.trailingAnchor)
            ])
            
            item.view = container
            menu.addItem(item)
        }
    }
    
    // MARK: - Data Fetching
    
    private func updateWeather() async {
        guard let placeCode = currentPlaceCode else { return }
        
        do {
            let forecast = try await weatherService.fetchForecast(for: placeCode)
            
            updateStatusBarText(
                icon: WeatherConditionIcon.sfSymbol(for: forecast.forecastTimestamps.first?.conditionCode),
                temperature: forecast.forecastTimestamps.first?.airTemperature
            )
            
            var observation: Observation?
            if let obs = try? await fetchObservation(for: placeCode) {
                observation = obs
            }
            
            buildMenu(
                placeName: forecast.place.name,
                forecasts: forecast.forecastTimestamps,
                observations: observation
            )
            
        } catch {
            updateStatusBarText(icon: "exclamationmark.triangle.fill", temperature: nil)
        }
    }
    
    private func fetchObservation(for placeCode: String) async throws -> Observation? {
        let stationMap: [String: String] = [
            "vilnius": "vilniaus-ams",
            "kaunas": "kauno-ams",
            "klaipeda": "klaipedos-ams",
            "siauliai": "siauliu-ams",
            "panevezys": "panevezio-ams",
            "alisus": "alisiaus-ams",
            "marijampole": "marijampoles-ams",
            "telšiai": "telsiu-ams",
            "utena": "utenos-ams",
            "jonava": "jonavos-ams",
        ]
        
        guard let stationCode = stationMap[placeCode] else { return nil }
        let obs = try await weatherService.fetchObservations(for: stationCode)
        return obs.observations.last
    }
    
    @objc private func refreshWeather() {
        Task {
            await updateWeather()
        }
    }
    
    // MARK: - NSMenuDelegate
    
    func menuWillOpen(_ menu: NSMenu) {
        Task {
            await updateWeather()
        }
    }
    
    // MARK: - Time Formatting
    
    private func formatTime(_ utcString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.timeZone = TimeZone(identifier: "UTC")
        
        guard let date = formatter.date(from: utcString) else { return "" }
        
        let localFormatter = DateFormatter()
        localFormatter.dateFormat = "HH:mm"
        localFormatter.timeZone = .current
        
        return localFormatter.string(from: date)
    }
}
