import SwiftUI
import LaunchDarkly
import LaunchDarklyObservability
import OpenTelemetryApi

// Custom error type for testing
enum WeatherError: Error, LocalizedError, CaseIterable {
    case networkTimeout
    case serverError
    case dataParsingError
    case invalidCity
    case apiRateLimited
    case authenticationFailed
    case locationPermissionDenied
    
    var errorDescription: String? {
        switch self {
        case .networkTimeout:
            return "Network request timed out"
        case .serverError:
            return "Weather server returned an error"
        case .dataParsingError:
            return "Failed to parse weather data"
        case .invalidCity:
            return "City not found in weather database"
        case .apiRateLimited:
            return "API rate limit exceeded"
        case .authenticationFailed:
            return "API authentication failed"
        case .locationPermissionDenied:
            return "Location permission was denied"
        }
    }
    
    static func random() -> WeatherError {
        allCases.randomElement() ?? .networkTimeout
    }
}

struct Weather {
    var city: String = "San Francisco"
    var region: String = "California"
    var country: String = "USA"
    var timeZoneIdentifier: String = "America/Los_Angeles"
    var condition: String = "Partly Cloudy"
    var conditionCode: Int = 1003
    var isDay: Bool = true
    var temperatureC: Int = 18
    var temperatureF: Int = 64
    var feelsLikeC: Int = 17
    var feelsLikeF: Int = 63
    var humidity: Int = 65
    var windSpeed: Int = 12
    
    /// Returns the current time in the location's timezone, updated in real-time
    var localTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        if let timeZone = TimeZone(identifier: timeZoneIdentifier) {
            formatter.timeZone = timeZone
        }
        return formatter.string(from: Date())
    }
}

// WeatherAPI.com response models
struct WeatherAPIResponse: Codable {
    let location: WeatherLocation
    let current: CurrentWeather
}

struct WeatherLocation: Codable {
    let name: String
    let region: String
    let country: String
    let localtime: String
    let tz_id: String
}

struct CurrentWeather: Codable {
    let temp_c: Double
    let temp_f: Double
    let feelslike_c: Double
    let feelslike_f: Double
    let humidity: Int
    let wind_mph: Double
    let condition: WeatherCondition
    let is_day: Int
}

struct WeatherCondition: Codable {
    let text: String
    let code: Int
}

@MainActor
class WeatherViewModel: ObservableObject {
    @Published var weather = Weather()
    @Published var cityInput: String = ""
    @Published var useFahrenheit: Bool = true
    @Published var useDynamicTheme: Bool = true
    @Published var isLoading: Bool = false
    @Published private var timeRefreshTrigger: Bool = false
    
    /// Access this to force view updates when time refreshes
    var currentLocalTime: String {
        // Reference timeRefreshTrigger to create dependency
        _ = timeRefreshTrigger
        return weather.localTime
    }
    
    let temperatureFlagKey = "use-fahrenheit"
    let themeFlagKey = "use-dynamic-theme"
    
    private var autoRefreshTask: Task<Void, Never>?
    
    /// Returns the current local time for the weather location
    var displayLocalTime: String {
        // This dependency ensures the view updates when timeRefreshTrigger changes
        _ = timeRefreshTrigger
        return weather.localTime
    }
    
    // Weather API key loaded from Secrets.plist
    private var weatherAPIKey: String {
        guard let path = Bundle.main.path(forResource: "Secrets", ofType: "plist"),
              let dict = NSDictionary(contentsOfFile: path),
              let key = dict["WeatherAPIKey"] as? String else {
            return ""
        }
        return key
    }
    
    var displayTemperature: Int {
        useFahrenheit ? weather.temperatureF : weather.temperatureC
    }
    
    var displayFeelsLike: Int {
        useFahrenheit ? weather.feelsLikeF : weather.feelsLikeC
    }
    
    var temperatureUnit: String {
        useFahrenheit ? "F" : "C"
    }
    
    var backgroundColors: [Color] {
        if useDynamicTheme {
            return colorsForCondition(code: weather.conditionCode, isDay: weather.isDay)
        } else {
            return [Color.blue, Color.blue.opacity(0.7)]
        }
    }
    
    private func colorsForCondition(code: Int, isDay: Bool) -> [Color] {
        switch code {
        case 1000: // Sunny/Clear
            return isDay ? [Color.orange, Color.yellow] : [Color.indigo, Color.black]
        case 1003, 1006, 1009: // Partly cloudy, Cloudy, Overcast
            return [Color.blue, Color.cyan]
        case 1030, 1135, 1147: // Mist, Fog
            return [Color.gray, Color.white.opacity(0.7)]
        case 1063, 1150, 1153, 1180, 1183, 1186, 1189, 1192, 1195, 1240, 1243, 1246: // Rain
            return [Color.gray, Color.blue.opacity(0.7)]
        case 1087, 1273, 1276, 1279, 1282: // Thunder
            return [Color.gray, Color.purple.opacity(0.7)]
        case 1066, 1114, 1117, 1210, 1213, 1216, 1219, 1222, 1225, 1255, 1258: // Snow
            return [Color.white, Color.cyan]
        default:
            return [Color.blue, Color.cyan]
        }
    }
    
    var weatherEmoji: String {
        switch weather.conditionCode {
        case 1000:
            return weather.isDay ? "sun.max.fill" : "moon.stars.fill"
        case 1003:
            return weather.isDay ? "cloud.sun.fill" : "cloud.moon.fill"
        case 1006, 1009:
            return "cloud.fill"
        case 1030, 1135, 1147:
            return "cloud.fog.fill"
        case 1063, 1150, 1153, 1180, 1183:
            return "cloud.drizzle.fill"
        case 1186, 1189, 1192, 1195, 1240, 1243, 1246:
            return "cloud.rain.fill"
        case 1087, 1273, 1276, 1279, 1282:
            return "cloud.bolt.fill"
        case 1066, 1114, 1210, 1213, 1216:
            return "cloud.snow.fill"
        case 1117, 1219, 1222, 1225, 1255, 1258:
            return "snowflake"
        default:
            return "cloud.sun.fill"
        }
    }
    
    func initialize() {
        observeFlags()
        loadInitialFlagValues()
        
        // Record app initialization metric
        LDObserve.shared.recordMetric(
            metric: .init(
                name: "app_initialized",
                value: 1,
                attributes: [
                    "streaming_mode": AttributeValue.bool(AppDelegate.isStreamingMode)
                ]
            )
        )
        
        // Fetch weather for default city
        Task {
            await fetchWeather(for: weather.city)
        }
        
        // Start auto-refresh at the top of each minute
        startAutoRefresh()
    }
    
    /// Starts the auto-refresh timer that triggers at the top of each minute
    private func startAutoRefresh() {
        autoRefreshTask?.cancel()
        
        autoRefreshTask = Task {
            print("🕐 Auto-refresh started")
            
            while !Task.isCancelled {
                // Calculate time until the next minute boundary
                let now = Date()
                let calendar = Calendar.current
                
                // Get the start of the next minute
                guard let nextMinute = calendar.nextDate(
                    after: now,
                    matching: DateComponents(second: 0),
                    matchingPolicy: .nextTime
                ) else {
                    print("🕐 Failed to calculate next minute")
                    try? await Task.sleep(for: .seconds(60))
                    continue
                }
                
                let secondsUntilNextMinute = nextMinute.timeIntervalSince(now)
                print("🕐 Waiting \(secondsUntilNextMinute) seconds until next refresh")
                
                // Wait until the top of the next minute
                try? await Task.sleep(for: .seconds(secondsUntilNextMinute))
                
                guard !Task.isCancelled else {
                    print("🕐 Auto-refresh cancelled")
                    break
                }
                
                print("🕐 Refreshing weather for \(weather.city)")
                
                // Toggle to trigger view update for time display
                timeRefreshTrigger.toggle()
                
                // Refresh weather data
                await fetchWeather(for: weather.city)
            }
        }
    }
    
    /// Stops the auto-refresh timer
    func stopAutoRefresh() {
        autoRefreshTask?.cancel()
        autoRefreshTask = nil
    }
    
    private func loadInitialFlagValues() {
        guard let client = LDClient.get() else { return }
        useFahrenheit = client.boolVariation(forKey: temperatureFlagKey, defaultValue: true)
        useDynamicTheme = client.boolVariation(forKey: themeFlagKey, defaultValue: true)
    }
    
    private func observeFlags() {
        guard let client = LDClient.get() else { return }
        
        client.observe(key: temperatureFlagKey, owner: self) { [weak self] changedFlag in
            guard let self = self else { return }
            if case .bool(let value) = changedFlag.newValue {
                Task { @MainActor in
                    self.useFahrenheit = value
                }
            }
        }
        
        client.observe(key: themeFlagKey, owner: self) { [weak self] changedFlag in
            guard let self = self else { return }
            if case .bool(let value) = changedFlag.newValue {
                Task { @MainActor in
                    self.useDynamicTheme = value
                }
            }
        }
    }
    
    func searchCity() {
        guard !cityInput.isEmpty else { return }
        let city = cityInput
        cityInput = ""
        
        // Record metric for city search
        LDObserve.shared.recordMetric(
            metric: .init(
                name: "city_search_count",
                value: 1,
                attributes: [
                    "city": AttributeValue.string(city)
                ]
            )
        )
        
        Task {
            await fetchWeather(for: city)
        }
    }
    
    private func fetchWeather(for city: String) async {
        guard !weatherAPIKey.isEmpty else {
            recordError(WeatherError.authenticationFailed)
            return
        }
        
        isLoading = true
        let startTime = Date()
        
        let encodedCity = city.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? city
        let urlString = "https://api.weatherapi.com/v1/current.json?key=\(weatherAPIKey)&q=\(encodedCity)&aqi=no"
        
        guard let url = URL(string: urlString) else {
            isLoading = false
            recordError(WeatherError.invalidCity)
            return
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            let elapsedMs = Date().timeIntervalSince(startTime) * 1000
            
            // Record API response time metric
            LDObserve.shared.recordMetric(
                metric: .init(
                    name: "weather_api_response_time_ms",
                    value: elapsedMs,
                    attributes: [
                        "city": AttributeValue.string(city)
                    ]
                )
            )
            
            guard let httpResponse = response as? HTTPURLResponse else {
                isLoading = false
                recordError(WeatherError.serverError)
                return
            }
            
            switch httpResponse.statusCode {
            case 200:
                let decoder = JSONDecoder()
                let weatherResponse = try decoder.decode(WeatherAPIResponse.self, from: data)
                updateWeather(from: weatherResponse)
            case 400:
                recordError(WeatherError.invalidCity)
            case 401:
                recordError(WeatherError.authenticationFailed)
            case 429:
                recordError(WeatherError.apiRateLimited)
            default:
                recordError(WeatherError.serverError)
            }
        } catch is DecodingError {
            recordError(WeatherError.dataParsingError)
        } catch {
            if (error as NSError).code == NSURLErrorTimedOut {
                recordError(WeatherError.networkTimeout)
            } else {
                recordError(WeatherError.serverError)
            }
        }
        
        isLoading = false
    }
    
    private func updateWeather(from response: WeatherAPIResponse) {
        weather.city = response.location.name
        weather.region = response.location.region
        weather.country = response.location.country
        weather.timeZoneIdentifier = response.location.tz_id
        weather.condition = response.current.condition.text
        weather.conditionCode = response.current.condition.code
        weather.isDay = response.current.is_day == 1
        weather.temperatureC = Int(response.current.temp_c)
        weather.temperatureF = Int(response.current.temp_f)
        weather.feelsLikeC = Int(response.current.feelslike_c)
        weather.feelsLikeF = Int(response.current.feelslike_f)
        weather.humidity = response.current.humidity
        weather.windSpeed = Int(response.current.wind_mph)
    }
    
    private func recordError(_ error: WeatherError) {
        // Record error count metric
        LDObserve.shared.recordMetric(
            metric: .init(
                name: "weather_error_count",
                value: 1,
                attributes: [
                    "error.type": AttributeValue.string(String(describing: error))
                ]
            )
        )
        
        // Record the error log
        LDObserve.shared.recordLog(
            message: error.localizedDescription,
            severity: .error,
            attributes: [
                "exception.type": AttributeValue.string("WeatherError.\(error)"),
                "exception.message": AttributeValue.string(error.localizedDescription),
                "error.type": AttributeValue.string(String(describing: error)),
                "error.domain": AttributeValue.string("com.launchdarkly.hello-ios-swift"),
                "city": AttributeValue.string(weather.city)
            ]
        )
        print("Weather error: \(error.localizedDescription)")
    }
    
    func recordTestError() {
        let error = WeatherError.random()
        
        // Record test error count metric
        LDObserve.shared.recordMetric(
            metric: .init(
                name: "test_error_count",
                value: 1,
                attributes: [
                    "error.type": AttributeValue.string(String(describing: error))
                ]
            )
        )
        
        // Record the error log
        LDObserve.shared.recordLog(
            message: error.localizedDescription,
            severity: .error,
            attributes: [
                "exception.type": AttributeValue.string("WeatherError.\(error)"),
                "exception.message": AttributeValue.string(error.localizedDescription),
                "error.type": AttributeValue.string(String(describing: error)),
                "error.domain": AttributeValue.string("com.launchdarkly.hello-ios-swift"),
                "city": AttributeValue.string(weather.city)
            ]
        )
        
        print("Random test error recorded: \(error.localizedDescription)")
    }
}
