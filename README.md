# LaunchDarkly Weather App Demo - iOS

A SwiftUI weather application demonstrating LaunchDarkly's iOS SDK with feature flags, Observability, and real-time updates.

## Features

- Real-time weather data from WeatherAPI
- Feature flag-controlled temperature units (Fahrenheit/Celsius)
- Dynamic weather-based themes controlled by feature flags
- City search functionality
- LaunchDarkly Observability integration with error tracking
- Configurable streaming or polling mode for flag updates
- SwiftUI-based modern interface

## How It Works

This app demonstrates LaunchDarkly feature flags in a real-world weather application:

1. **Initialization**: The app loads your LaunchDarkly mobile key and connects to WeatherAPI
2. **SDK Connection**: The LaunchDarkly SDK initializes with a user context (user key: "example-user-key", name: "Sandy")
3. **Weather Data**: Fetches current weather for a city (defaults to San Francisco)
4. **Feature Flag #1 - Temperature Units**: 
   - Flag key: "sample-feature"
   - `true` = Display temperature in Fahrenheit
   - `false` = Display temperature in Celsius
5. **Feature Flag #2 - Dynamic Themes**:
   - Flag key: "dynamic-weather-theme"
   - `true` = Background gradient changes based on weather conditions (sunny, rainy, cloudy, etc.)
   - `false` = Static ocean blue gradient theme
6. **Flag Updates**: 
   - **Streaming mode** (default): Toggle flags in LaunchDarkly and watch the app update instantly
   - **Polling mode** (optional): Restart the app to see updated flag values
7. **Observability**: 
   - Network requests, errors, and SDK events captured
   - Test error recording via button tap

## Prerequisites

- macOS with Xcode 14.0 or later
- iOS 14.0 or later (for deployment - required for SwiftUI features)
- A LaunchDarkly account with:
  - A mobile key (client-side ID for iOS)
  - Two boolean feature flags (or use the defaults)
  - Observability enabled (optional but recommended)
- A WeatherAPI account (free tier available at https://www.weatherapi.com/)
  - Optional: App works with mock data if no API key is provided

## Setup Instructions

### 1. Migrate to Swift Package Manager (if coming from CocoaPods)

If you have an existing CocoaPods setup, follow the migration guide in `MIGRATION_TO_SPM.md`.

For a fresh setup, the Swift Package dependencies are:
- LaunchDarkly iOS SDK: `https://github.com/launchdarkly/ios-client-sdk.git` (v9.0+)
- LaunchDarkly Observability: `https://github.com/launchdarkly/swift-launchdarkly-observability.git` (v0.10.0+)

### 2. Configure Secrets

Copy the example secrets file:

```bash
cp hello-ios-swift/Secrets.example.plist hello-ios-swift/Secrets.plist
```

Edit `hello-ios-swift/Secrets.plist` and add your credentials:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>LaunchDarklySDKKey</key>
    <string>YOUR_LAUNCHDARKLY_MOBILE_KEY_HERE</string>
    <key>WeatherAPIKey</key>
    <string>YOUR_WEATHER_API_KEY_HERE</string>
</dict>
</plist>
```

**Note**: `Secrets.plist` is in `.gitignore` and will not be committed to version control.

### 3. Create Feature Flags in LaunchDarkly

Create two boolean feature flags in your LaunchDarkly project:

1. **Temperature Unit Flag**:
   - Key: `sample-feature`
   - `true` = Fahrenheit
   - `false` = Celsius

2. **Dynamic Theme Flag**:
   - Key: `dynamic-weather-theme`
   - `true` = Weather-based gradient themes
   - `false` = Static ocean blue theme

### 4. Add Swift Package Dependencies in Xcode

1. Open `hello-ios-swift.xcodeproj` in Xcode
2. Select the project in the navigator
3. Go to "Package Dependencies" tab
4. Click "+" and add:
   - `https://github.com/launchdarkly/ios-client-sdk.git` (Up to Next Minor: 9.0.0)
   - `https://github.com/launchdarkly/swift-launchdarkly-observability.git` (Up to Next Minor: 0.10.0)

### 5. Configure Flag Update Mode (Optional)

The app supports two modes for flag updates:

**Streaming Mode (Real-time)** - DEFAULT: Flags update instantly without restarting
**Polling Mode (Stable)**: Flags only update on app restart (good for stable demos)

The app uses **streaming mode by default**. To switch to polling mode:
1. In Xcode, go to Product → Scheme → Edit Scheme...
2. Select "Run" on the left
3. Go to "Arguments" tab
4. Under "Environment Variables", click "+"
5. Add: Name: `USE_POLLING_MODE`, Value: `true`
6. Click "Close"

The app displays a badge showing which mode is active (🔄 Streaming or 📊 Polling).

### 6. Build and Run

1. Select your target device or simulator
2. Press `Cmd+R` to build and run
3. You should see weather data for San Francisco

### 7. Test the Application

1. You should see weather data with temperature and weather details
2. Try searching for different cities using the search box
3. Go to your LaunchDarkly dashboard and toggle the feature flags:
   - Toggle temperature unit flag to switch between Fahrenheit and Celsius
   - Toggle dynamic theme flag to switch between weather-based and static themes
4. By default (**streaming mode**), watch the app update in real-time! If you enabled **polling mode**, restart the app to see changes.
5. Tap the "🐛 Record Test Error" button to send a test error to LaunchDarkly Observability
6. Check your LaunchDarkly Observability dashboard to see recorded errors

## Project Structure

```
launchdarkly-hello-ios-swift/
├── hello-ios-swift/
│   ├── AppDelegate.swift           # LaunchDarkly SDK initialization with Observability
│   ├── WeatherView.swift           # Main SwiftUI view
│   ├── WeatherViewModel.swift      # Business logic and flag handling
│   ├── Secrets.plist               # Your credentials (not in git)
│   └── Secrets.example.plist       # Template for credentials
├── hello-ios-swift.xcodeproj/      # Xcode project
└── README.md                       # This file
```

## Technology Stack

- **LaunchDarkly iOS SDK** (v9.0+) - Feature flag management
- **LaunchDarklyObservability** (v0.10.0+) - SDK event tracking and error recording
- **WeatherAPI** - Real-time weather data
- **SwiftUI** - Modern declarative UI framework
- **Swift Package Manager** - Modern dependency management

## Observability Features

This app includes LaunchDarkly's Observability plugin with comprehensive tracking:

- **Error Tracking**: Automatically captures and reports errors (test via the error button)
- **SDK Events**: Monitors flag evaluations and SDK operations
- **Network Recording**: Captures HTTP requests (including WeatherAPI calls)

## Troubleshooting

### "Missing Secrets.plist or LaunchDarklySDKKey"
- Make sure you've created `hello-ios-swift/Secrets.plist` from the example file
- Verify the file contains your LaunchDarkly mobile key

### Weather data not loading or showing mock data
- Verify you've added `WeatherAPIKey` to your `Secrets.plist` file
- Check that your WeatherAPI key is valid at https://www.weatherapi.com/
- The app will fall back to mock data if the API key is missing or invalid

### Flag values not updating
- The app uses polling mode with 24-hour intervals to prevent mid-session updates
- Restart the app to fetch fresh flag values
- Check that your LaunchDarkly mobile key is correct
- Verify the flag keys match exactly (case-sensitive):
  - Temperature flag: `sample-feature`
  - Theme flag: `dynamic-weather-theme`
- Ensure both flags exist in your LaunchDarkly project
- Check Xcode console for connection errors

### Theme not changing
- Make sure you've created the `dynamic-weather-theme` flag in LaunchDarkly
- The theme only changes when this flag is toggled to `true`
- Different weather conditions produce different gradient themes

### Swift Package Manager errors
- Try cleaning the build folder (Shift+Cmd+K)
- Reset package caches: File → Packages → Reset Package Caches
- Delete derived data: `rm -rf ~/Library/Developer/Xcode/DerivedData`
- Restart Xcode

## Learn More

- [LaunchDarkly iOS SDK Documentation](https://docs.launchdarkly.com/sdk/client-side/ios)
- [LaunchDarkly Observability Documentation](https://launchdarkly.com/docs/sdk/observability/ios)
- [WeatherAPI Documentation](https://www.weatherapi.com/docs/)
- [SwiftUI Documentation](https://developer.apple.com/documentation/swiftui/)
- [LaunchDarkly Quickstart Guide](https://app.launchdarkly.com/quickstart#/)

## License

This sample application is provided as-is for demonstration purposes.
