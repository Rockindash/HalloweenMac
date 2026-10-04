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

/// A cat's "mi-aow", made from scratch the way voices are synthesized: a soft, buzzy voice whose
/// pitch rises then falls, shaped by three mouth resonances (formants) that glide from a closed,
/// nasal "m" through "ee" and "a" to a round "ow". Played when the Halloween black cat is clicked.
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
        engine.mainMixerNode.outputVolume = 0.45
        // A few slightly different cats.
        buffers = [(1.0, 0.75), (1.1, 0.68), (0.92, 0.82)].compactMap { makeMeow(pitch: $0.0, duration: $0.1) }
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

    /// One mouth shape: three formant frequencies.
    private struct Vowel { var f1: Float, f2: Float, f3: Float }

    /// A band-pass filter whose center frequency can move while it runs.
    private struct Resonator {
        var b0: Float = 0, b2: Float = 0, a1: Float = 0, a2: Float = 0
        var x1: Float = 0, x2: Float = 0, y1: Float = 0, y2: Float = 0

        mutating func tune(frequency: Float, bandwidth: Float, sampleRate: Float) {
            let w0 = 2 * Float.pi * frequency / sampleRate
            let alpha = sin(w0) / (2 * (frequency / bandwidth))
            let a0 = 1 + alpha
            b0 = alpha / a0
            b2 = -alpha / a0
            a1 = -2 * cos(w0) / a0
            a2 = (1 - alpha) / a0
        }

        mutating func process(_ x: Float) -> Float {
            let y = b0 * x + b2 * x2 - a1 * y1 - a2 * y2
            x2 = x1; x1 = x
            y2 = y1; y1 = y
            return y
        }
    }

    private func makeMeow(pitch: Float, duration: Float) -> AVAudioPCMBuffer? {
        let sampleRate = Float(format.sampleRate)
        let length = AVAudioFrameCount(sampleRate * duration)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: length),
              let samples = buffer.floatChannelData?[0] else { return nil }
        buffer.frameLength = length

        func smooth(_ t: Float) -> Float { let c = min(1, max(0, t)); return c * c * (3 - 2 * c) }
        // Mouth shapes through the meow, at fractions of its length.
        let keys: [(at: Float, vowel: Vowel)] = [
            (0.0, Vowel(f1: 320, f2: 1300, f3: 2600)),   // m
            (0.14, Vowel(f1: 420, f2: 2300, f3: 3100)),  // ee
            (0.45, Vowel(f1: 950, f2: 1550, f3: 2800)),  // a
            (1.0, Vowel(f1: 520, f2: 950, f3: 2500)),    // ow
        ]
        func vowel(at u: Float) -> Vowel {
            for i in 1..<keys.count where u <= keys[i].at {
                let a = keys[i - 1], b = keys[i]
                let t = smooth((u - a.at) / (b.at - a.at))
                return Vowel(f1: a.vowel.f1 + (b.vowel.f1 - a.vowel.f1) * t,
                             f2: a.vowel.f2 + (b.vowel.f2 - a.vowel.f2) * t,
                             f3: a.vowel.f3 + (b.vowel.f3 - a.vowel.f3) * t)
            }
            return keys[keys.count - 1].vowel
        }
        // The pitch: a little rise on "mi", then a long fall on "aow".
        func pitchAt(_ u: Float) -> Float {
            if u < 0.35 { return 470 + 290 * smooth(u / 0.35) }
            return 760 - 330 * smooth((u - 0.35) / 0.65)
        }

        var r1 = Resonator(), r2 = Resonator(), r3 = Resonator()
        var phase: Float = 0
        var drift: Float = 0
        var noise: UInt32 = 12345
        var peak: Float = 0
        for i in 0..<Int(length) {
            let t = Float(i) / sampleRate
            let u = t / duration
            if i % 32 == 0 {
                let v = vowel(at: u)
                r1.tune(frequency: v.f1, bandwidth: 110, sampleRate: sampleRate)
                r2.tune(frequency: v.f2, bandwidth: 160, sampleRate: sampleRate)
                r3.tune(frequency: v.f3, bandwidth: 250, sampleRate: sampleRate)
            }
            // A slow, random wander and a gentle vibrato keep it from sounding like a machine.
            noise = noise &* 1_664_525 &+ 1_013_904_223
            let white = Float(noise >> 8) / Float(1 << 24) * 2 - 1
            drift += (white * 0.002 - drift) * 0.001
            let vibrato = 1 + 0.015 * sin(2 * .pi * 5.5 * t) * smooth((u - 0.2) / 0.3)
            let f0 = pitchAt(u) * pitch * vibrato * (1 + drift)
            phase += f0 / sampleRate
            phase -= floor(phase)
            // A soft, band-limited buzz.
            var source: Float = 0
            var k: Float = 1
            while k * f0 < 7000 {
                source += sin(2 * .pi * k * phase) / pow(k, 1.1)
                k += 1
            }
            source += white * 0.08 // a little breath
            let voiced = r1.process(source) * 1.0 + r2.process(source) * 0.6 + r3.process(source) * 0.25
            // Quiet while the mouth is closed on the "m", opening up, then fading away.
            let open = 0.35 + 0.65 * smooth((u - 0.04) / 0.14)
            let attack = smooth(t / 0.03)
            let release = smooth((duration - t) / 0.22)
            samples[i] = voiced * open * attack * release
            peak = max(peak, abs(samples[i]))
        }
        if peak > 0 {
            for i in 0..<Int(length) { samples[i] *= 0.7 / peak }
        }
        return buffer
    }
}
