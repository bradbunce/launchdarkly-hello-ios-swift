//
//  WeatherView.swift
//  hello-ios-swift
//
//  Created by Brad Bunce on 11/21/25.
//  Copyright © 2025 LaunchDarkly. All rights reserved.
//


import SwiftUI
import LaunchDarkly
import LaunchDarklySessionReplay

struct WeatherView: View {
    @StateObject private var viewModel = WeatherViewModel()
    
    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: viewModel.backgroundColors),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 20) {
                    HStack {
                        TextField("Enter city name...", text: $viewModel.cityInput)
                            .textFieldStyle(GlassTextFieldStyle())
                            .ldPrivate() // Mask city input in session replay
                            .onSubmit {
                                viewModel.searchCity()
                            }
                        
                        Button(action: { viewModel.searchCity() }) {
                            if viewModel.isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Image(systemName: "magnifyingglass")
                                    .font(.title2)
                            }
                        }
                        .buttonStyle(GlassButtonStyle())
                        .disabled(viewModel.isLoading)
                    }
                    .padding(.horizontal)
                    
                    VStack(spacing: 5) {
                        Text(viewModel.weather.city)
                            .font(.system(size: 32, weight: .semibold))
                        
                        if !viewModel.weather.region.isEmpty {
                            Text("\(viewModel.weather.country) - \(viewModel.currentLocalTime)")
                                .font(.system(size: 16))
                                .opacity(0.9)
                        }
                    }
                    .padding(.top, 20)
                    
                    Image(systemName: viewModel.weatherEmoji)
                        .font(.system(size: 80))
                        .symbolRenderingMode(.multicolor)
                        .padding(.vertical, 10)
                    
                    HStack(alignment: .top, spacing: 0) {
                        Text("\(viewModel.displayTemperature)")
                            .font(.system(size: 72, weight: .bold))
                        Text(viewModel.temperatureUnit)
                            .font(.system(size: 32))
                            .opacity(0.8)
                            .padding(.top, 8)
                    }
                    
                    Text(viewModel.weather.condition)
                        .font(.system(size: 24))
                        .padding(.bottom, 10)
                    
                    HStack(spacing: 20) {
                        WeatherDetailView(label: "Feels Like", value: "\(viewModel.displayFeelsLike)\(viewModel.temperatureUnit)")
                        WeatherDetailView(label: "Humidity", value: "\(viewModel.weather.humidity)%")
                        WeatherDetailView(label: "Wind", value: "\(viewModel.weather.windSpeed) mph")
                    }
                    .padding(.vertical, 20)
                    
                    VStack(spacing: 8) {
                        HStack(spacing: 4) {
                            Image(systemName: AppDelegate.isStreamingMode ? "antenna.radiowaves.left.and.right" : "arrow.clockwise")
                            Text(AppDelegate.isStreamingMode ? "Streaming Mode" : "Polling Mode")
                        }
                        .font(.system(size: 12, weight: .medium))
                        .padding(.bottom, 4)
                        
                        Text("use-fahrenheit = \(viewModel.useFahrenheit ? "true" : "false") -> \(viewModel.useFahrenheit ? "Fahrenheit" : "Celsius")")
                            .font(.system(size: 14))
                        
                        Text("use-dynamic-theme = \(viewModel.useDynamicTheme ? "true" : "false") -> \(viewModel.useDynamicTheme ? "Dynamic" : "Static") Theme")
                            .font(.system(size: 14))
                    }
                    .padding()
                    .background(Color.white.opacity(0.15))
                    .cornerRadius(10)
                    .padding(.horizontal)
                    
                    Button(action: { viewModel.recordTestError() }) {
                        Text("Record Test Error")
                            .font(.system(size: 16, weight: .medium))
                    }
                    .buttonStyle(GlassButtonStyle())
                    .padding(.bottom, 20)
                }
                .padding(.vertical)
            }
        }
        .foregroundColor(.white)
        .onAppear {
            viewModel.initialize()
        }
    }
}

struct WeatherDetailView: View {
    let label: String
    let value: String
    
    var body: some View {
        VStack(spacing: 5) {
            Text(label)
                .font(.system(size: 14))
                .opacity(0.8)
            Text(value)
                .font(.system(size: 20, weight: .semibold))
        }
    }
}

struct GlassTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(12)
            .background(Color.white.opacity(0.1))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
            )
            .foregroundColor(.white)
    }
}

struct GlassButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color.white.opacity(configuration.isPressed ? 0.3 : 0.2))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
    }
}

#Preview {
    WeatherView()
}