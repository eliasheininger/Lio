import Speech
import AVFoundation

enum SpeechError: Error {
    case notAuthorized
    case noSpeechDetected
    case recognitionFailed(Error)
}

/// Transcribes a recorded audio file using Apple's on-device SFSpeechRecognizer.
/// Ported from ax_listen.swift — replaces Google STT.
final class SpeechEngine {
    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))

    func transcribe(fileURL: URL) async throws -> String {
        // Request permission on first use
        let status = await withCheckedContinuation { cont in
            SFSpeechRecognizer.requestAuthorization { status in cont.resume(returning: status) }
        }
        guard status == .authorized else { throw SpeechError.notAuthorized }
        guard recognizer?.isAvailable == true else { throw SpeechError.notAuthorized }

        let request = SFSpeechURLRecognitionRequest(url: fileURL)
        request.shouldReportPartialResults = false
        request.requiresOnDeviceRecognition = false

        return try await withCheckedThrowingContinuation { cont in
            recognizer?.recognitionTask(with: request) { result, error in
                if let error {
                    cont.resume(throwing: SpeechError.recognitionFailed(error))
                    return
                }
                guard let result, result.isFinal else { return }
                let text = result.bestTranscription.formattedString.trimmingCharacters(in: .whitespaces)
                if text.isEmpty {
                    cont.resume(throwing: SpeechError.noSpeechDetected)
                } else {
                    cont.resume(returning: text)
                }
            }
        }
    }
}
