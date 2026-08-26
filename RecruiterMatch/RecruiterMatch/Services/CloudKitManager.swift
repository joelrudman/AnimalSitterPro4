import Foundation
import CloudKit

enum CloudKitError: LocalizedError {
    case notSignedIn
    case restricted
    case unknownAccountStatus
    case underlying(Error)

    var errorDescription: String? {
        switch self {
        case .notSignedIn:
            return "Sign in to iCloud (Settings > [your name]) so candidate profiles can back up to CloudKit."
        case .restricted:
            return "iCloud access is restricted on this device (parental controls or MDM policy)."
        case .unknownAccountStatus:
            return "Couldn't determine iCloud account status. Check your connection and try again."
        case .underlying(let error):
            return error.localizedDescription
        }
    }
}

/// Owns all CloudKit access. Candidate profiles (including the CV file itself, as a CKAsset)
/// live in the user's private database, so they back up and sync across the recruiter's own
/// devices via their iCloud account — nothing is shared publicly.
@MainActor
final class CloudKitManager: ObservableObject {
    static let shared = CloudKitManager()

    private let container: CKContainer
    private let database: CKDatabase

    @Published var accountStatus: CKAccountStatus = .couldNotDetermine
    @Published var lastError: String?

    private init() {
        container = CKContainer.default()
        database = container.privateCloudDatabase
    }

    func refreshAccountStatus() async {
        do {
            accountStatus = try await container.accountStatus()
        } catch {
            accountStatus = .couldNotDetermine
            lastError = error.localizedDescription
        }
    }

    private func requireAvailableAccount() throws {
        switch accountStatus {
        case .available:
            return
        case .noAccount:
            throw CloudKitError.notSignedIn
        case .restricted:
            throw CloudKitError.restricted
        case .couldNotDetermine, .temporarilyUnavailable:
            throw CloudKitError.unknownAccountStatus
        @unknown default:
            throw CloudKitError.unknownAccountStatus
        }
    }

    // MARK: - Fetch

    func fetchAllCandidates() async throws -> [Candidate] {
        try requireAvailableAccount()

        let query = CKQuery(recordType: Candidate.recordType, predicate: NSPredicate(value: true))
        query.sortDescriptors = [NSSortDescriptor(key: "updatedAt", ascending: false)]

        var candidates: [Candidate] = []
        var cursor: CKQueryOperation.Cursor?

        repeat {
            let result: (matchResults: [(CKRecord.ID, Result<CKRecord, Error>)], queryCursor: CKQueryOperation.Cursor?)
            if let cursor {
                result = try await database.records(continuingMatchFrom: cursor)
            } else {
                result = try await database.records(matching: query)
            }

            for (_, recordResult) in result.matchResults {
                if case .success(let record) = recordResult, let candidate = Candidate(record: record) {
                    candidates.append(candidate)
                }
            }
            cursor = result.queryCursor
        } while cursor != nil

        return candidates
    }

    // MARK: - Save

    /// Saves a candidate, attaching the pending CV file (if any) as a CKAsset. On success
    /// returns the saved candidate re-hydrated from the server record (so the CV asset URL
    /// reflects what CloudKit actually stored).
    @discardableResult
    func save(_ candidate: Candidate) async throws -> Candidate {
        try requireAvailableAccount()

        var existing: CKRecord?
        if let fetched = try? await database.record(for: CKRecord.ID(recordName: candidate.id)) {
            existing = fetched
        }

        let record = candidate.toRecord(existing: existing)
        let saved = try await database.save(record)

        guard let result = Candidate(record: saved) else {
            throw CloudKitError.underlying(NSError(domain: "RecruiterMatch", code: -1, userInfo: [NSLocalizedDescriptionKey: "Saved record could not be read back."]))
        }
        return result
    }

    func delete(_ candidate: Candidate) async throws {
        try requireAvailableAccount()
        _ = try await database.deleteRecord(withID: CKRecord.ID(recordName: candidate.id))
    }

    /// Downloads the CV asset's data for a candidate (e.g. to preview it), given its record.
    func fetchCVData(for candidateID: String) async throws -> (fileName: String, data: Data)? {
        try requireAvailableAccount()
        let record = try await database.record(for: CKRecord.ID(recordName: candidateID))
        guard
            let asset = record["cvAsset"] as? CKAsset,
            let url = asset.fileURL,
            let data = try? Data(contentsOf: url)
        else { return nil }
        let fileName = record["cvFileName"] as? String ?? "CV"
        return (fileName, data)
    }
}
