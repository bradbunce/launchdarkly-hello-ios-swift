import UIKit
import LaunchDarkly
import LaunchDarklyObservability
import LaunchDarklySessionReplay
import OpenTelemetryApi
import SwiftUI

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    
    // Shared property to track streaming mode for UI display
    static var isStreamingMode: Bool = true

    // SDK key is loaded from Secrets.plist (not checked into Git)
    private var sdkKey: String {
        guard let path = Bundle.main.path(forResource: "Secrets", ofType: "plist"),
              let dict = NSDictionary(contentsOfFile: path),
              let key = dict["LaunchDarklySDKKey"] as? String else {
            fatalError("Missing Secrets.plist or LaunchDarklySDKKey. See Secrets.example.plist for setup.")
        }
        return key
    }

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        setUpLDClient()
        
        // Create SwiftUI weather view
        let weatherView = WeatherView()
        
        // Create window and set root view controller
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = UIHostingController(rootView: weatherView)
        window?.makeKeyAndVisible()
        
        return true
    }

    private func setUpLDClient() {
        // Set up the evaluation context. This context should appear on your
        // LaunchDarkly contexts dashboard soon after you run the demo.
        var contextBuilder = LDContextBuilder(key: "example-user-key")
        contextBuilder.kind("user")
        contextBuilder.name("Sandy")

        guard case .success(let context) = contextBuilder.build()
        else { return }

        var config = LDConfig(mobileKey: sdkKey, autoEnvAttributes: .enabled)
        
        // Configure Observability for comprehensive tracking
        // Enables: errors, logs, traces, metrics, and session replay
        config.plugins = [
            Observability(
                options: .init(
                    serviceName: "hello-ios-swift",
                    serviceVersion: "1.0.0",
                    resourceAttributes: [
                        "environment": AttributeValue.string("development"),
                        "team": AttributeValue.string("mobile-team")
                    ],
                    isDebug: true
                )
            ),
            SessionReplay(
                options: .init(
                    isEnabled: true,
                    serviceName: "hello-ios-swift",
                    privacy: .init(
                        maskTextInputs: true,
                        maskWebViews: false,
                        maskLabels: false,
                        maskImages: false,
                        maskUIViews: [],
                        ignoreUIViews: [],
                        maskAccessibilityIdentifiers: [],
                        ignoreAccessibilityIdentifiers: [],
                        minimumAlpha: 0.02
                    )
                )
            )
        ]
        
        // Configure streaming mode based on build configuration
        // Set USE_POLLING_MODE=true in Xcode scheme environment variables to use polling instead
        // Default is streaming mode for real-time flag updates
        let usePollingMode = ProcessInfo.processInfo.environment["USE_POLLING_MODE"] == "true"
        
        if usePollingMode {
            // Polling mode: Stable, no mid-session changes
            config.streamingMode = .polling
            config.flagPollingInterval = 86400 // 24 hours
            config.enableBackgroundUpdates = false
            config.maxCachedContexts = 0
            AppDelegate.isStreamingMode = false
            print("Using POLLING mode - restart required for flag updates")
        } else {
            // Streaming mode: Real-time flag updates (default)
            config.streamingMode = .streaming
            config.enableBackgroundUpdates = true
            AppDelegate.isStreamingMode = true
            print("Using STREAMING mode - flags update in real-time")
        }
        
        // Enable debug mode for better logging
        config.isDebugMode = true
        
        LDClient.start(config: config, context: context, startWaitSeconds: 30) { timedOut in
            if timedOut {
                print("⚠️ LaunchDarkly SDK timed out during initialization")
            } else {
                print("✅ LaunchDarkly SDK initialized successfully with Observability")
            }
            
            // Check connection status
            let client = LDClient.get()
            print("🌐 SDK is online: \(client?.isOnline ?? false)")
            
            // Log the actual flag value
            let flagValue = LDClient.get()?.boolVariation(forKey: "sample-feature", defaultValue: false)
            print("🚩 sample-feature flag value: \(flagValue ?? false)")
            
            // Log all flags to see what the SDK received
            if let allFlags = LDClient.get()?.allFlags {
                print("📋 All flags received from LaunchDarkly:")
                for (key, value) in allFlags {
                    print("   - \(key): \(value)")
                }
            }
        }
    }
}
