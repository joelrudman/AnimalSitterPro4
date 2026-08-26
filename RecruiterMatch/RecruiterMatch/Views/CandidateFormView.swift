import SwiftUI
import UniformTypeIdentifiers

struct CandidateFormView: View {
    @EnvironmentObject private var store: CandidateStore
    @Environment(\.dismiss) private var dismiss

    let existingCandidate: Candidate?

    @State private var fullName = ""
    @State private var email = ""
    @State private var phone = ""
    @State private var currentTitle = ""
    @State private var yearsExperience = 0
    @State private var location = ""
    @State private var summary = ""
    @State private var skills: [String] = []
    @State private var newSkill = ""

    @State private var cvFileName: String?
    @State private var cvText: String?
    @State private var pendingCVLocalURL: URL?
    @State private var cvNotice: String?

    @State private var showingFileImporter = false
    @State private var isSaving = false
    @State private var saveError: String?

    init(candidate: Candidate?) {
        self.existingCandidate = candidate
        if let candidate {
            _fullName = State(initialValue: candidate.fullName)
            _email = State(initialValue: candidate.email)
            _phone = State(initialValue: candidate.phone)
            _currentTitle = State(initialValue: candidate.currentTitle)
            _yearsExperience = State(initialValue: candidate.yearsExperience)
            _location = State(initialValue: candidate.location)
            _summary = State(initialValue: candidate.summary)
            _skills = State(initialValue: candidate.skills)
            _cvFileName = State(initialValue: candidate.cvFileName)
            _cvText = State(initialValue: candidate.cvText)
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Contact") {
                    TextField("Full name", text: $fullName)
                        .textContentType(.name)
                    TextField("Email", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                    TextField("Phone", text: $phone)
                        .textContentType(.telephoneNumber)
                        .keyboardType(.phonePad)
                    TextField("Location (city, state)", text: $location)
                }

                Section("Role") {
                    TextField("Current / most recent title", text: $currentTitle)
                    Stepper("Years of experience: \(yearsExperience)", value: $yearsExperience, in: 0...50)
                }

                Section {
                    skillsEditor
                } header: {
                    Text("Skills")
                } footer: {
                    Text("These carry the most weight when matching to companies — add the candidate's strongest, most specific skills.")
                }

                Section("Notes") {
                    TextEditor(text: $summary)
                        .frame(minHeight: 80)
                }

                Section("CV / Résumé") {
                    if let cvFileName {
                        Label(cvFileName, systemImage: "doc.fill")
                    }
                    Button {
                        showingFileImporter = true
                    } label: {
                        Label(cvFileName == nil ? "Upload CV" : "Replace CV", systemImage: "arrow.up.doc")
                    }
                    if let cvNotice {
                        Text(cvNotice)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    if let cvText, !cvText.isEmpty {
                        Text("\(cvText.count) characters extracted for matching.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                if let saveError {
                    Section {
                        Text(saveError)
                            .foregroundStyle(.red)
                            .font(.footnote)
                    }
                }
            }
            .navigationTitle(existingCandidate == nil ? "New Candidate" : "Edit Candidate")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await save() }
                    } label: {
                        if isSaving {
                            ProgressView()
                        } else {
                            Text("Save")
                        }
                    }
                    .disabled(fullName.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
                }
            }
            .fileImporter(
                isPresented: $showingFileImporter,
                allowedContentTypes: CVTextExtractor.supportedContentTypes,
                allowsMultipleSelection: false
            ) { result in
                handleFileImport(result)
            }
        }
    }

    private var skillsEditor: some View {
        VStack(alignment: .leading, spacing: 10) {
            WrapLayout(spacing: 8) {
                ForEach(skills, id: \.self) { skill in
                    SkillChipView(text: skill) {
                        skills.removeAll { $0 == skill }
                    }
                }
            }
            HStack {
                TextField("Add a skill (e.g. Swift, B2B Sales)", text: $newSkill)
                    .onSubmit(addSkill)
                Button("Add", action: addSkill)
                    .disabled(newSkill.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }

    private func addSkill() {
        let trimmed = newSkill.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !skills.contains(where: { $0.caseInsensitiveCompare(trimmed) == .orderedSame }) else {
            newSkill = ""
            return
        }
        skills.append(trimmed)
        newSkill = ""
    }

    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .failure(let error):
            cvNotice = "Couldn't import file: \(error.localizedDescription)"
        case .success(let urls):
            guard let url = urls.first else { return }

            let didAccess = url.startAccessingSecurityScopedResource()
            defer { if didAccess { url.stopAccessingSecurityScopedResource() } }

            // Copy into a location we own, since CloudKit's CKAsset needs a stable file URL
            // and the picked URL's security scope ends when this function returns.
            let localURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + "-" + url.lastPathComponent)
            do {
                if FileManager.default.fileExists(atPath: localURL.path) {
                    try FileManager.default.removeItem(at: localURL)
                }
                try FileManager.default.copyItem(at: url, to: localURL)
            } catch {
                cvNotice = "Couldn't read the selected file: \(error.localizedDescription)"
                return
            }

            let extraction = CVTextExtractor.extractText(fromFileAt: localURL)
            cvFileName = url.lastPathComponent
            cvText = extraction.text
            cvNotice = extraction.limitedExtractionNotice
            pendingCVLocalURL = localURL
        }
    }

    private func save() async {
        isSaving = true
        saveError = nil
        defer { isSaving = false }

        var candidate = existingCandidate ?? Candidate()
        candidate.fullName = fullName.trimmingCharacters(in: .whitespaces)
        candidate.email = email.trimmingCharacters(in: .whitespaces)
        candidate.phone = phone.trimmingCharacters(in: .whitespaces)
        candidate.currentTitle = currentTitle.trimmingCharacters(in: .whitespaces)
        candidate.yearsExperience = yearsExperience
        candidate.location = location.trimmingCharacters(in: .whitespaces)
        candidate.summary = summary
        candidate.skills = skills
        if let cvFileName { candidate.cvFileName = cvFileName }
        if let cvText { candidate.cvText = cvText }
        candidate.pendingCVLocalURL = pendingCVLocalURL

        let success = await store.save(candidate)
        if success {
            dismiss()
        } else {
            saveError = store.errorMessage
        }
    }
}
