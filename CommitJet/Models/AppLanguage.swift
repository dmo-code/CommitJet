import Foundation

enum AppLanguage {
    static func text(_ english: String, _ german: String, language: String) -> String {
        language == "German" ? german : english
    }
}
