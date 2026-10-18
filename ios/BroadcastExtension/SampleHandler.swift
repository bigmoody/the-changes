// Hearing what another app is playing. Builds being worked on only.
//
// iOS keeps each app's sound to itself. The one way round it is a
// broadcast: the person starts it, the red recording indicator stays on
// while it runs, and the system hands this extension every frame of the
// screen and every buffer of sound the phone is playing. It is how
// streaming apps send a game to the internet, and here it is used to
// find out whether a record playing in YouTube or Spotify can reach the
// app cleanly enough to be followed.
//
// It only says what arrives: the format, how loud each buffer is, and
// how steadily they come. The app reads that from the App Group they
// share, a small file written a few times a second. It also keeps the
// last twenty seconds as a WAV beside it, so what it heard can be taken
// off the phone and run through a beat tracker on a computer.
//
// Apple Music plays nothing here, and neither does anything else whose
// sound is protected: a screen recording is given silence for it.
//
// An extension like this is reported to be stopped by the system at
// about 50 MB, so nothing is kept but the one ring of sound and a few
// numbers. The video frames are passed over without being looked at.

import AudioToolbox
import CoreMedia
import QuartzCore
import ReplayKit

/// Where the extension and the app meet.
let theGroup = "group.com.yaseminbridges.playAlong"

class SampleHandler: RPBroadcastSampleHandler {
  /// How much sound is kept for taking off the phone.
  private static let keptSeconds = 20.0

  /// How often the numbers are written for the app to read.
  private static let reportEvery = 0.1

  /// How often the kept sound is written out, so a broadcast the system
  /// ends without saying so still leaves most of it behind.
  private static let keepEvery = 5.0

  private let folder = FileManager.default.containerURL(
    forSecurityApplicationGroupIdentifier: theGroup
  )

  /// One at a time, off the thread the sound arrives on.
  private let writer = DispatchQueue(label: "the_changes.broadcast.writer")

  private var format = "Nothing yet"
  private var sampleRate = 0.0
  private var channels = 0
  private var framesPerBuffer = 0

  private var buffers = 0
  private var silentBuffers = 0
  private var frames = 0
  private var level = 0.0
  private var peak = 0.0

  /// When the first buffer came, and the last, by the phone's clock.
  private var firstArrival: CFTimeInterval?
  private var lastArrival: CFTimeInterval?

  /// The longest wait between two buffers.
  private var longestGap = 0.0

  /// Where the next buffer should start by the buffers' own clock, and
  /// how many did not: a jump is sound skipped or repeated.
  private var expectedTime: CMTime?
  private var jumps = 0

  private var lastReport = 0.0
  private var lastKeep = 0.0

  /// The last stretch of sound, mixed to one channel, oldest overwritten.
  private var ring = [Int16]()
  private var ringAt = 0
  private var ringFull = false

  override func broadcastStarted(withSetupInfo setupInfo: [String: NSObject]?) {
    report(state: "started")
  }

  override func broadcastPaused() {
    report(state: "paused")
    keep()
  }

  override func broadcastResumed() {
    report(state: "started")
  }

  override func broadcastFinished() {
    report(state: "finished")
    keep()
    // Waited for, or the extension is gone before the file is.
    writer.sync {}
  }

  override func processSampleBuffer(
    _ sampleBuffer: CMSampleBuffer,
    with sampleBufferType: RPSampleBufferType
  ) {
    // The microphone is off in the picker and the screen is not wanted:
    // only the sound the phone is playing.
    guard sampleBufferType == .audioApp else { return }
    let now = CACurrentMediaTime()
    if let lastArrival {
      longestGap = max(longestGap, now - lastArrival)
    }
    if firstArrival == nil { firstArrival = now }
    lastArrival = now

    guard
      let description = CMSampleBufferGetFormatDescription(sampleBuffer),
      let basic = CMAudioFormatDescriptionGetStreamBasicDescription(description)?
        .pointee
    else { return }
    let count = CMSampleBufferGetNumSamples(sampleBuffer)
    describe(basic, frames: count)
    buffers += 1
    frames += count

    let start = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
    if let expectedTime, start.isValid,
      abs(CMTimeGetSeconds(CMTimeSubtract(start, expectedTime))) > 0.005
    {
      jumps += 1
    }
    if start.isValid, basic.mSampleRate > 0 {
      expectedTime = CMTimeAdd(
        start,
        CMTime(value: CMTimeValue(count), timescale: CMTimeScale(basic.mSampleRate))
      )
    }

    measure(sampleBuffer, basic: basic, frames: count)

    if now - lastReport >= SampleHandler.reportEvery {
      lastReport = now
      report(state: "started")
    }
    if now - lastKeep >= SampleHandler.keepEvery {
      lastKeep = now
      keep()
    }
  }

  /// The format said in words, and the ring made to fit it.
  private func describe(_ basic: AudioStreamBasicDescription, frames: Int) {
    framesPerBuffer = frames
    guard basic.mSampleRate != sampleRate || Int(basic.mChannelsPerFrame) != channels
    else { return }
    sampleRate = basic.mSampleRate
    channels = Int(basic.mChannelsPerFrame)
    let flags = basic.mFormatFlags
    let float = flags & kAudioFormatFlagIsFloat != 0
    let kind = float
      ? "float"
      : (flags & kAudioFormatFlagIsSignedInteger != 0 ? "signed integer" : "unsigned integer")
    let order = flags & kAudioFormatFlagIsBigEndian != 0 ? "big endian" : "little endian"
    let layout = flags & kAudioFormatFlagIsNonInterleaved != 0 ? "non-interleaved" : "interleaved"
    format = "\(Int(sampleRate)) Hz, \(channels) channel\(channels == 1 ? "" : "s"), "
      + "\(basic.mBitsPerChannel)-bit \(kind), \(order), \(layout)"
    ring = [Int16](repeating: 0, count: Int(sampleRate * SampleHandler.keptSeconds))
    ringAt = 0
    ringFull = false
  }

  /// How loud the buffer is, and its sound kept in the ring.
  private func measure(
    _ sampleBuffer: CMSampleBuffer,
    basic: AudioStreamBasicDescription,
    frames count: Int
  ) {
    var needed = 0
    CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(
      sampleBuffer,
      bufferListSizeNeededOut: &needed,
      bufferListOut: nil,
      bufferListSize: 0,
      blockBufferAllocator: nil,
      blockBufferMemoryAllocator: nil,
      flags: 0,
      blockBufferOut: nil
    )
    guard needed > 0 else { return }
    let raw = UnsafeMutableRawPointer.allocate(
      byteCount: needed,
      alignment: MemoryLayout<AudioBufferList>.alignment
    )
    defer { raw.deallocate() }
    let list = raw.bindMemory(to: AudioBufferList.self, capacity: 1)
    var block: CMBlockBuffer?
    let status = CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(
      sampleBuffer,
      bufferListSizeNeededOut: nil,
      bufferListOut: list,
      bufferListSize: needed,
      blockBufferAllocator: nil,
      blockBufferMemoryAllocator: nil,
      flags: kCMSampleBufferFlag_AudioBufferList_Assure16ByteAlignment,
      blockBufferOut: &block
    )
    guard status == noErr else { return }

    let flags = basic.mFormatFlags
    let float = flags & kAudioFormatFlagIsFloat != 0
    let big = flags & kAudioFormatFlagIsBigEndian != 0
    let bits = Int(basic.mBitsPerChannel)
    // A sample as a number from -1 to 1, whichever way it was written.
    func sample(_ data: UnsafeRawPointer, _ index: Int) -> Double {
      switch (float, bits) {
      case (true, 32):
        var word = data.load(fromByteOffset: index * 4, as: UInt32.self)
        if big { word = word.byteSwapped }
        return Double(Float(bitPattern: word))
      case (false, 16):
        var word = data.load(fromByteOffset: index * 2, as: UInt16.self)
        if big { word = word.byteSwapped }
        return Double(Int16(bitPattern: word)) / 32768
      case (false, 32):
        var word = data.load(fromByteOffset: index * 4, as: UInt32.self)
        if big { word = word.byteSwapped }
        return Double(Int32(bitPattern: word)) / 2_147_483_648
      default:
        return 0
      }
    }

    let audio = UnsafeMutableAudioBufferListPointer(list)
    let interleaved = flags & kAudioFormatFlagIsNonInterleaved == 0
    let channelCount = max(1, channels)
    var sum = 0.0
    var loudest = 0.0
    for frame in 0..<count {
      var mixed = 0.0
      for channel in 0..<channelCount {
        let value: Double
        if interleaved {
          guard let data = audio.first?.mData else { return }
          value = sample(data, frame * channelCount + channel)
        } else {
          guard channel < audio.count, let data = audio[channel].mData else { continue }
          value = sample(data, frame)
        }
        sum += value * value
        loudest = max(loudest, abs(value))
        mixed += value
      }
      mixed /= Double(channelCount)
      if !ring.isEmpty {
        ring[ringAt] = Int16(max(-1, min(1, mixed)) * 32767)
        ringAt += 1
        if ringAt == ring.count {
          ringAt = 0
          ringFull = true
        }
      }
    }
    let values = count * channelCount
    level = values > 0 ? (sum / Double(values)).squareRoot() : 0
    peak = loudest
    // Protected sound arrives as buffers of nothing, so they are counted.
    if loudest == 0 { silentBuffers += 1 }
  }

  /// The numbers, for the app.
  private func report(state: String) {
    guard let folder else { return }
    let now = CACurrentMediaTime()
    let seconds = firstArrival.map { (lastArrival ?? now) - $0 } ?? 0
    let numbers: [String: Any] = [
      "state": state,
      "updated": Date().timeIntervalSince1970,
      "format": format,
      "sampleRate": sampleRate,
      "channels": channels,
      "framesPerBuffer": framesPerBuffer,
      "buffers": buffers,
      "silentBuffers": silentBuffers,
      "frames": frames,
      "seconds": seconds,
      "level": level,
      "peak": peak,
      "longestGap": longestGap,
      "jumps": jumps,
    ]
    guard let data = try? JSONSerialization.data(withJSONObject: numbers) else { return }
    writer.async {
      try? data.write(to: folder.appendingPathComponent("broadcast.json"), options: .atomic)
    }
  }

  /// The last stretch of sound, oldest first, as a WAV.
  private func keep() {
    guard let folder, !ring.isEmpty, ringFull || ringAt > 0 else { return }
    let samples = ringFull ? Array(ring[ringAt...] + ring[..<ringAt]) : Array(ring[..<ringAt])
    let rate = UInt32(sampleRate)
    writer.async {
      var wav = Data()
      func add<T: FixedWidthInteger>(_ value: T) {
        withUnsafeBytes(of: value.littleEndian) { wav.append(contentsOf: $0) }
      }
      let bytes = UInt32(samples.count * 2)
      wav.append(contentsOf: Array("RIFF".utf8))
      add(36 + bytes)
      wav.append(contentsOf: Array("WAVEfmt ".utf8))
      add(UInt32(16))
      add(UInt16(1))
      add(UInt16(1))
      add(rate)
      add(rate * 2)
      add(UInt16(2))
      add(UInt16(16))
      wav.append(contentsOf: Array("data".utf8))
      add(bytes)
      samples.withUnsafeBytes { wav.append(contentsOf: $0) }
      try? wav.write(to: folder.appendingPathComponent("broadcast.wav"), options: .atomic)
    }
  }
}
