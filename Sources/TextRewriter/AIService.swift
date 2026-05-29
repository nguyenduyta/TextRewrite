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
    }

    var provider: AIProvider {
        get { AIProvider(rawValue: defaults.string(forKey: "aiProvider") ?? "") ?? .openai }
        set { defaults.set(newValue.rawValue, forKey: "aiProvider") }
    }
    var openAIKey: String {
        get { defaults.string(forKey: "openAIKey") ?? "" }
        set { defaults.set(newValue, forKey: "openAIKey") }
    }
    var geminiKey: String {
        get { defaults.string(forKey: "geminiKey") ?? "" }
        set { defaults.set(newValue, forKey: "geminiKey") }
    }
    var claudeKey: String {
        get { defaults.string(forKey: "claudeKey") ?? "" }
        set { defaults.set(newValue, forKey: "claudeKey") }
    }
    // Empty string = no default (plain grammar fix)
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

    func rewrite(_ text: String, instruction: String? = nil) async throws -> String {
        let s = AISettings.shared
        switch s.provider {
        case .openai:  return try await callOpenAI(text, instruction: instruction, key: s.openAIKey)
        case .gemini:  return try await callGemini(text, instruction: instruction, key: s.geminiKey)
        case .claude:  return try await callClaude(text, instruction: instruction, key: s.claudeKey)
        }
    }

    private func prompt(_ text: String, instruction: String?) -> String {
        let base = instruction ?? """
            Fix grammar, spelling, and phrasing of the following text. \
            Preserve the original meaning and language (do not translate). \
            Return only the corrected text with no explanation.
            """
        return "\(base)\n\nText:\n\(text)"
    }

    // MARK: - OpenAI
    private func callOpenAI(_ text: String, instruction: String?, key: String) async throws -> String {
        guard !key.isEmpty else { throw AIError.missingKey("OpenAI") }
        var req = URLRequest(url: URL(string: "https://api.openai.com/v1/chat/completions")!)
        req.httpMethod = "POST"
        req.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: [
            "model": "gpt-4o-mini",
            "messages": [["role": "user", "content": prompt(text, instruction: instruction)]],
            "max_tokens": 1500,
        ])
        let (data, _) = try await URLSession.shared.data(for: req)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        if let err = (json["error"] as? [String: Any])?["message"] as? String { throw AIError.apiError(err) }
        guard let content = ((json["choices"] as? [[String: Any]])?.first?["message"] as? [String: Any])?["content"] as? String
        else { throw AIError.badResponse }
        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Gemini
    private func callGemini(_ text: String, instruction: String?, key: String) async throws -> String {
        guard !key.isEmpty else { throw AIError.missingKey("Google Gemini") }
        let urlStr = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=\(key)"
        var req = URLRequest(url: URL(string: urlStr)!)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: [
            "contents": [["parts": [["text": prompt(text, instruction: instruction)]]]],
        ])
        let (data, _) = try await URLSession.shared.data(for: req)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        if let err = (json["error"] as? [String: Any])?["message"] as? String { throw AIError.apiError(err) }
        guard let result = (((json["candidates"] as? [[String: Any]])?.first?["content"] as? [String: Any])?["parts"] as? [[String: Any]])?.first?["text"] as? String
        else { throw AIError.badResponse }
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Claude
    private func callClaude(_ text: String, instruction: String?, key: String) async throws -> String {
        guard !key.isEmpty else { throw AIError.missingKey("Anthropic Claude") }
        var req = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        req.httpMethod = "POST"
        req.setValue(key, forHTTPHeaderField: "x-api-key")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        req.httpBody = try JSONSerialization.data(withJSONObject: [
            "model": "claude-haiku-4-5-20251001",
            "max_tokens": 1500,
            "messages": [["role": "user", "content": prompt(text, instruction: instruction)]],
        ])
        let (data, _) = try await URLSession.shared.data(for: req)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        if let err = (json["error"] as? [String: Any])?["message"] as? String { throw AIError.apiError(err) }
        guard let content = (json["content"] as? [[String: Any]])?.first?["text"] as? String
        else { throw AIError.badResponse }
        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
