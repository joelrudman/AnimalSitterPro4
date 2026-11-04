import SwiftUI

struct BartenderRow: View {
    let bartender: Bartender
    var showsPub = true

    var body: some View {
        HStack(spacing: 12) {
            PhotoAvatar(thumbnailData: bartender.thumbnailData, name: bartender.name, size: 48)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(bartender.name).font(.headline)
                    if bartender.isFavourite {
                        Image(systemName: "star.fill").font(.caption).foregroundStyle(.yellow)
                    }
                }
                if showsPub {
                    Text(bartender.pubName).font(.caption).foregroundStyle(.secondary)
                }
                if !bartender.notes.isEmpty {
                    Text(bartender.notes)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, 2)
    }
}

/// Circular photo, or the person's initials if there's no photo.
struct PhotoAvatar: View {
    let thumbnailData: Data?
    let name: String
    var size: CGFloat = 48

    private var initials: String {
        let letters = name.split(separator: " ").prefix(2).compactMap(\.first)
        return letters.isEmpty ? "?" : String(letters).uppercased()
    }

    var body: some View {
        Group {
            if let thumbnailData, let image = UIImage(data: thumbnailData) {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                ZStack {
                    Circle().fill(.tint.opacity(0.2))
                    Text(initials)
                        .font(.system(size: size * 0.38, weight: .semibold, design: .rounded))
                        .foregroundStyle(.tint)
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .accessibilityHidden(true)
    }
}
