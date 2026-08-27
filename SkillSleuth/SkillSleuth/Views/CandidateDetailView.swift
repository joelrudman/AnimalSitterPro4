import SwiftUI
import QuickLook

struct CandidateDetailView: View {
    @EnvironmentObject private var store: CandidateStore
    @State var candidate: Candidate

    @State private var showingEdit = false
    @State private var showingDeleteConfirm = false
    @State private var quickLookURL: URL?
    @State private var isDownloadingCV = false
    @State private var downloadError: String?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            Section {
                LabeledContent("Title", value: candidate.currentTitle.isEmpty ? "—" : candidate.currentTitle)
                LabeledContent("Experience", value: "\(candidate.yearsExperience) yrs")
                LabeledContent("Location", value: candidate.location.isEmpty ? "—" : candidate.location)
                if !candidate.email.isEmpty {
                    LabeledContent("Email", value: candidate.email)
                }
                if !candidate.phone.isEmpty {
                    LabeledContent("Phone", value: candidate.phone)
                }
            }

            if !candidate.skills.isEmpty {
                Section("Skills") {
                    WrapLayout(spacing: 8) {
                        ForEach(candidate.skills, id: \.self) { skill in
                            SkillChipView(text: skill)
                        }
                    }
                }
            }

            if !candidate.summary.isEmpty {
                Section("Notes") {
                    Text(candidate.summary)
                }
            }

            Section("CV / Résumé") {
                if let cvFileName = candidate.cvFileName {
                    Button {
                        Task { await openCV() }
                    } label: {
                        HStack {
                            Label(cvFileName, systemImage: "doc.fill")
                            Spacer()
                            if isDownloadingCV {
                                ProgressView()
                            }
                        }
                    }
                    if let downloadError {
                        Text(downloadError).font(.footnote).foregroundStyle(.red)
                    }
                } else {
                    Text("No CV uploaded yet.")
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                NavigationLink {
                    MatchResultsView(candidate: candidate)
                } label: {
                    Label("Find Top Companies", systemImage: "target")
                        .fontWeight(.semibold)
                }
            } footer: {
                Text("Matches skills, title, and CV content against the company database to rank the top 10 targets.")
            }
        }
        .navigationTitle(candidate.fullName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        showingEdit = true
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    Button(role: .destructive) {
                        showingDeleteConfirm = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showingEdit, onDismiss: refreshFromStore) {
            CandidateFormView(candidate: candidate)
        }
        .confirmationDialog("Delete this candidate?", isPresented: $showingDeleteConfirm, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                Task {
                    await store.delete(candidate)
                    dismiss()
                }
            }
        }
        .quickLookPreview($quickLookURL)
    }

    private func refreshFromStore() {
        if let updated = store.candidates.first(where: { $0.id == candidate.id }) {
            candidate = updated
        }
    }

    private func openCV() async {
        isDownloadingCV = true
        downloadError = nil
        defer { isDownloadingCV = false }
        do {
            guard let (fileName, data) = try await CloudKitManager.shared.fetchCVData(for: candidate.id) else {
                downloadError = "No CV file found in iCloud for this candidate."
                return
            }
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
            try data.write(to: url, options: .atomic)
            quickLookURL = url
        } catch {
            downloadError = error.localizedDescription
        }
    }
}
