import AVFoundation
import Foundation

enum AudioEngineError: Error {
    case notAuthorized
    case tooShort          // fewer than 8 chunks recorded
    case engineFailed(Error)
}

/// Records from the default microphone using AVAudioEngine.
/// Delivers real-time RMS level updates at ~30fps and saves audio to a temp file
/// for transcription when recording stops.
final class AudioEngine {
    /// Called on the main thread with normalised RMS (0.0–1.0) while recording
    var onLevelUpdate: ((Double) -> Void)?

    private let engine     = AVAudioEngine()
    private var file:      AVAudioFile?
    private var tempURL:   URL?
    private var chunkCount = 0
    private let minChunks  = 8    // ~256 ms at 16kHz / 512 chunk — same threshold as Python
    private var isRunning  = false

    // Target format: 16kHz mono (matches ax_listen.swift and Python)
    private let format = AVAudioFormat(
        commonFormat: .pcmFormatFloat32,
        sampleRate:   16000,
        channels:     1,
        interleaved:  false
    )!

    func startRecording() throws {
        guard !isRunning else { return }
        AVCaptureDevice.requestAccess(for: .audio) { _ in }   // trigger permission prompt

        let inputNode = engine.inputNode
        let inputFmt  = inputNode.outputFormat(forBus: 0)

        // Create temp file for AVAudioFile
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("whisk_\(UUID().uuidString).wav")
        tempURL    = tmp
        chunkCount = 0

        file = try AVAudioFile(forWriting: tmp, settings: format.settings)

        // Install tap on input node, converting to 16kHz mono on the fly
        inputNode.installTap(onBus: 0, bufferSize: 512, format: inputFmt) { [weak self] buf, _ in
            guard let self else { return }
            self.chunkCount += 1

            // Convert to target format and write
            if let converted = self.convert(buf, to: self.format) {
                try? self.file?.write(from: converted)

                // Compute RMS
                let level = self.rms(converted)
                DispatchQueue.main.async { self.onLevelUpdate?(level) }
            }
        }

        try engine.start()
        isRunning = true
    }

    /// Stops recording and returns the temp file URL if enough audio was captured
    func stopRecording() -> URL? {
        guard isRunning else { return nil }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        file = nil
        isRunning = false

        guard chunkCount >= minChunks, let url = tempURL else { return nil }
        return url
    }

    // MARK: - Helpers

    private func rms(_ buf: AVAudioPCMBuffer) -> Double {
        guard let data = buf.floatChannelData?[0] else { return 0 }
        let n = Int(buf.frameLength)
        guard n > 0 else { return 0 }
        var sumSq: Float = 0
        for i in 0..<n { sumSq += data[i] * data[i] }
        let rmsVal = sqrt(sumSq / Float(n))
        return Double(min(1.0, rmsVal / 0.08))   // 0.08 normalisation ≈ Python's 2500/32768
    }

    private func convert(_ buf: AVAudioPCMBuffer,
                          to target: AVAudioFormat) -> AVAudioPCMBuffer? {
        guard let converter = AVAudioConverter(from: buf.format, to: target) else { return nil }
        let ratio        = target.sampleRate / buf.format.sampleRate
        let outFrames    = AVAudioFrameCount(Double(buf.frameLength) * ratio)
        guard let out    = AVAudioPCMBuffer(pcmFormat: target, frameCapacity: outFrames) else { return nil }
        var error: NSError?
        var done = false
        converter.convert(to: out, error: &error) { _, status in
            if done { status.pointee = .noDataNow; return nil }
            status.pointee = .haveData
            done = true
            return buf
        }
        return error == nil ? out : nil
    }
}
