import Foundation
import AVFoundation

/// Manages iOS audio session so alarm audio can play continuously
/// through the lock screen and while the app is backgrounded.
class AudioSessionManager {
    static let shared = AudioSessionManager()

    private init() {}

    func configurePlaybackSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.duckOthers])
            try session.setActive(true)
        } catch {
            print("Failed to configure AVAudioSession: \(error.localizedDescription)")
        }
    }

    func deactivateSession() {
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            print("Failed to deactivate AVAudioSession: \(error.localizedDescription)")
        }
    }
}
