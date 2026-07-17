# MeteoBaras

A macOS menu bar weather app that displays the current temperature in Celsius using data from [meteo.lt](https://api.meteo.lt/).

## Features

- **Menu bar display** - Shows current temperature (°C) with a weather icon in the macOS status bar
- **Detailed weather menu** - Click the icon to see:
  - Current temperature and "feels like" temperature
  - Weather condition with icon
  - Latest station observations (humidity, pressure, wind, cloud cover, precipitation)
  - 12-hour forecast with hourly temperatures and conditions
- **Auto location** - Automatically detects your location and finds the nearest weather place
- **Auto refresh** - Weather data refreshes when you open the menu and every 15 minutes

## Requirements

- macOS 13.0 (Ventura) or later
- Swift 6.0+
- Location access (requested on first launch)

## Building & Running

```bash
swift build
swift run MeteoBaras
```

## Data Source

Weather data is provided by the [Lithuanian Hydrometeorological Service](https://meteo.lt/) (LHMT) through their public API at [api.meteo.lt](https://api.meteo.lt/).

## License

MIT
