// MARK: - [Fork Customization: Direct AI Provider Voice-to-Text]
// Purpose: Manage settings, credentials, endpoints, and language preferences for Cloud AI Speech-to-Text.

import Combine
import Foundation

enum CloudASRServiceType: String, CaseIterable, Identifiable, Codable {
    case groq = "groq"
    case openai = "openai"
    case custom = "custom"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .groq: return "Groq (Lightning Fast Whisper)"
        case .openai: return "OpenAI Whisper"
        case .custom: return "Custom Endpoint (Self-Hosted / Compatible)"
        }
    }

    var defaultBaseURL: String {
        switch self {
        case .groq: return "https://api.groq.com/openai/v1"
        case .openai: return "https://api.openai.com/v1"
        case .custom: return "http://localhost:8000/v1"
        }
    }

    var defaultModel: String {
        switch self {
        case .groq: return "whisper-large-v3-turbo"
        case .openai: return "whisper-1"
        case .custom: return "whisper-large-v3-turbo"
        }
    }

    var availableModels: [String] {
        switch self {
        case .groq:
            return ["whisper-large-v3-turbo", "whisper-large-v3", "distil-whisper-large-v3-en"]
        case .openai:
            return ["whisper-1"]
        case .custom:
            return ["whisper-large-v3-turbo", "whisper-1", "custom"]
        }
    }
}

extension SettingsStore {
    private enum CloudASRKeys {
        static let serviceType = "CloudASRServiceType"
        static let selectedModel = "CloudASRSelectedModel"
        static let customBaseURL = "CloudASRCustomBaseURL"
        static let customModel = "CloudASRCustomModel"
        static let apiKeyOverride = "CloudASRAPIKeyOverride"
        static let language = "CloudASRLanguage"
    }

    var cloudASRServiceType: CloudASRServiceType {
        get {
            guard let raw = UserDefaults.standard.string(forKey: CloudASRKeys.serviceType),
                  let type = CloudASRServiceType(rawValue: raw)
            else {
                return .groq
            }
            return type
        }
        set {
            objectWillChange.send()
            UserDefaults.standard.set(newValue.rawValue, forKey: CloudASRKeys.serviceType)
        }
    }

    var cloudASRSelectedModel: String {
        get {
            UserDefaults.standard.string(forKey: CloudASRKeys.selectedModel) ?? cloudASRServiceType.defaultModel
        }
        set {
            objectWillChange.send()
            UserDefaults.standard.set(newValue, forKey: CloudASRKeys.selectedModel)
        }
    }

    var cloudASRCustomBaseURL: String {
        get {
            UserDefaults.standard.string(forKey: CloudASRKeys.customBaseURL) ?? "http://localhost:8000/v1"
        }
        set {
            objectWillChange.send()
            UserDefaults.standard.set(newValue, forKey: CloudASRKeys.customBaseURL)
        }
    }

    var cloudASRCustomModel: String {
        get {
            UserDefaults.standard.string(forKey: CloudASRKeys.customModel) ?? "whisper-large-v3-turbo"
        }
        set {
            objectWillChange.send()
            UserDefaults.standard.set(newValue, forKey: CloudASRKeys.customModel)
        }
    }

    var cloudASRAPIKeyOverride: String {
        get {
            UserDefaults.standard.string(forKey: CloudASRKeys.apiKeyOverride) ?? ""
        }
        set {
            objectWillChange.send()
            UserDefaults.standard.set(newValue, forKey: CloudASRKeys.apiKeyOverride)
        }
    }

    /// Language code for cloud transcription. "auto" or empty enables automatic detection on the go.
    var cloudASRLanguage: String {
        get {
            UserDefaults.standard.string(forKey: CloudASRKeys.language) ?? "auto"
        }
        set {
            objectWillChange.send()
            UserDefaults.standard.set(newValue, forKey: CloudASRKeys.language)
        }
    }

    // MARK: - Resolved Values

    var resolvedCloudASRBaseURL: String {
        switch cloudASRServiceType {
        case .groq, .openai:
            return cloudASRServiceType.defaultBaseURL
        case .custom:
            let custom = cloudASRCustomBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)
            return custom.isEmpty ? cloudASRServiceType.defaultBaseURL : custom
        }
    }

    var resolvedCloudASRModel: String {
        switch cloudASRServiceType {
        case .groq, .openai:
            return cloudASRSelectedModel
        case .custom:
            let custom = cloudASRCustomModel.trimmingCharacters(in: .whitespacesAndNewlines)
            return custom.isEmpty ? cloudASRServiceType.defaultModel : custom
        }
    }

    var resolvedCloudASRAPIKey: String {
        let override = cloudASRAPIKeyOverride.trimmingCharacters(in: .whitespacesAndNewlines)
        if !override.isEmpty {
            return override
        }
        // Fall back to key stored for provider in general AI settings
        switch cloudASRServiceType {
        case .groq:
            return getAPIKey(for: "groq") ?? ""
        case .openai:
            return getAPIKey(for: "openai") ?? ""
        case .custom:
            return ""
        }
    }

    var resolvedCloudASRLanguage: String? {
        let lang = cloudASRLanguage.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if lang.isEmpty || lang == "auto" || lang == "any" {
            return nil
        }
        return lang
    }

    var isCloudASRConfigured: Bool {
        switch cloudASRServiceType {
        case .groq, .openai:
            return !resolvedCloudASRAPIKey.isEmpty
        case .custom:
            return !resolvedCloudASRBaseURL.isEmpty
        }
    }
}
// MARK: - [End Fork Customization: Direct AI Provider Voice-to-Text]
