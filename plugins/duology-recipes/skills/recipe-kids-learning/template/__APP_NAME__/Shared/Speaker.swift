import AVFoundation
import Observation

/// Reads questions and feedback aloud with the system's speech synthesizer, on the device,
/// for children who can't read yet. One per app, owned by the store, so a fold never cuts
/// a sentence short by rebuilding it.
@Observable
final class Speaker {
    /// The last words the app asked to say. The UI tests read it; nothing else depends on it.
    private(set) var lastRequest = ""

    @ObservationIgnored private let synthesizer = AVSpeechSynthesizer()
    @ObservationIgnored private let isMuted: Bool
    @ObservationIgnored private var sessionIsSet = false

    /// - Parameter isMuted: record what would be said without saying it (UI tests).
    init(isMuted: Bool = false) {
        self.isMuted = isMuted
    }

    /// Says `text`, cutting off anything still being said: a child who taps twice hears it once.
    func say(_ text: String) {
        lastRequest = text
        guard !isMuted else { return }
        setSessionOnce()
        synthesizer.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: AppFacts.speechLanguage)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.85   // a little slower for young listeners
        synthesizer.speak(utterance)
    }

    /// The words are the lesson, so they play with the Ring/Silent switch on silent. Spoken
    /// audio from other apps (a podcast) pauses; music mixes in.
    private func setSessionOnce() {
        guard !sessionIsSet else { return }
        sessionIsSet = true
        try? AVAudioSession.sharedInstance().setCategory(
            .playback, mode: .spokenAudio, options: [.interruptSpokenAudioAndMixWithOthers])
    }
}
