import SwiftUI
import SwiftData
import MapKit

struct BartenderDetailView: View {
    let bartender: Bartender

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var showingEdit = false
    @State private var confirmingDelete = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                photo

                VStack(spacing: 6) {
                    HStack(spacing: 8) {
                        Text(bartender.name).font(.largeTitle.bold())
                        if bartender.isFavourite {
                            Image(systemName: "star.fill").foregroundStyle(.yellow)
                        }
                    }
                    .multilineTextAlignment(.center)
                    Label(bartender.pubName, systemImage: "mug.fill")
                        .foregroundStyle(.secondary)
                }

                if !bartender.notes.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Description").font(.headline)
                        Text(bartender.notes)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                }

                pubCard

                Text("Added \(bartender.createdAt.formatted(date: .long, time: .omitted))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    bartender.isFavourite.toggle()
                    bartender.updatedAt = Date()
                } label: {
                    Label("Favourite", systemImage: bartender.isFavourite ? "star.fill" : "star")
                }
                Menu {
                    Button { showingEdit = true } label: { Label("Edit", systemImage: "pencil") }
                    Button(role: .destructive) { confirmingDelete = true } label: { Label("Delete", systemImage: "trash") }
                } label: {
                    Label("More", systemImage: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showingEdit) {
            BartenderEditView(mode: .edit(bartender))
        }
        .confirmationDialog("Delete \(bartender.name)?", isPresented: $confirmingDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                modelContext.delete(bartender)
                try? modelContext.save()
                dismiss()
            }
        } message: {
            Text("This also removes them from your iCloud backup.")
        }
    }

    @ViewBuilder
    private var photo: some View {
        if let data = bartender.photoData, let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity)
                .frame(height: 320)
                .clipShape(RoundedRectangle(cornerRadius: 20))
        } else {
            PhotoAvatar(thumbnailData: nil, name: bartender.name, size: 140)
        }
    }

    private var pubCard: some View {
        let pub = bartender.pub
        return VStack(alignment: .leading, spacing: 0) {
            Map(initialPosition: .region(MKCoordinateRegion(center: pub.coordinate, latitudinalMeters: 500, longitudinalMeters: 500))) {
                Marker(pub.name, systemImage: "mug.fill", coordinate: pub.coordinate)
            }
            .frame(height: 160)
            .allowsHitTesting(false)

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(pub.name).font(.headline)
                    if !pub.address.isEmpty {
                        Text(pub.address).font(.caption).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Button("Directions") {
                    let item = MKMapItem(placemark: MKPlacemark(coordinate: pub.coordinate))
                    item.name = pub.name
                    item.openInMaps()
                }
                .buttonStyle(.bordered)
            }
            .padding()
        }
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
