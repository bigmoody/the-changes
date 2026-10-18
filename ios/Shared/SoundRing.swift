// The last half minute a broadcast heard, shared between the extension
// that hears it and the app that follows it. Builds being worked on only.
//
// A file in the App Group, mapped into both: the extension writes each
// buffer into it as it comes, and the app copies the latest stretch out
// whenever it wants one, without either waiting on the other. Beside the
// sound is when its last sample was played, by the phone's clock, so the
// app knows when everything in it happened.
//
// Gaps in what arrives (an advert loading, the broadcast paused) are
// written as silence, so a sample's place in the file is always its place
// in time.

#if DEBUG
import Foundation

final class SoundRing {
  /// How much is kept.
  static let seconds = 30.0

  private static let headerSize = 64
  private static let magic: UInt32 = 0x5443_5231

  private let file: Int32
  private let mapped: UnsafeMutableRawPointer
  private let size: Int

  let sampleRate: Double
  let capacity: Int

  private var samples: UnsafeMutablePointer<Int16> {
    (mapped + SoundRing.headerSize).assumingMemoryBound(to: Int16.self)
  }

  private var written: UInt64 {
    get { mapped.load(fromByteOffset: 24, as: UInt64.self) }
    set { mapped.storeBytes(of: newValue, toByteOffset: 24, as: UInt64.self) }
  }

  private var end: Double {
    get { mapped.load(fromByteOffset: 32, as: Double.self) }
    set { mapped.storeBytes(of: newValue, toByteOffset: 32, as: Double.self) }
  }

  /// Odd while the extension is writing.
  private var sequence: UInt64 {
    get { mapped.load(fromByteOffset: 40, as: UInt64.self) }
    set { mapped.storeBytes(of: newValue, toByteOffset: 40, as: UInt64.self) }
  }

  /// A new ring for the extension to write, replacing any before it.
  init?(writingTo url: URL, sampleRate: Double) {
    self.sampleRate = sampleRate
    capacity = Int(sampleRate * SoundRing.seconds)
    size = SoundRing.headerSize + capacity * 2
    try? FileManager.default.removeItem(at: url)
    file = open(url.path, O_RDWR | O_CREAT, 0o644)
    guard file >= 0, ftruncate(file, off_t(size)) == 0,
      let base = mmap(nil, size, PROT_READ | PROT_WRITE, MAP_SHARED, file, 0),
      base != MAP_FAILED
    else { return nil }
    mapped = base
    mapped.initializeMemory(as: UInt8.self, repeating: 0, count: SoundRing.headerSize)
    mapped.storeBytes(of: SoundRing.magic, as: UInt32.self)
    mapped.storeBytes(of: sampleRate, toByteOffset: 8, as: Double.self)
    mapped.storeBytes(of: UInt64(capacity), toByteOffset: 16, as: UInt64.self)
  }

  /// The ring the extension is writing, for the app to read.
  init?(readingFrom url: URL) {
    file = open(url.path, O_RDONLY)
    guard file >= 0 else { return nil }
    var info = stat()
    guard fstat(file, &info) == 0, Int(info.st_size) > SoundRing.headerSize,
      let base = mmap(nil, Int(info.st_size), PROT_READ, MAP_SHARED, file, 0),
      base != MAP_FAILED
    else {
      close(file)
      return nil
    }
    mapped = base
    size = Int(info.st_size)
    guard mapped.load(as: UInt32.self) == SoundRing.magic else {
      munmap(mapped, size)
      close(file)
      return nil
    }
    sampleRate = mapped.load(fromByteOffset: 8, as: Double.self)
    capacity = Int(mapped.load(fromByteOffset: 16, as: UInt64.self))
  }

  deinit {
    munmap(mapped, size)
    close(file)
  }

  /// One buffer of sound, one channel, whose last sample was played at
  /// [endingAt] by the phone's clock.
  func append(_ sound: [Int16], endingAt host: Double) {
    let starts = host - Double(sound.count) / sampleRate
    let before = end
    var silence = 0
    // A gap since the last buffer is silence, up to the whole ring.
    if before > 0, starts - before > 0.01 {
      silence = min(capacity, Int((starts - before) * sampleRate))
    }
    sequence &+= 1
    OSMemoryBarrier()
    var at = Int(written % UInt64(capacity))
    for _ in 0..<silence {
      samples[at] = 0
      at = (at + 1) % capacity
    }
    for value in sound {
      samples[at] = value
      at = (at + 1) % capacity
    }
    written &+= UInt64(silence + sound.count)
    end = host
    OSMemoryBarrier()
    sequence &+= 1
  }

  /// The last [seconds] heard, from -1 to 1, and when its last sample was
  /// played. Nil while nothing has been written, or while the extension
  /// is midway through writing.
  func latest(_ seconds: Double) -> (sound: [Float], end: Double)? {
    let first = sequence
    guard first % 2 == 0 else { return nil }
    OSMemoryBarrier()
    let total = Int(min(written, UInt64(capacity)))
    let wanted = min(total, Int(seconds * sampleRate))
    let finished = end
    guard wanted > 0 else { return nil }
    var out = [Float](repeating: 0, count: wanted)
    var at = (Int(written % UInt64(capacity)) - wanted + capacity) % capacity
    for i in 0..<wanted {
      out[i] = Float(samples[at]) / 32768
      at = (at + 1) % capacity
    }
    OSMemoryBarrier()
    guard sequence == first else { return nil }
    return (out, finished)
  }
}
#endif
