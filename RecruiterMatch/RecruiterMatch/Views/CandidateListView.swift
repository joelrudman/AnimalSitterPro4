import SwiftUI

struct CandidateListView: View {
    @EnvironmentObject private var store: CandidateStore
    @State private var showingNewCandidate = false
    @State private var searchText = ""

    private var filteredCandidates: [Candidate] {
        guard !searchText.isEmpty else { return store.candidates }
        let query = searchText.lowercased()
        return store.candidates.filter {
            $0.fullName.lowercased().contains(query) ||
            $0.currentTitle.lowercased().contains(query) ||
            $0.skills.contains { $0.lowercased().contains(query) }
        }
    }

    var body: some View {
        NavigationStack {
            List {
                if let message = store.accountStatusMessage {
                    Section {
                        Label(message, systemImage: "icloud.slash")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                if let error = store.errorMessage {
                    Section {
                        Label(error, systemImage: "exclamationmark.triangle")
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }

                if filteredCandidates.isEmpty && !store.isLoading {
                    ContentUnavailableView(
                        "No Candidates Yet",
                        systemImage: "person.text.rectangle",
                        description: Text("Add a candidate profile and upload their CV to get matched with top companies.")
                    )
                } else {
                    ForEach(filteredCandidates) { candidate in
                        NavigationLink(value: candidate) {
                            CandidateRow(candidate: candidate)
                        }
                    }
                    .onDelete(perform: delete)
                }
            }
            .navigationTitle("Candidates")
            .searchable(text: $searchText, prompt: "Search name, title, or skill")
            .navigationDestination(for: Candidate.self) { candidate in
                CandidateDetailView(candidate: candidate)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingNewCandidate = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .refreshable {
                await store.reload()
            }
            .overlay {
                if store.isLoading && store.candidates.isEmpty {
                    ProgressView("Loading candidates…")
                }
            }
            .sheet(isPresented: $showingNewCandidate) {
                CandidateFormView(candidate: nil)
            }
        }
    }

    private func delete(at offsets: IndexSet) {
        let toDelete = offsets.map { filteredCandidates[$0] }
        Task {
            for candidate in toDelete {
                await store.delete(candidate)
            }
        }
    }
}

private struct CandidateRow: View {
    let candidate: Candidate

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color.accentColor.opacity(0.15))
                .frame(width: 44, height: 44)
                .overlay {
                    Text(initials)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.accentColor)
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(candidate.fullName.isEmpty ? "Unnamed Candidate" : candidate.fullName)
                    .font(.headline)
                if !candidate.currentTitle.isEmpty {
                    Text(candidate.currentTitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                if candidate.cvFileName != nil {
                    Label("CV attached", systemImage: "doc.fill")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }

    private var initials: String {
        let parts = candidate.fullName.split(separator: " ")
        let letters = parts.prefix(2).compactMap { $0.first }
        return letters.isEmpty ? "?" : String(letters).uppercased()
    }
}
