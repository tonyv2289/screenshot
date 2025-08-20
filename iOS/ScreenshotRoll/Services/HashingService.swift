import UIKit

enum HashingService {
    // Average Hash (aHash) 8x8 → 64-bit
    static func perceptualHash(_ image: UIImage) -> UInt64 {
        let size = CGSize(width: 8, height: 8)
        UIGraphicsBeginImageContextWithOptions(size, true, 0)
        image.draw(in: CGRect(origin: .zero, size: size))
        let scaled = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        guard let cg = scaled?.cgImage,
              let data = cg.dataProvider?.data as Data?,
              let colorSpace = cg.colorSpace else {
            return 0
        }
        // Convert to grayscale by averaging RGB
        let width = cg.width
        let height = cg.height
        var gray: [UInt8] = Array(repeating: 0, count: width * height)
        let bytesPerPixel = cg.bitsPerPixel / 8
        let bytesPerRow = cg.bytesPerRow
        data.withUnsafeBytes { (raw: UnsafeRawBufferPointer) in
            for y in 0..<height {
                for x in 0..<width {
                    let offset = y * bytesPerRow + x * bytesPerPixel
                    let r = raw[offset]
                    let g = raw[offset + 1]
                    let b = raw[offset + 2]
                    let v = (UInt16(r) + UInt16(g) + UInt16(b)) / 3
                    gray[y * width + x] = UInt8(v)
                }
            }
        }
        let avg = gray.reduce(0) { $0 + Int($1) } / max(1, gray.count)
        var hash: UInt64 = 0
        for i in 0..<min(64, gray.count) {
            if Int(gray[i]) >= avg { hash |= (1 << UInt64(63 - i)) }
        }
        return hash
    }

    static func hammingDistance(_ a: UInt64, _ b: UInt64) -> Int {
        var x = a ^ b
        var count = 0
        while x != 0 {
            x &= x - 1
            count += 1
        }
        return count
    }
}

