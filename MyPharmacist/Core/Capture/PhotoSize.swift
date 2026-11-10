//
//  PhotoSize.swift
//  MyPharmacist
//

/// A photo size in pixels, as the camera offers them.
nonisolated struct PhotoSize: Hashable, Sendable {
    let width: Int
    let height: Int

    var pixels: Int { width * height }

    /// 12-megapixel photos, with room for the few sizes just above. At the zoom the
    /// camera starts at, a 12 MP photo already holds what the sensor resolves; raise this
    /// to 50 million to try 48 MP photos (four times the memory).
    static let mostPixels = 13_000_000

    /// The largest size on offer within the limit, or the smallest there is if they are
    /// all above it.
    static func best(of sizes: [PhotoSize], mostPixels: Int = mostPixels) -> PhotoSize? {
        sizes.filter { $0.pixels <= mostPixels }.max { $0.pixels < $1.pixels }
            ?? sizes.min { $0.pixels < $1.pixels }
    }
}
