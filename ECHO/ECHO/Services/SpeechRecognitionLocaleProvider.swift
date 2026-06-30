import Foundation
import Speech

struct SpeechRecognitionLocaleProvider {
    static func automaticLocale() -> Locale {
        let supportedLocales = SFSpeechRecognizer.supportedLocales()
        let preferredLanguageIdentifiers = Locale.preferredLanguages + fallbackLanguageIdentifiers

        for identifier in preferredLanguageIdentifiers {
            let locale = Locale(identifier: identifier)

            if supportedLocales.contains(where: { $0.identifier == locale.identifier }) {
                return locale
            }

            if let languageCode = locale.language.languageCode?.identifier,
               let languageMatch = supportedLocales.first(where: { supportedLocale in
                   supportedLocale.language.languageCode?.identifier == languageCode
               }) {
                return languageMatch
            }
        }

        return Locale(identifier: "en-US")
    }

    static func automaticDictationLocale() async -> Locale? {
        let preferredLanguageIdentifiers = Locale.preferredLanguages + fallbackLanguageIdentifiers

        for identifier in preferredLanguageIdentifiers {
            let locale = Locale(identifier: identifier)

            if let supportedLocale = await DictationTranscriber.supportedLocale(equivalentTo: locale) {
                return supportedLocale
            }
        }

        return await DictationTranscriber.supportedLocale(equivalentTo: Locale(identifier: "en-US"))
    }

    static func displayName(for locale: Locale) -> String {
        Locale.current.localizedString(forIdentifier: locale.identifier) ?? locale.identifier
    }

    private static var fallbackLanguageIdentifiers: [String] {
        [
            "fr-FR",
            "en-US",
            "en-GB",
            "es-ES",
            "de-DE",
            "it-IT"
        ]
    }
}
