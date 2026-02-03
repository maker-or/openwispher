//
//  TTSAudioPlayer.swift
//  OpenWispher
//
//  Audio playback for text-to-speech output.
//

import AVFoundation

@MainActor
internal final class TTSAudioPlayer: NSObject, AVAudioPlayerDelegate {
    private var audioPlayer: AVAudioPlayer?
    private var playbackCompletion: (() -> Void)?

    internal var isPlaying: Bool {
        audioPlayer?.isPlaying ?? false
    }

    internal func play(audioData: Data, onCompletion: (() -> Void)? = nil) throws {
        playbackCompletion = onCompletion
        audioPlayer = try AVAudioPlayer(data: audioData)
        audioPlayer?.delegate = self
        audioPlayer?.prepareToPlay()
        audioPlayer?.play()
    }

    internal func pause() {
        audioPlayer?.pause()
    }

    internal func resume() {
        audioPlayer?.play()
    }

    internal func stop() {
        audioPlayer?.stop()
        audioPlayer = nil
    }

    internal func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        playbackCompletion?()
        playbackCompletion = nil
    }
}
