import Foundation
import CloudKit

struct Candidate: Identifiable, Hashable {
    static let recordType = "Candidate"

    var id: String
    var fullName: String
    var email: String
    var phone: String
    var currentTitle: String
    var yearsExperience: Int
    var location: String
    var skills: [String]
    var summary: String
    var cvFileName: String?
    var cvText: String?
    var createdAt: Date
    var updatedAt: Date

    /// Local-only reference to a CV file staged for upload before the CloudKit save completes.
    var pendingCVLocalURL: URL?

    init(
        id: String = UUID().uuidString,
        fullName: String = "",
        email: String = "",
        phone: String = "",
        currentTitle: String = "",
        yearsExperience: Int = 0,
        location: String = "",
        skills: [String] = [],
        summary: String = "",
        cvFileName: String? = nil,
        cvText: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        pendingCVLocalURL: URL? = nil
    ) {
        self.id = id
        self.fullName = fullName
        self.email = email
        self.phone = phone
        self.currentTitle = currentTitle
        self.yearsExperience = yearsExperience
        self.location = location
        self.skills = skills
        self.summary = summary
        self.cvFileName = cvFileName
        self.cvText = cvText
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.pendingCVLocalURL = pendingCVLocalURL
    }
}

// MARK: - CloudKit mapping

extension Candidate {
    /// Builds/updates a CKRecord for this candidate. Pass the existing record (if editing)
    /// so CloudKit's change-token bookkeeping is preserved; pass nil to create a new one.
    func toRecord(existing: CKRecord?) -> CKRecord {
        let record = existing ?? CKRecord(recordType: Candidate.recordType, recordID: CKRecord.ID(recordName: id))
        record["fullName"] = fullName as CKRecordValue
        record["email"] = email as CKRecordValue
        record["phone"] = phone as CKRecordValue
        record["currentTitle"] = currentTitle as CKRecordValue
        record["yearsExperience"] = yearsExperience as CKRecordValue
        record["location"] = location as CKRecordValue
        record["skills"] = skills as CKRecordValue
        record["summary"] = summary as CKRecordValue
        record["cvFileName"] = (cvFileName ?? "") as CKRecordValue
        // CloudKit string fields are capped well above what a CV needs, but keep it sane.
        record["cvText"] = String((cvText ?? "").prefix(200_000)) as CKRecordValue
        record["createdAt"] = createdAt as CKRecordValue
        record["updatedAt"] = updatedAt as CKRecordValue

        if let localURL = pendingCVLocalURL {
            record["cvAsset"] = CKAsset(fileURL: localURL)
        }

        return record
    }

    init?(record: CKRecord) {
        guard
            let fullName = record["fullName"] as? String
        else { return nil }

        self.init(
            id: record.recordID.recordName,
            fullName: fullName,
            email: record["email"] as? String ?? "",
            phone: record["phone"] as? String ?? "",
            currentTitle: record["currentTitle"] as? String ?? "",
            yearsExperience: Int(record["yearsExperience"] as? Int64 ?? 0),
            location: record["location"] as? String ?? "",
            skills: record["skills"] as? [String] ?? [],
            summary: record["summary"] as? String ?? "",
            cvFileName: (record["cvFileName"] as? String).flatMap { $0.isEmpty ? nil : $0 },
            cvText: record["cvText"] as? String,
            createdAt: record["createdAt"] as? Date ?? Date(),
            updatedAt: record["updatedAt"] as? Date ?? Date()
        )
    }

    /// Local file URL for the CV asset attached to a fetched record, if any.
    static func cvAssetURL(from record: CKRecord) -> URL? {
        (record["cvAsset"] as? CKAsset)?.fileURL
    }
}
