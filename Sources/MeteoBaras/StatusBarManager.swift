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
                .foregroundColor: NSColor.labelColor,
                .baselineOffset: -1.5
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
            addCurrentConditions(to: menu, forecast: current, observation: observations)
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
        
        return wrapForMenuItem(stackView, width: 220)
    }

    /// Builds an "[icon] text" row: a plain horizontal stack, centered.
    private func iconTextRow(symbol: String, iconColor: NSColor, text: String, font: NSFont, textColor: NSColor, iconSize: CGFloat, spacing: CGFloat = 6) -> NSView {
        let stack = NSStackView()
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = spacing

        let iconImage = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
        iconImage?.isTemplate = true
        let iconView = NSImageView(image: iconImage ?? NSImage())
        iconView.imageScaling = .scaleProportionallyUpOrDown
        iconView.contentTintColor = iconColor
        iconView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            iconView.widthAnchor.constraint(equalToConstant: iconSize),
            iconView.heightAnchor.constraint(equalToConstant: iconSize)
        ])

        let label = NSTextField(labelWithString: text)
        label.font = font
        label.textColor = textColor
        label.isEditable = false
        label.isBordered = false
        label.drawsBackground = false

        stack.addArrangedSubview(iconView)
        stack.addArrangedSubview(label)

        return stack
    }

    /// Wraps a view for use as an NSMenuItem's custom view, sizing it to its
    /// content's intrinsic height instead of a guessed fixed height (a fixed
    /// guess tends to leave dead space below the content).
    private func wrapForMenuItem(_ view: NSView, width: CGFloat) -> NSView {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(view)
        view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            view.topAnchor.constraint(equalTo: container.topAnchor),
            view.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            view.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            view.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            container.widthAnchor.constraint(equalToConstant: width)
        ])
        // Force layout to settle now, before NSMenu displays the view —
        // otherwise the stack views inside can visibly jump into place on
        // the first frame each time the menu opens.
        container.layoutSubtreeIfNeeded()
        return container
    }

    private func addCurrentConditions(to menu: NSMenu, forecast: ForecastTimestamp, observation: Observation?) {
        let item = NSMenuItem()
        let conditionCode = observation?.conditionCode ?? forecast.conditionCode

        let outerStack = NSStackView()
        outerStack.orientation = .vertical
        outerStack.edgeInsets = NSEdgeInsets(top: 8, left: 12, bottom: 8, right: 12)
        outerStack.spacing = 6
        outerStack.alignment = .centerX

        // Row 1: icon + temperature
        let mainFont = NSFont.systemFont(ofSize: 22, weight: .bold)
        let mainRow = iconTextRow(
            symbol: WeatherConditionIcon.sfSymbol(for: conditionCode),
            iconColor: NSColor.labelColor,
            text: String(format: "%.0f°C", forecast.airTemperature ?? 0),
            font: mainFont,
            textColor: NSColor.labelColor,
            iconSize: 22,
            spacing: 8
        )

        // Row 2: condition + feels-like
        let subRow = NSStackView()
        subRow.orientation = .horizontal
        subRow.spacing = 6
        subRow.alignment = .firstBaseline

        let conditionLabel = NSTextField(labelWithString: WeatherConditionIcon.label(for: conditionCode))
        conditionLabel.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        conditionLabel.textColor = NSColor.labelColor
        conditionLabel.isEditable = false
        conditionLabel.isBordered = false
        conditionLabel.drawsBackground = false

        let feelsLikeValue = observation?.feelsLikeTemperature ?? forecast.feelsLikeTemperature ?? forecast.airTemperature ?? 0
        let feelsLike = NSTextField(labelWithString: "Feels like \(String(format: "%.0f", feelsLikeValue))°C")
        feelsLike.font = NSFont.systemFont(ofSize: 11)
        feelsLike.textColor = NSColor.secondaryLabelColor
        feelsLike.isEditable = false
        feelsLike.isBordered = false
        feelsLike.drawsBackground = false

        subRow.addArrangedSubview(conditionLabel)
        subRow.addArrangedSubview(feelsLike)

        outerStack.addArrangedSubview(mainRow)
        outerStack.addArrangedSubview(subRow)

        // Row 3: rest of the conditions
        let statsRow = NSStackView()
        statsRow.orientation = .horizontal
        statsRow.spacing = 12
        statsRow.alignment = .centerY

        let humidity = observation?.relativeHumidity ?? forecast.relativeHumidity
        let windSpeed = observation?.windSpeed ?? forecast.windSpeed
        let pressure = observation?.seaLevelPressure ?? forecast.seaLevelPressure
        let cloudCover = observation?.cloudCover ?? forecast.cloudCover

        if let humidity {
            statsRow.addArrangedSubview(statChip(symbol: "humidity.fill", text: "\(humidity)%"))
        }
        if let windSpeed {
            statsRow.addArrangedSubview(statChip(symbol: "wind", text: String(format: "%.0f m/s", windSpeed)))
        }
        if let pressure {
            statsRow.addArrangedSubview(statChip(symbol: "gauge.medium", text: String(format: "%.0f hPa", pressure)))
        }
        if let cloudCover {
            statsRow.addArrangedSubview(statChip(symbol: "cloud.fill", text: "\(cloudCover)%"))
        }

        if !statsRow.arrangedSubviews.isEmpty {
            outerStack.addArrangedSubview(statsRow)
        }

        item.view = wrapForMenuItem(outerStack, width: 250)
        menu.addItem(item)
    }

    private func statChip(symbol: String, text: String) -> NSView {
        iconTextRow(
            symbol: symbol,
            iconColor: NSColor.secondaryLabelColor,
            text: text,
            font: NSFont.systemFont(ofSize: 11, weight: .medium),
            textColor: NSColor.labelColor,
            iconSize: 13,
            spacing: 4
        )
    }


    private func addHourlyForecast(to menu: NSMenu, forecasts: [ForecastTimestamp]) {
        let items = Array(forecasts.prefix(8))
        guard !items.isEmpty else { return }

        let gridStack = NSStackView()
        gridStack.orientation = .vertical
        gridStack.edgeInsets = NSEdgeInsets(top: 4, left: 12, bottom: 6, right: 12)
        gridStack.spacing = 8

        for rowStart in stride(from: 0, to: items.count, by: 2) {
            let rowStack = NSStackView()
            rowStack.orientation = .horizontal
            rowStack.spacing = 16
            rowStack.distribution = .fillEqually

            rowStack.addArrangedSubview(hourCardView(forecast: items[rowStart]))
            if rowStart + 1 < items.count {
                rowStack.addArrangedSubview(hourCardView(forecast: items[rowStart + 1]))
            } else {
                rowStack.addArrangedSubview(NSView())
            }

            gridStack.addArrangedSubview(rowStack)
        }

        let item = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        item.view = wrapForMenuItem(gridStack, width: 240)
        menu.addItem(item)
    }

    private func hourCardView(forecast: ForecastTimestamp) -> NSView {
        let stack = NSStackView()
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 6

        let timeLabel = NSTextField(labelWithString: formatTime(forecast.forecastTimeUtc))
        timeLabel.font = NSFont.systemFont(ofSize: 11)
        timeLabel.textColor = NSColor.secondaryLabelColor
        timeLabel.isEditable = false
        timeLabel.isBordered = false
        timeLabel.drawsBackground = false

        let tempRow = iconTextRow(
            symbol: WeatherConditionIcon.sfSymbol(for: forecast.conditionCode),
            iconColor: NSColor.labelColor,
            text: forecast.airTemperature.map { String(format: "%.0f°", $0) } ?? "—",
            font: NSFont.systemFont(ofSize: 12, weight: .medium),
            textColor: NSColor.labelColor,
            iconSize: 16,
            spacing: 4
        )

        stack.addArrangedSubview(timeLabel)
        stack.addArrangedSubview(tempRow)

        return stack
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
