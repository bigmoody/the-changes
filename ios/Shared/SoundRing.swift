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
import Accelerate
import Foundation

final class SoundRing {
  /// How much is kept, unless asked for more.
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
  init?(writingTo url: URL, sampleRate: Double, seconds: Double = SoundRing.seconds) {
    self.sampleRate = sampleRate
    capacity = Int(sampleRate * seconds)
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
  /// played. Nil while nothing has been written.
  ///
  /// The extension writes a buffer every few hundredths of a second, far
  /// more often than twenty seconds can be copied out in a build being
  /// worked on, so the copy is not made to wait for a quiet moment. Only
  /// the count and the time beside it are read together, which is quick;
  /// the sound is taken from behind where the extension writes, and is
  /// good as long as it has not come round to it again, which it would
  /// only do if the copy took as long as the ring has to spare.
  func latest(_ seconds: Double) -> (sound: [Float], end: Double)? {
    var count: UInt64 = 0
    var finished = 0.0
    var settled = false
    for _ in 0..<100 {
      let first = sequence
      guard first % 2 == 0 else { continue }
      OSMemoryBarrier()
      count = written
      finished = end
      OSMemoryBarrier()
      if sequence == first {
        settled = true
        break
      }
    }
    guard settled else { return nil }
    // Never the whole ring: half a second is left for the extension to
    // write into while the rest is copied.
    let room = capacity - Int(sampleRate / 2)
    let wanted = min(Int(min(count, UInt64(room))), Int(seconds * sampleRate))
    guard wanted > 0 else { return nil }
    let stop = Int(count % UInt64(capacity))
    let start = (stop - wanted + capacity) % capacity
    var copied = [Int16](repeating: 0, count: wanted)
    copied.withUnsafeMutableBufferPointer { out in
      if start < stop {
        out.baseAddress!.update(from: samples + start, count: wanted)
      } else {
        let tail = capacity - start
        out.baseAddress!.update(from: samples + start, count: tail)
        (out.baseAddress! + tail).update(from: samples, count: stop)
      }
    }
    OSMemoryBarrier()
    // Come round to what was copied: start again next time.
    guard written - count < UInt64(capacity - wanted) else { return nil }
    var sound = [Float](repeating: 0, count: wanted)
    vDSP_vflt16(copied, 1, &sound, 1, vDSP_Length(wanted))
    var scale = Float(1.0 / 32768)
    vDSP_vsmul(sound, 1, &scale, &sound, 1, vDSP_Length(wanted))
    return (sound, finished)
  }
}
#endif
