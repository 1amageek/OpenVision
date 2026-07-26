public struct VisionModelProvenance: Sendable, Hashable {
    public struct SHA256Digest: Sendable, Hashable {
        public let hexadecimal: String

        public init(
            hexadecimal: String
        ) throws(VisionModelManifestError) {
            guard
                hexadecimal.utf8.count == 64,
                hexadecimal.utf8.allSatisfy({
                    (48 ... 57).contains($0) ||
                    (97 ... 102).contains($0)
                })
            else {
                throw .invalidSHA256Digest(hexadecimal)
            }
            self.hexadecimal = hexadecimal
        }
    }

    public let publisher: String
    public let architecture: String
    public let sourceLocation: String
    public let sourceRevision: String
    public let sourceDigest: SHA256Digest
    public let trainingDatasets: [String]
    public let citations: [String]
    public let licenseIdentifier: String?

    public init(
        publisher: String,
        architecture: String,
        sourceLocation: String,
        sourceRevision: String,
        sourceDigest: SHA256Digest,
        trainingDatasets: [String],
        citations: [String],
        licenseIdentifier: String?
    ) throws(VisionModelManifestError) {
        guard !publisher.isEmpty else {
            throw .emptyProvenanceField("publisher")
        }
        guard !architecture.isEmpty else {
            throw .emptyProvenanceField("architecture")
        }
        guard !sourceLocation.isEmpty else {
            throw .emptyProvenanceField("sourceLocation")
        }
        guard !sourceRevision.isEmpty else {
            throw .emptyProvenanceField("sourceRevision")
        }
        guard trainingDatasets.allSatisfy({ !$0.isEmpty }) else {
            throw .emptyProvenanceField("trainingDatasets")
        }
        guard citations.allSatisfy({ !$0.isEmpty }) else {
            throw .emptyProvenanceField("citations")
        }
        if let licenseIdentifier, licenseIdentifier.isEmpty {
            throw .emptyProvenanceField("licenseIdentifier")
        }

        self.publisher = publisher
        self.architecture = architecture
        self.sourceLocation = sourceLocation
        self.sourceRevision = sourceRevision
        self.sourceDigest = sourceDigest
        self.trainingDatasets = trainingDatasets
        self.citations = citations
        self.licenseIdentifier = licenseIdentifier
    }
}
