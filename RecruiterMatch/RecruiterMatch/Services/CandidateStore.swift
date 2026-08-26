import Foundation
import SwiftUI

/// App-level source of truth for candidates. Wraps CloudKitManager and keeps an in-memory
/// list in sync with the private CloudKit database so views stay simple.
@MainActor
final class CandidateStore: ObservableObject {
    @Published var candidates: [Candidate] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    let companies: [Company] = Company.loadBundled()
    private let cloudKit = CloudKitManager.shared

    var accountStatusMessage: String? {
        switch cloudKit.accountStatus {
        case .available:
            return nil
        case .noAccount:
            return "Sign in to iCloud to back up candidate profiles with CloudKit."
        case .restricted:
            return "iCloud access is restricted on this device."
        case .couldNotDetermine, .temporarilyUnavailable:
            return "Checking iCloud availability…"
        @unknown default:
            return "Checking iCloud availability…"
        }
    }

    func start() async {
        await cloudKit.refreshAccountStatus()
        await reload()
    }

    func reload() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            candidates = try await cloudKit.fetchAllCandidates()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @discardableResult
    func save(_ candidate: Candidate) async -> Bool {
        errorMessage = nil
        do {
            var toSave = candidate
            toSave.updatedAt = Date()
            let saved = try await cloudKit.save(toSave)
            if let index = candidates.firstIndex(where: { $0.id == saved.id }) {
                candidates[index] = saved
            } else {
                candidates.insert(saved, at: 0)
            }
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func delete(_ candidate: Candidate) async {
        errorMessage = nil
        do {
            try await cloudKit.delete(candidate)
            candidates.removeAll { $0.id == candidate.id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func topMatches(for candidate: Candidate) -> [MatchResult] {
        MatchingEngine.topMatches(for: candidate, companies: companies, limit: 10)
    }
}
