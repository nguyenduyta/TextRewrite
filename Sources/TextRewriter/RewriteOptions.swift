import Foundation

struct RewriteOptions {
    var tone:   String? = nil
    var format: String? = nil
    var length: String? = nil

    func buildInstruction() -> String? {
        var parts: [String] = []

        if let tone = tone {
            parts.append("Rewrite in a \(tone.lowercased()) tone.")
        }
        if let format = format {
            switch format {
            case "Email":         parts.append("Format as a professional email.")
            case "Bullet points": parts.append("Format as a bullet point list.")
            case "Blog post":     parts.append("Format as a blog post with a clear structure.")
            default:              parts.append("Format as a clean paragraph.")
            }
        }
        if let length = length {
            switch length {
            case "Short": parts.append("Keep it short and concise.")
            case "Long":  parts.append("Make it detailed and comprehensive.")
            default:      parts.append("Keep a medium length.")
            }
        }

        guard !parts.isEmpty else { return nil }
        return "Fix grammar, spelling, and phrasing. \(parts.joined(separator: " ")) Preserve the original language and meaning. Return only the corrected text with no explanation."
    }
}

func isAIQuestion(_ text: String) -> Bool {
    let lower = text.lowercased()
    let clues = [
        "could you please", "could you share", "could you provide", "please provide",
        "please clarify", "i need more", "got cut off", "seems incomplete",
        "missing context", "what do you mean", "can you provide", "what text",
    ]
    if clues.contains(where: { lower.contains($0) }) { return true }
    return text.components(separatedBy: "?").count - 1 >= 2
}
