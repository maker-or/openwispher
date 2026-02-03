//
//  AudioRecorder.swift
//  OpenWispher
//
//  Audio recording engine using AVFoundation.
//

import Foundation
import AVFoundation

/// Handles audio recording with ephemeral storage
@Observable
internal class AudioRecorder: NSObject {
    private var audioRecorder: AVAudioRecorder?
    private var recordingURL: URL?
    
    internal var isRecording = false
    
    /// Start recording audio to a temporary file
    internal func startRecording() throws {
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "openwispher_recording_\(UUID().uuidString).m4a"
        recordingURL = tempDir.appendingPathComponent(fileName)
        
        guard let url = recordingURL else {
            throw RecordingError.invalidURL
        }
        
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 16000.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        audioRecorder = try AVAudioRecorder(url: url, settings: settings)
        audioRecorder?.record()
        isRecording = true
    }
    
    /// Stop recording and return the audio file URL
    internal func stopRecording() -> URL? {
        audioRecorder?.stop()
        isRecording = false
        return recordingURL
    }
    
    /// Delete the temporary recording file
    internal func deleteRecording() {
        guard let url = recordingURL else { return }
        try? FileManager.default.removeItem(at: url)
        recordingURL = nil
    }
    
    /// Get the audio data for the recording
    internal func getRecordingData() -> Data? {
        guard let url = recordingURL else { return nil }
        return try? Data(contentsOf: url)
    }
}

enum RecordingError: Error, LocalizedError {
    case invalidURL
    case recordingFailed
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Failed to create recording URL"
        case .recordingFailed:
            return "Failed to start recording"
        }
    }
}
