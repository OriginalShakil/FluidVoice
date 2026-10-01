// MARK: - [Fork Customization: Direct AI Provider Voice-to-Text]
// Purpose: SwiftUI UI component for configuring AI Provider Voice-to-Text,
// language detection on the go, API credentials, and connectivity testing.

import SwiftUI

struct CloudASRSettingsCard: View {
    @ObservedObject var settings: SettingsStore
    let theme: AppTheme

    @State private var testingStatus: AIConnectionStatus = .unknown
    @State private var testingMessage: String = ""
    @State private var isShowingLanguagePicker: Bool = false
    @State private var languageSearchText: String = ""

    private let popularLanguages: [(code: String, name: String)] = [
        ("auto", "Auto-Detect (Any Language On The Go)"),
        ("en", "English"),
        ("es", "Spanish"),
        ("fr", "French"),
        ("de", "German"),
        ("it", "Italian"),
        ("pt", "Portuguese"),
        ("zh", "Chinese / Mandarin"),
        ("ja", "Japanese"),
        ("ko", "Korean"),
        ("ar", "Arabic"),
        ("bn", "Bengali"),
        ("hi", "Hindi"),
        ("ru", "Russian"),
        ("nl", "Dutch"),
        ("tr", "Turkish"),
        ("pl", "Polish"),
        ("sv", "Swedish"),
        ("vi", "Vietnamese")
    ]

    private var isActive: Bool {
        settings.selectedSpeechModel == .cloudAI
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header & Status
            HStack(alignment: .center, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.purple.opacity(0.15))
                        .frame(width: 36, height: 36)
                    Image(systemName: "cloud.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(Color.purple)
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Text("Cloud AI Voice-to-Text")
                            .font(theme.typography.sectionTitle)
                            .foregroundStyle(Color(nsColor: .labelColor))

                        Text("Multilingual")
                            .font(.system(size: 10, weight: .bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.purple.opacity(0.2)))
                            .foregroundStyle(Color.purple)

                        if isActive {
                            Text("Active Engine")
                                .font(.system(size: 10, weight: .bold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(Color.fluidGreen.opacity(0.2)))
                                .foregroundStyle(Color.fluidGreen)
                        }
                    }

                    Text("Transcribe voice directly via AI providers (Groq, OpenAI, or Custom) with zero-config language auto-detection.")
                        .font(theme.typography.bodySmall)
                        .foregroundStyle(Color(nsColor: .secondaryLabelColor))
                }

                Spacer()

                Button(action: {
                    if isActive {
                        settings.selectedSpeechModel = .parakeetTDT
                    } else {
                        settings.selectedSpeechModel = .cloudAI
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: isActive ? "checkmark.circle.fill" : "bolt.fill")
                        Text(isActive ? "Active" : "Activate Cloud AI")
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(isActive ? Color.fluidGreen : Color.purple)
                .controlSize(.regular)
            }

            Divider()

            // Provider Selection
            VStack(alignment: .leading, spacing: 8) {
                Text("AI Provider")
                    .font(theme.typography.bodySmallStrong)
                    .foregroundStyle(Color(nsColor: .labelColor))

                Picker("Provider", selection: Binding(
                    get: { settings.cloudASRServiceType },
                    set: { newType in
                        settings.cloudASRServiceType = newType
                        settings.cloudASRSelectedModel = newType.defaultModel
                        testingStatus = .unknown
                    }
                )) {
                    ForEach(CloudASRServiceType.allCases) { type in
                        Text(type.displayName).tag(type)
                    }
                }
                .pickerStyle(.segmented)

                if settings.cloudASRServiceType == .groq {
                    HStack(spacing: 4) {
                        Image(systemName: "sparkles")
                            .foregroundStyle(.orange)
                        Text("Recommended: Groq transcribes audio in ~250ms with Whisper Large v3 Turbo.")
                            .font(.system(size: 11))
                            .foregroundStyle(Color(nsColor: .secondaryLabelColor))
                    }
                }
            }

            // Model Selection
            VStack(alignment: .leading, spacing: 6) {
                Text("Model")
                    .font(theme.typography.bodySmallStrong)
                    .foregroundStyle(Color(nsColor: .labelColor))

                if settings.cloudASRServiceType == .custom {
                    VStack(alignment: .leading, spacing: 6) {
                        TextField("Endpoint Base URL (e.g. http://localhost:8000/v1)", text: $settings.cloudASRCustomBaseURL)
                            .textFieldStyle(.roundedBorder)

                        TextField("Model Name (e.g. whisper-large-v3)", text: $settings.cloudASRCustomModel)
                            .textFieldStyle(.roundedBorder)
                    }
                } else {
                    Picker("Model", selection: $settings.cloudASRSelectedModel) {
                        ForEach(settings.cloudASRServiceType.availableModels, id: \.self) { model in
                            Text(model).tag(model)
                        }
                    }
                    .pickerStyle(.menu)
                }
            }

            // Language Selection ("On The Go")
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Spoken Language")
                        .font(theme.typography.bodySmallStrong)
                        .foregroundStyle(Color(nsColor: .labelColor))

                    Spacer()

                    Text("Auto-detects spoken language seamlessly")
                        .font(.system(size: 11))
                        .foregroundStyle(Color(nsColor: .secondaryLabelColor))
                }

                HStack(spacing: 10) {
                    Menu {
                        ForEach(popularLanguages, id: \.code) { item in
                            Button(action: {
                                settings.cloudASRLanguage = item.code
                            }) {
                                HStack {
                                    Text(item.name)
                                    if settings.cloudASRLanguage == item.code {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "globe")
                                .foregroundStyle(Color.purple)
                            Text(displayLanguageName(for: settings.cloudASRLanguage))
                                .font(theme.typography.bodySmall)
                            Spacer()
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(nsColor: .controlBackgroundColor))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                                )
                        )
                    }
                    .menuStyle(.borderlessButton)
                    .frame(maxWidth: 320)
                }
            }

            // API Key Section
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("API Key")
                        .font(theme.typography.bodySmallStrong)
                        .foregroundStyle(Color(nsColor: .labelColor))

                    Spacer()

                    if !settings.resolvedCloudASRAPIKey.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Color.fluidGreen)
                            Text("Key Ready")
                                .font(.system(size: 11))
                                .foregroundStyle(Color.fluidGreen)
                        }
                    }
                }

                SecureField("Enter \(settings.cloudASRServiceType.displayName) API Key", text: $settings.cloudASRAPIKeyOverride)
                    .textFieldStyle(.roundedBorder)

                if settings.cloudASRAPIKeyOverride.isEmpty && !settings.resolvedCloudASRAPIKey.isEmpty {
                    Text("Using saved API key from AI Settings for \(settings.cloudASRServiceType.rawValue.capitalized).")
                        .font(.system(size: 11))
                        .foregroundStyle(Color(nsColor: .secondaryLabelColor))
                }
            }

            // Test Connection Action
            HStack(spacing: 12) {
                Button(action: {
                    testConnection()
                }) {
                    HStack(spacing: 6) {
                        if testingStatus == .testing {
                            ProgressView()
                                .controlSize(.mini)
                        } else {
                            Image(systemName: "network")
                        }
                        Text("Test AI Transcriber")
                    }
                }
                .disabled(testingStatus == .testing || !settings.isCloudASRConfigured)

                if testingStatus == .success {
                    Label(testingMessage.isEmpty ? "Connected successfully!" : testingMessage, systemImage: "checkmark.circle.fill")
                        .font(theme.typography.bodySmall)
                        .foregroundStyle(Color.fluidGreen)
                } else if testingStatus == .failed {
                    Label(testingMessage.isEmpty ? "Connection failed" : testingMessage, systemImage: "exclamationmark.triangle.fill")
                        .font(theme.typography.bodySmall)
                        .foregroundStyle(.red)
                        .lineLimit(2)
                }

                Spacer()
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(theme.palette.cardBackground.opacity(0.9))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isActive ? Color.purple.opacity(0.4) : theme.palette.cardBorder.opacity(0.3), lineWidth: isActive ? 1.5 : 1)
                )
        )
    }

    private func displayLanguageName(for code: String) -> String {
        if let match = popularLanguages.first(where: { $0.code == code }) {
            return match.name
        }
        if code.lowercased() == "auto" {
            return "Auto-Detect (Any Language On The Go)"
        }
        return "Language: \(code.uppercased())"
    }

    private func testConnection() {
        testingStatus = .testing
        testingMessage = "Testing AI Transcriber..."

        Task {
            let provider = CloudTranscriptionProvider()
            do {
                let msg = try await provider.testConnection()
                await MainActor.run {
                    self.testingStatus = .success
                    self.testingMessage = msg
                }
            } catch {
                await MainActor.run {
                    self.testingStatus = .failed
                    self.testingMessage = error.localizedDescription
                }
            }
        }
    }
}
// MARK: - [End Fork Customization: Direct AI Provider Voice-to-Text]
