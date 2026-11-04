import SwiftUI
import SwiftData
import PhotosUI

/// Add a new bartender, or edit an existing one.
struct BartenderEditView: View {
    enum Mode {
        case create(pub: Pub?)
        case edit(Bartender)
    }

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(CurrentPubModel.self) private var pubModel

    private let mode: Mode

    @State private var name: String
    @State private var notes: String
    @State private var pub: Pub?
    @State private var image: UIImage?
    @State private var photoChanged = false
    @State private var photoItem: PhotosPickerItem?
    @State private var showingCamera = false
    @State private var showingPubPicker = false

    init(mode: Mode) {
        self.mode = mode
        switch mode {
        case .create(let pub):
            _name = State(initialValue: "")
            _notes = State(initialValue: "")
            _pub = State(initialValue: pub)
            _image = State(initialValue: nil)
        case .edit(let bartender):
            _name = State(initialValue: bartender.name)
            _notes = State(initialValue: bartender.notes)
            _pub = State(initialValue: bartender.pub)
            _image = State(initialValue: bartender.photoData.flatMap(UIImage.init(data:)))
        }
    }

    private var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && pub != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                photoSection

                Section("Name") {
                    TextField("Bartender's name", text: $name)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                }

                Section("Description") {
                    TextField("What are they like? Signature drink, how you met, what they recommend…", text: $notes, axis: .vertical)
                        .lineLimit(4...10)
                }

                Section("Pub") {
                    Button { showingPubPicker = true } label: {
                        HStack {
                            Image(systemName: "mug.fill").foregroundStyle(.tint)
                            if let pub {
                                VStack(alignment: .leading) {
                                    Text(pub.name).foregroundStyle(.primary)
                                    if !pub.address.isEmpty {
                                        Text(pub.address).font(.caption).foregroundStyle(.secondary)
                                    }
                                }
                            } else {
                                Text("Choose pub")
                            }
                            Spacer()
                            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
                        }
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit bartender" : "New bartender")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save).disabled(!canSave)
                }
            }
            .onChange(of: photoItem) { _, item in
                guard let item else { return }
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self), let picked = UIImage(data: data) {
                        image = picked
                        photoChanged = true
                    }
                    photoItem = nil
                }
            }
            .fullScreenCover(isPresented: $showingCamera) {
                CameraPicker { captured in
                    image = captured
                    photoChanged = true
                }
                .ignoresSafeArea()
            }
            .sheet(isPresented: $showingPubPicker) {
                PubPickerView { pub = $0 }
            }
            .onAppear {
                // If we didn't know the pub when the sheet opened, fill it in once we do.
                if pub == nil { pub = pubModel.currentPub }
            }
        }
    }

    private var photoSection: some View {
        Section {
            VStack(spacing: 12) {
                Group {
                    if let image {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                    } else {
                        Image(systemName: "person.crop.circle.fill")
                            .resizable()
                            .scaledToFit()
                            .foregroundStyle(.quaternary)
                            .padding(20)
                    }
                }
                .frame(width: 140, height: 140)
                .clipShape(Circle())

                HStack(spacing: 12) {
                    if UIImagePickerController.isSourceTypeAvailable(.camera) {
                        Button { showingCamera = true } label: {
                            Label("Camera", systemImage: "camera")
                        }
                    }
                    PhotosPicker(selection: $photoItem, matching: .images) {
                        Label("Library", systemImage: "photo.on.rectangle")
                    }
                    if image != nil {
                        Button(role: .destructive) {
                            image = nil
                            photoChanged = true
                        } label: {
                            Label("Remove", systemImage: "trash")
                        }
                    }
                }
                .buttonStyle(.bordered)
                .labelStyle(.titleAndIcon)
                .font(.subheadline)

                Text("Ask before you take someone's photo.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .listRowBackground(Color.clear)
        }
    }

    private func save() {
        guard let pub else { return }
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        let processed = image.flatMap(ImageProcessor.prepare)

        switch mode {
        case .create:
            let bartender = Bartender(
                name: trimmedName,
                notes: trimmedNotes,
                pub: pub,
                photoData: processed?.photo,
                thumbnailData: processed?.thumbnail
            )
            modelContext.insert(bartender)
        case .edit(let bartender):
            bartender.name = trimmedName
            bartender.notes = trimmedNotes
            bartender.pub = pub
            if photoChanged {
                bartender.photoData = processed?.photo
                bartender.thumbnailData = processed?.thumbnail
            }
            bartender.updatedAt = Date()
        }
        try? modelContext.save()
        dismiss()
    }
}
