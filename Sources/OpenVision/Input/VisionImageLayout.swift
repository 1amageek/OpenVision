import OpenCoreVideo

public struct VisionImageLayout: Sendable, Hashable {
    public let dimensions: CVPixelDimensions
    public let pixelFormat: CVPixelFormatType
    public let storage: VisionImageStorageLayout

    public init(
        dimensions: CVPixelDimensions,
        pixelFormat: CVPixelFormatType,
        storage: VisionImageStorageLayout
    ) throws(VisionImageLayoutError) {
        switch storage {
        case .packed(let bytesPerRow, let byteCount):
            guard bytesPerRow > 0 else {
                throw .invalidBytesPerRow(bytesPerRow)
            }
            guard byteCount > 0 else {
                throw .invalidByteCount(byteCount)
            }
            let minimumByteCount = bytesPerRow.multipliedReportingOverflow(
                by: dimensions.height
            )
            guard !minimumByteCount.overflow else {
                throw .byteCountOverflow
            }
            guard byteCount >= minimumByteCount.partialValue else {
                throw .invalidByteCount(byteCount)
            }

        case .planar(let planes):
            guard !planes.isEmpty else {
                throw .invalidPlaneCount(planes.count)
            }
            var totalByteCount = 0
            for (expectedIndex, plane) in planes.enumerated() {
                guard plane.index == expectedIndex else {
                    throw .nonContiguousPlaneIndex(
                        expected: expectedIndex,
                        actual: plane.index
                    )
                }
                guard
                    plane.dimensions.width <= dimensions.width,
                    plane.dimensions.height <= dimensions.height
                else {
                    throw .planeDimensionsExceedImage(
                        plane: plane.dimensions,
                        image: dimensions
                    )
                }
                let total = totalByteCount.addingReportingOverflow(
                    plane.byteCount
                )
                guard !total.overflow else {
                    throw .byteCountOverflow
                }
                totalByteCount = total.partialValue
            }
        }

        self.dimensions = dimensions
        self.pixelFormat = pixelFormat
        self.storage = storage
    }

    public var isPlanar: Bool {
        if case .planar = storage {
            return true
        }
        return false
    }

    public var planeCount: Int {
        switch storage {
        case .packed:
            return 0
        case .planar(let planes):
            return planes.count
        }
    }

    public var byteCount: Int {
        switch storage {
        case .packed(_, let byteCount):
            return byteCount
        case .planar(let planes):
            return planes.reduce(into: 0) {
                $0 += $1.byteCount
            }
        }
    }

    public func plane(
        at index: Int
    ) throws(VisionImageLayoutError) -> VisionImagePlaneLayout {
        guard case .planar(let planes) = storage,
              planes.indices.contains(index)
        else {
            throw .invalidPlaneIndex(
                index: index,
                planeCount: planeCount
            )
        }
        return planes[index]
    }

    static func snapshot(
        of pixelBuffer: any CVPixelBuffer
    ) throws(VisionError) -> Self {
        do {
            if pixelBuffer.isPlanar {
                guard pixelBuffer.planeCount > 0 else {
                    throw VisionImageLayoutError.invalidPlaneCount(
                        pixelBuffer.planeCount
                    )
                }
                var planes: [VisionImagePlaneLayout] = []
                planes.reserveCapacity(pixelBuffer.planeCount)
                for index in 0..<pixelBuffer.planeCount {
                    let dimensions = try pixelBuffer.dimensionsOfPlane(
                        at: index
                    )
                    let bytesPerRow = try pixelBuffer.bytesPerRowOfPlane(
                        at: index
                    )
                    let byteCount = bytesPerRow.multipliedReportingOverflow(
                        by: dimensions.height
                    )
                    guard !byteCount.overflow else {
                        throw VisionImageLayoutError.byteCountOverflow
                    }
                    planes.append(
                        try VisionImagePlaneLayout(
                            index: index,
                            dimensions: dimensions,
                            bytesPerRow: bytesPerRow,
                            byteCount: byteCount.partialValue
                        )
                    )
                }
                return try Self(
                    dimensions: pixelBuffer.dimensions,
                    pixelFormat: pixelBuffer.pixelFormat,
                    storage: .planar(planes)
                )
            }

            guard pixelBuffer.planeCount == 0 else {
                throw VisionImageLayoutError.invalidPlaneCount(
                    pixelBuffer.planeCount
                )
            }
            return try Self(
                dimensions: pixelBuffer.dimensions,
                pixelFormat: pixelBuffer.pixelFormat,
                storage: .packed(
                    bytesPerRow: pixelBuffer.bytesPerRow,
                    byteCount: pixelBuffer.byteCount
                )
            )
        } catch let error as VisionImageLayoutError {
            throw .invalidImageLayout(error)
        } catch let error as CVPixelBufferError {
            throw .invalidPixelBuffer(error)
        } catch {
            throw .invalidProviderCapability(
                "VisionImageLayout.snapshot"
            )
        }
    }
}
