import Foundation

enum AIProvider: String, CaseIterable {
    case openai  = "OpenAI (ChatGPT)"
    case gemini  = "Google Gemini"
    case claude  = "Anthropic Claude"
}

class AISettings {
    static let shared = AISettings()
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        migrateKeysToKeychain()
    }

    // Migrate existing UserDefaults keys to Keychain on first run
    private func migrateKeysToKeychain() {
        for key in ["openAIKey", "geminiKey", "claudeKey"] {
            if let val = defaults.string(forKey: key), !val.isEmpty {
                if Keychain.load(key).isEmpty { Keychain.save(key, value: val) }
                defaults.removeObject(forKey: key)
            }
        }
    }

    var provider: AIProvider {
        get { AIProvider(rawValue: defaults.string(forKey: "aiProvider") ?? "") ?? .openai }
        set { defaults.set(newValue.rawValue, forKey: "aiProvider") }
    }
    var openAIKey: String {
        get { Keychain.load("openAIKey") }
        set { Keychain.save("openAIKey", value: newValue) }
    }
    var geminiKey: String {
        get { Keychain.load("geminiKey") }
        set { Keychain.save("geminiKey", value: newValue) }
    }
    var claudeKey: String {
        get { Keychain.load("claudeKey") }
        set { Keychain.save("claudeKey", value: newValue) }
    }
    var defaultTone: String {
        get { defaults.string(forKey: "defaultTone") ?? "" }
        set { defaults.set(newValue, forKey: "defaultTone") }
    }
}

enum AIError: Error, LocalizedError {
    case missingKey(String)
    case apiError(String)
    case badResponse

    var errorDescription: String? {
        switch self {
        case .missingKey(let p): return "Missing API key for \(p). Open Settings to add it."
        case .apiError(let m):   return "API error: \(m)"
        case .badResponse:       return "Unexpected response from AI API"
        }
    }
}

class AIService {
    static let shared = AIService()
    private init() {}

    // MARK: - Prompt

    private func prompt(_ text: String, instruction: String?) -> String {
        let base = instruction ?? "Fix grammar, spelling, and phrasing of the following text. Preserve the original meaning and language (do not translate). Return only the corrected text with no explanation."
        return "\(base)\n\nText:\n\(text)"
    }

    // MARK: - Non-streaming (accumulates chunks)

    func rewrite(_ text: String, instruction: String? = nil) async throws -> String {
        var result = ""
        try await rewriteStreaming(text, instruction: instruction) { chunk in result += chunk }
        return result
    }

    // MARK: - Streaming

    func rewriteStreaming(_ text: String, instruction: String?, onChunk: @escaping (String) async -> Void) async throws {
        let s = AISettings.shared
        switch s.provider {
        case .openai: try await streamOpenAI(text, instruction: instruction, key: s.openAIKey, onChunk: onChunk)
        case .gemini: try await streamGemini(text, instruction: instruction, key: s.geminiKey, onChunk: onChunk)
        case .claude: try await streamClaude(text, instruction: instruction, key: s.claudeKey, onChunk: onChunk)
        }
    }

    // MARK: - Claude

    private func streamClaude(_ text: String, instruction: String?, key: String, onChunk: @escaping (String) async -> Void) async throws {
        guard !key.isEmpty else { throw AIError.missingKey("Anthropic Claude") }
        var req = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        req.httpMethod = "POST"
        req.setValue(key, forHTTPHeaderField: "x-api-key")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        req.httpBody = try JSONSerialization.data(withJSONObject: [
            "model": "claude-haiku-4-5-20251001",
            "max_tokens": 1500,
            "stream": true,
            "messages": [["role": "user", "content": prompt(text, instruction: instruction)]],
        ])
        let (bytes, _) = try await URLSession.shared.bytes(for: req)
        for try await line in bytes.lines {
            guard line.hasPrefix("data: "),
                  let data  = line.dropFirst(6).data(using: .utf8),
                  let obj   = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  (obj["type"] as? String) == "content_block_delta",
                  let delta = obj["delta"] as? [String: Any],
                  let chunk = delta["text"] as? String
            else { continue }
            await onChunk(chunk)
        }
    }

    // MARK: - OpenAI

    private func streamOpenAI(_ text: String, instruction: String?, key: String, onChunk: @escaping (String) async -> Void) async throws {
        guard !key.isEmpty else { throw AIError.missingKey("OpenAI") }
        var req = URLRequest(url: URL(string: "https://api.openai.com/v1/chat/completions")!)
        req.httpMethod = "POST"
        req.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: [
            "model": "gpt-4o-mini",
            "stream": true,
            "messages": [["role": "user", "content": prompt(text, instruction: instruction)]],
            "max_tokens": 1500,
        ])
        let (bytes, _) = try await URLSession.shared.bytes(for: req)
        for try await line in bytes.lines {
            guard line.hasPrefix("data: ") else { continue }
            let json = String(line.dropFirst(6))
            if json == "[DONE]" { break }
            guard let data    = json.data(using: .utf8),
                  let obj     = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let choices = obj["choices"] as? [[String: Any]],
                  let delta   = choices.first?["delta"] as? [String: Any],
                  let chunk   = delta["content"] as? String
            else { continue }
            await onChunk(chunk)
        }
    }

    // MARK: - Gemini

    private func streamGemini(_ text: String, instruction: String?, key: String, onChunk: @escaping (String) async -> Void) async throws {
        guard !key.isEmpty else { throw AIError.missingKey("Google Gemini") }
        let urlStr = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:streamGenerateContent?alt=sse&key=\(key)"
        var req = URLRequest(url: URL(string: urlStr)!)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: [
            "contents": [["parts": [["text": prompt(text, instruction: instruction)]]]],
        ])
        let (bytes, _) = try await URLSession.shared.bytes(for: req)
        for try await line in bytes.lines {
            guard line.hasPrefix("data: "),
                  let data       = line.dropFirst(6).data(using: .utf8),
                  let obj        = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let candidates = obj["candidates"] as? [[String: Any]],
                  let content    = candidates.first?["content"] as? [String: Any],
                  let parts      = content["parts"] as? [[String: Any]],
                  let chunk      = parts.first?["text"] as? String
            else { continue }
            await onChunk(chunk)
        }
    }
}
