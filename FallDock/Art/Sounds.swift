import AVFoundation

/// The app's little sounds, all made from scratch (no audio files needed): a squishy smash,
/// a pop when something grows, a rustle of leaves, a bounce, a chime and a whoosh of wind.
/// The audio engine only runs for a moment after each sound, so it doesn't use battery while idle.
@MainActor
final class Sounds {
    enum Sound: CaseIterable {
        case smash, pop, rustle, bounce, chime, whoosh
    }

    private let engine = AVAudioEngine()
    /// A few players, so sounds can overlap instead of queueing up.
    private var players: [AVAudioPlayerNode] = []
    private var nextPlayer = 0
    private let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!
    private var buffers: [Sound: [AVAudioPCMBuffer]] = [:]
    private var lastPlayed: [Sound: TimeInterval] = [:]
    private var stopWork: DispatchWorkItem?

    init() {
        for _ in 0..<4 {
            let player = AVAudioPlayerNode()
            engine.attach(player)
            engine.connect(player, to: engine.mainMixerNode, format: format)
            players.append(player)
        }
        engine.mainMixerNode.outputVolume = 0.45
        buffers[.smash] = [150, 125, 105].compactMap { pitch in make(0.35) { t, noise in Self.thump(t, pitch: pitch, noise: &noise) } }
        buffers[.pop] = [520, 600, 680].compactMap { pitch in make(0.12) { t, _ in Self.pop(t, pitch: pitch) } }
        buffers[.rustle] = [0, 1].compactMap { _ in make(0.45) { t, noise in Self.rustle(t, noise: &noise) } }
        buffers[.bounce] = [180, 210].compactMap { pitch in make(0.28) { t, _ in Self.boing(t, pitch: pitch) } }
        buffers[.chime] = [make(1.2) { t, _ in Self.chime(t) }].compactMap { $0 }
        buffers[.whoosh] = [make(1.6) { t, noise in Self.whoosh(t, noise: &noise) }].compactMap { $0 }
    }

    /// Plays a sound (if sounds are on). The same sound plays at most every 60 ms, so a burst of
    /// things growing at once doesn't turn into a racket.
    func play(_ sound: Sound, volume: Float = 1) {
        guard Settings.sound, let buffer = buffers[sound]?.randomElement() else { return }
        let now = ProcessInfo.processInfo.systemUptime
        if let last = lastPlayed[sound], now - last < 0.06 { return }
        lastPlayed[sound] = now
        if !engine.isRunning {
            do { try engine.start() } catch { return }
        }
        let player = players[nextPlayer]
        nextPlayer = (nextPlayer + 1) % players.count
        player.volume = volume
        player.scheduleBuffer(buffer, at: nil, options: [.interrupts], completionHandler: nil)
        if !player.isPlaying { player.play() }

        stopWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            Task { @MainActor in
                self?.players.forEach { $0.stop() }
                self?.engine.pause()
            }
        }
        stopWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 2, execute: work)
    }

    // MARK: Making the sounds

    /// Fills a buffer `seconds` long from `sample(t, noiseState)`, with a short fade-in to avoid a click.
    private func make(_ seconds: Float, _ sample: (Float, inout Float) -> Float) -> AVAudioPCMBuffer? {
        let sampleRate = Float(format.sampleRate)
        let length = AVAudioFrameCount(sampleRate * seconds)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: length),
              let samples = buffer.floatChannelData?[0] else { return nil }
        buffer.frameLength = length
        var noise: Float = 0
        for i in 0..<Int(length) {
            let t = Float(i) / sampleRate
            let attack = min(1, t / 0.004)
            let release = min(1, (seconds - t) / 0.01)
            samples[i] = sample(t, &noise) * attack * max(0, release)
        }
        return buffer
    }

    private static func tone(_ t: Float, _ frequency: Float) -> Float { sin(2 * .pi * frequency * t) }

    /// A low "bonk" that drops in pitch, plus a muffled squish.
    private static func thump(_ t: Float, pitch: Float, noise: inout Float) -> Float {
        // The pitch falls to half over the first 0.12 s; this is the phase that gives.
        let cycles = t < 0.12 ? pitch * (t - t * t / 0.48) : pitch * (0.09 + 0.5 * (t - 0.12))
        let thump = sin(2 * .pi * cycles) * exp(-t * 16)
        noise += 0.08 * (Float.random(in: -1...1) - noise)
        return (thump * 0.6 + noise * exp(-t * 22) * 2.5 * 0.5) * 0.5
    }

    /// A bright little blip that rises in pitch.
    private static func pop(_ t: Float, pitch: Float) -> Float {
        let phase = 2 * .pi * (pitch * t + pitch * 4 * t * t)
        return sin(phase) * exp(-t * 38) * 0.35
    }

    /// Dry leaves: crackly noise in uneven bursts.
    private static func rustle(_ t: Float, noise: inout Float) -> Float {
        noise += 0.35 * (Float.random(in: -1...1) - noise)
        let crackle: Float = Float.random(in: 0...1) < 0.02 ? Float.random(in: 0.5...1) : 0.25
        let envelope = sin(.pi * min(1, t / 0.45)) * (0.6 + 0.4 * sin(t * 70))
        return noise * crackle * envelope * 0.9
    }

    /// A soft rubbery bounce.
    private static func boing(_ t: Float, pitch: Float) -> Float {
        let wobble = 1 + 0.15 * sin(t * 2 * .pi * 18) * exp(-t * 8)
        return tone(t, pitch * wobble * (1 + t)) * exp(-t * 14) * 0.4
    }

    /// Two bell notes, a fifth apart.
    private static func chime(_ t: Float) -> Float {
        let first = (tone(t, 1319) + 0.4 * tone(t, 2638)) * exp(-t * 4)
        let second = t > 0.12 ? (tone(t, 1976) + 0.3 * tone(t, 3952)) * exp(-(t - 0.12) * 3.5) : 0
        return (first + second) * 0.12
    }

    /// Wind: noise that swells and fades, its brightness drifting.
    private static func whoosh(_ t: Float, noise: inout Float) -> Float {
        let brightness = 0.03 + 0.05 * sin(.pi * t / 1.6)
        noise += brightness * (Float.random(in: -1...1) - noise)
        return noise * sin(.pi * t / 1.6) * 3.2
    }
}
