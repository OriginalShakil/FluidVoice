// MARK: - [Fork Customization: Direct AI Provider Voice-to-Text]
// Purpose: Provide direct speech-to-text transcription through cloud AI providers
// (OpenAI, Groq, or custom endpoints) with automatic on-the-go multilingual language detection.

import Foundation

/// Encodes 16kHz mono PCM Float32 audio samples into standard 16-bit PCM WAV data.
enum WAVAudioEncoder {
    static func encode(samples: [Float], sampleRate: Int = 16_000) -> Data {
        let channels: UInt16 = 1
        let bitsPerSample: UInt16 = 16
        let bytesPerSample = Int(bitsPerSample / 8)
        let dataByteCount = samples.count * bytesPerSample
        let byteRate = UInt32(sampleRate * Int(channels) * bytesPerSample)
        let blockAlign = channels * UInt16(bytesPerSample)

        var data = Data()
        data.reserveCapacity(44 + dataByteCount)

        // RIFF header
        data.append(contentsOf: "RIFF".utf8)
        var riffChunkSize = UInt32(36 + dataByteCount).littleEndian
        withUnsafeBytes(of: &riffChunkSize) { data.append(contentsOf: $0) }
        data.append(contentsOf: "WAVE".utf8)

        // fmt subchunk
        data.append(contentsOf: "fmt ".utf8)
        var subchunk1Size = UInt32(16).littleEndian
        withUnsafeBytes(of: &subchunk1Size) { data.append(contentsOf: $0) }
        var audioFormat = UInt16(1).littleEndian // Linear PCM
        withUnsafeBytes(of: &audioFormat) { data.append(contentsOf: $0) }
        var numChannels = channels.littleEndian
        withUnsafeBytes(of: &numChannels) { data.append(contentsOf: $0) }
        var sRate = UInt32(sampleRate).littleEndian
        withUnsafeBytes(of: &sRate) { data.append(contentsOf: $0) }
        var bRate = byteRate.littleEndian
        withUnsafeBytes(of: &bRate) { data.append(contentsOf: $0) }
        var bAlign = blockAlign.littleEndian
        withUnsafeBytes(of: &bAlign) { data.append(contentsOf: $0) }
        var bPerSample = bitsPerSample.littleEndian
        withUnsafeBytes(of: &bPerSample) { data.append(contentsOf: $0) }

        // data subchunk
        data.append(contentsOf: "data".utf8)
        var dataSize = UInt32(dataByteCount).littleEndian
        withUnsafeBytes(of: &dataSize) { data.append(contentsOf: $0) }

        // PCM Samples clamped and scaled to 16-bit signed integer
        for sample in samples {
            let clamped = max(-1.0, min(1.0, sample))
            var scaled = Int16((clamped * Float(Int16.max)).rounded()).littleEndian
            withUnsafeBytes(of: &scaled) { data.append(contentsOf: $0) }
        }

        return data
    }
}

/// Transcription provider that connects directly to cloud AI speech-to-text endpoints
/// such as Groq Whisper, OpenAI Whisper, or self-hosted OpenAI-compatible services.
final class CloudTranscriptionProvider: TranscriptionProvider {
    let name = "Cloud AI (Groq / OpenAI / Custom)"

    private let urlSession: URLSession

    init(urlSession: URLSession = .shared) {
        self.urlSession = urlSession
    }

    var isAvailable: Bool {
        SettingsStore.shared.isCloudASRConfigured
    }

    var isReady: Bool {
        self.isAvailable
    }

    var prefersNativeFileTranscription: Bool {
        true
    }

    var supportsWordTimings: Bool {
        false
    }

    func modelsExistOnDisk() -> Bool {
        // Cloud models require no disk download
        true
    }

    func prepare(progressHandler: ((ModelPreparationProgress) -> Void)?) async throws {
        guard self.isAvailable else {
            let providerType = SettingsStore.shared.cloudASRServiceType.displayName
            throw NSError(
                domain: "CloudTranscriptionProvider",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "API Key for \(providerType) is missing. Please configure it in Settings."]
            )
        }
        progressHandler?(.loading)
    }

    func transcribe(_ samples: [Float]) async throws -> ASRTranscriptionResult {
        try await self.transcribeFinal(samples)
    }

    func transcribeStreaming(_ samples: [Float]) async throws -> ASRTranscriptionResult {
        // Cloud providers do not perform streaming chunks to prevent excessive latency and API cost.
        // Final transcription is performed when the user stops speaking.
        ASRTranscriptionResult(text: "", confidence: 1.0)
    }

    func transcribeFinal(_ samples: [Float]) async throws -> ASRTranscriptionResult {
        let minSamples = 4_000 // 0.25s at 16kHz
        guard samples.count >= minSamples else {
            return ASRTranscriptionResult(text: "", confidence: 1.0)
        }

        let wavData = WAVAudioEncoder.encode(samples: samples, sampleRate: 16_000)
        let text = try await self.executeTranscriptionRequest(
            audioData: wavData,
            fileName: "speech.wav",
            mimeType: "audio/wav"
        )

        return ASRTranscriptionResult(
            text: text,
            confidence: 1.0
        )
    }

    func transcribeFile(at fileURL: URL) async throws -> ASRTranscriptionResult {
        let audioData = try Data(contentsOf: fileURL)
        let fileName = fileURL.lastPathComponent
        let mimeType: String
        let ext = fileURL.pathExtension.lowercased()
        switch ext {
        case "wav": mimeType = "audio/wav"
        case "mp3": mimeType = "audio/mpeg"
        case "m4a": mimeType = "audio/m4a"
        case "ogg": mimeType = "audio/ogg"
        case "flac": mimeType = "audio/flac"
        default: mimeType = "application/octet-stream"
        }

        let text = try await self.executeTranscriptionRequest(
            audioData: audioData,
            fileName: fileName,
            mimeType: mimeType
        )

        return ASRTranscriptionResult(text: text, confidence: 1.0)
    }

    // MARK: - API Execution

    private func executeTranscriptionRequest(
        audioData: Data,
        fileName: String,
        mimeType: String
    ) async throws -> String {
        let settings = SettingsStore.shared
        let baseURLString = settings.resolvedCloudASRBaseURL
        let apiKey = settings.resolvedCloudASRAPIKey
        let model = settings.resolvedCloudASRModel
        let language = settings.resolvedCloudASRLanguage

        guard let endpointURL = self.buildEndpointURL(baseURLString: baseURLString) else {
            throw NSError(
                domain: "CloudTranscriptionProvider",
                code: -2,
                userInfo: [NSLocalizedDescriptionKey: "Invalid API Base URL: \(baseURLString)"]
            )
        }

        var request = URLRequest(url: endpointURL)
        request.httpMethod = "POST"
        request.timeoutInterval = 45.0

        if !apiKey.isEmpty {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }

        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        // Build multipart body
        var body = Data()

        // 1. Model field
        body.append(contentsOf: "--\(boundary)\r\n".utf8)
        body.append(contentsOf: "Content-Disposition: form-data; name=\"model\"\r\n\r\n".utf8)
        body.append(contentsOf: "\(model)\r\n".utf8)

        // 2. Response format
        body.append(contentsOf: "--\(boundary)\r\n".utf8)
        body.append(contentsOf: "Content-Disposition: form-data; name=\"response_format\"\r\n\r\n".utf8)
        body.append(contentsOf: "json\r\n".utf8)

        // 3. Language field (omitted for automatic language detection on the go!)
        if let language, !language.isEmpty, language.lowercased() != "auto" {
            body.append(contentsOf: "--\(boundary)\r\n".utf8)
            body.append(contentsOf: "Content-Disposition: form-data; name=\"language\"\r\n\r\n".utf8)
            body.append(contentsOf: "\(language)\r\n".utf8)
        }

        // 4. File data
        body.append(contentsOf: "--\(boundary)\r\n".utf8)
        body.append(contentsOf: "Content-Disposition: form-data; name=\"file\"; filename=\"\(fileName)\"\r\n".utf8)
        body.append(contentsOf: "Content-Type: \(mimeType)\r\n\r\n".utf8)
        body.append(audioData)
        body.append(contentsOf: "\r\n".utf8)

        // Closing boundary
        body.append(contentsOf: "--\(boundary)--\r\n".utf8)

        request.httpBody = body

        DebugLogger.shared.info(
            "CloudTranscriptionProvider: Sending \(audioData.count) bytes to \(endpointURL.absoluteString) [model=\(model), language=\(language ?? "auto")]",
            source: "CloudASR"
        )

        let (data, response) = try await self.urlSession.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(
                domain: "CloudTranscriptionProvider",
                code: -3,
                userInfo: [NSLocalizedDescriptionKey: "Invalid server response."]
            )
        }

        if httpResponse.statusCode < 200 || httpResponse.statusCode >= 300 {
            let errorText: String
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let errorObj = json["error"] as? [String: Any],
               let message = errorObj["message"] as? String {
                errorText = message
            } else if let rawString = String(data: data, encoding: .utf8), !rawString.isEmpty {
                errorText = rawString
            } else {
                errorText = "HTTP \(httpResponse.statusCode)"
            }
            throw NSError(
                domain: "CloudTranscriptionProvider",
                code: httpResponse.statusCode,
                userInfo: [NSLocalizedDescriptionKey: "AI Provider Error (\(httpResponse.statusCode)): \(errorText)"]
            )
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let text = json["text"] as? String else {
            throw NSError(
                domain: "CloudTranscriptionProvider",
                code: -4,
                userInfo: [NSLocalizedDescriptionKey: "Could not parse transcription text from AI response."]
            )
        }

        let cleanText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        DebugLogger.shared.info(
            "CloudTranscriptionProvider: Received transcript: '\(cleanText)'",
            source: "CloudASR"
        )
        return cleanText
    }

    private func buildEndpointURL(baseURLString: String) -> URL? {
        var trimmed = baseURLString.trimmingCharacters(in: .whitespacesAndNewlines)
        while trimmed.hasSuffix("/") {
            trimmed.removeLast()
        }
        guard !trimmed.isEmpty else { return nil }

        if trimmed.hasSuffix("/audio/transcriptions") {
            return URL(string: trimmed)
        }
        return URL(string: "\(trimmed)/audio/transcriptions")
    }

    /// Validates the API key and endpoint by performing a small test request
    func testConnection() async throws -> String {
        // Generate a 0.5s audio pulse at 16kHz
        let sampleCount = 8_000
        var samples = [Float](repeating: 0.0, count: sampleCount)
        for i in 0..<sampleCount {
            samples[i] = sin(Float(i) * 2.0 * .pi * 440.0 / 16_000.0) * 0.05
        }
        let wav = WAVAudioEncoder.encode(samples: samples, sampleRate: 16_000)
        let result = try await self.executeTranscriptionRequest(
            audioData: wav,
            fileName: "test_probe.wav",
            mimeType: "audio/wav"
        )
        return result.isEmpty ? "Connection successful! (Ready for speech)" : "Connected! (Probe returned: '\(result)')"
    }
}
// MARK: - [End Fork Customization: Direct AI Provider Voice-to-Text]
