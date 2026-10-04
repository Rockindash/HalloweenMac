import AVFoundation

/// A soft, squishy "thump" made from scratch (no audio files needed).
/// The audio engine only runs for a moment after each smash, so it doesn't use battery while idle.
@MainActor
final class SmashSound {
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!
    private var buffers: [AVAudioPCMBuffer] = []
    private var stopWork: DispatchWorkItem?

    init() {
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
        engine.mainMixerNode.outputVolume = 0.45
        buffers = [150, 125, 105].compactMap { makeThump(pitch: $0) }
    }

    func play() {
        guard let buffer = buffers.randomElement() else { return }
        if !engine.isRunning {
            do { try engine.start() } catch { return }
        }
        player.scheduleBuffer(buffer, at: nil, options: [], completionHandler: nil)
        if !player.isPlaying { player.play() }

        stopWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            Task { @MainActor in
                self?.player.stop()
                self?.engine.pause()
            }
        }
        stopWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: work)
    }

    private func makeThump(pitch: Float) -> AVAudioPCMBuffer? {
        let sampleRate = Float(format.sampleRate)
        let length = AVAudioFrameCount(sampleRate * 0.35)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: length),
              let samples = buffer.floatChannelData?[0] else { return nil }
        buffer.frameLength = length

        var phase: Float = 0
        var lowpass: Float = 0
        for i in 0..<Int(length) {
            let t = Float(i) / sampleRate
            // A low "bonk" that drops in pitch...
            let frequency = pitch * (1 - 0.5 * min(t / 0.12, 1))
            phase += 2 * .pi * frequency / sampleRate
            let thump = sin(phase) * exp(-t * 16)
            // ...plus a muffled squish.
            lowpass += 0.08 * (Float.random(in: -1...1) - lowpass)
            let squish = lowpass * exp(-t * 22) * 2.5
            // Short fade-in avoids a click.
            let attack = min(1, t / 0.004)
            samples[i] = (thump * 0.6 + squish * 0.5) * 0.5 * attack
        }
        return buffer
    }
}

/// A cat's "mi-aow", made from scratch: the pitch rises then falls, and the vowel goes from a
/// bright "ee" to a round "ow". Played when the Halloween black cat is clicked.
@MainActor
final class MeowSound {
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!
    private var buffers: [AVAudioPCMBuffer] = []
    private var stopWork: DispatchWorkItem?

    init() {
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
        engine.mainMixerNode.outputVolume = 0.4
        buffers = [1.0, 1.12, 0.9].compactMap { makeMeow(pitch: $0) }
    }

    func play() {
        guard let buffer = buffers.randomElement() else { return }
        if !engine.isRunning {
            do { try engine.start() } catch { return }
        }
        player.scheduleBuffer(buffer, at: nil, options: [.interrupts], completionHandler: nil)
        if !player.isPlaying { player.play() }
        stopWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            Task { @MainActor in
                self?.player.stop()
                self?.engine.pause()
            }
        }
        stopWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: work)
    }

    private func makeMeow(pitch: Float) -> AVAudioPCMBuffer? {
        let sampleRate = Float(format.sampleRate)
        let duration: Float = 0.6
        let length = AVAudioFrameCount(sampleRate * duration)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: length),
              let samples = buffer.floatChannelData?[0] else { return nil }
        buffer.frameLength = length

        var phase: Float = 0
        var peak: Float = 0
        for i in 0..<Int(length) {
            let t = Float(i) / sampleRate
            let u = t / duration
            // "mi-" rises, "-aow" falls away.
            let glide: Float = u < 0.3 ? 560 + 300 * sin(u / 0.3 * .pi / 2) : 860 - 400 * sin((u - 0.3) / 0.7 * .pi / 2)
            let vibrato = 1 + 0.02 * sin(2 * .pi * 6 * t)
            phase += 2 * .pi * glide * pitch * vibrato / sampleRate
            // Bright at the start, rounder at the end: higher harmonics fade as it goes.
            let brightness = 1 - 0.7 * u
            var sample: Float = 0
            for k in 1...8 {
                let weight = exp(-Float(k - 1) * (1.2 - brightness)) / Float(k)
                sample += weight * sin(Float(k) * phase)
            }
            let attack = min(1, t / 0.05)
            let release = min(1, (duration - t) / 0.18)
            samples[i] = sample * attack * release
            peak = max(peak, abs(samples[i]))
        }
        if peak > 0 {
            for i in 0..<Int(length) { samples[i] *= 0.6 / peak }
        }
        return buffer
    }
}
