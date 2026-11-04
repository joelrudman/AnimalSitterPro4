import ActivityKit
import WidgetKit
import SwiftUI

private let amber = Color(red: 0.851, green: 0.533, blue: 0.098)

/// Lock Screen banner + Dynamic Island for "you've just walked into a pub you know".
struct PubArrivalLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PubArrivalAttributes.self) { context in
            LockScreenView(attributes: context.attributes, state: context.state)
                .activityBackgroundTint(Color.black.opacity(0.75))
                .activitySystemActionForegroundColor(amber)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label {
                        Text(context.attributes.pubName).font(.headline).lineLimit(1)
                    } icon: {
                        Image(systemName: "mug.fill").foregroundStyle(amber)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("\(context.state.totalCount) here")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    PeopleRow(state: context.state, avatarSize: 40)
                        .padding(.top, 4)
                }
            } compactLeading: {
                Image(systemName: "mug.fill").foregroundStyle(amber)
            } compactTrailing: {
                Text(compactNames(context.state))
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                    .frame(maxWidth: 70)
            } minimal: {
                Image(systemName: "mug.fill").foregroundStyle(amber)
            }
            .keylineTint(amber)
        }
    }

    private func compactNames(_ state: PubArrivalAttributes.ContentState) -> String {
        guard let first = state.people.first?.name.split(separator: " ").first else { return "" }
        let others = state.totalCount - 1
        return others > 0 ? "\(first) +\(others)" : String(first)
    }
}

private struct LockScreenView: View {
    let attributes: PubArrivalAttributes
    let state: PubArrivalAttributes.ContentState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "mug.fill")
                    .font(.title3)
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(amber, in: Circle())
                VStack(alignment: .leading, spacing: 1) {
                    Text("You're at \(attributes.pubName)")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text(state.totalCount == 1 ? "1 bartender you know" : "\(state.totalCount) bartenders you know")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.7))
                }
                Spacer()
                Text(attributes.arrivedAt, style: .time)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
            }
            PeopleRow(state: state, avatarSize: 46)
        }
        .padding(16)
    }
}

private struct PeopleRow: View {
    let state: PubArrivalAttributes.ContentState
    let avatarSize: CGFloat

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            ForEach(state.people, id: \.self) { person in
                VStack(spacing: 4) {
                    Avatar(person: person, size: avatarSize)
                    Text(person.name.split(separator: " ").first.map(String.init) ?? person.name)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                }
                .frame(width: avatarSize + 14)
            }
            let extra = state.totalCount - state.people.count
            if extra > 0 {
                Text("+\(extra)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.8))
                    .frame(width: avatarSize, height: avatarSize)
                    .background(.white.opacity(0.15), in: Circle())
            }
            Spacer(minLength: 0)
        }
    }
}

private struct Avatar: View {
    let person: PubArrivalAttributes.Person
    let size: CGFloat

    var body: some View {
        Group {
            if let file = person.thumbnailFile,
               let url = SharedConfig.thumbnailURL(named: file),
               let image = UIImage(contentsOfFile: url.path) {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                Text(initials)
                    .font(.system(size: size * 0.38, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(amber.opacity(0.85))
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(Circle().stroke(.white.opacity(0.25), lineWidth: 1))
    }

    private var initials: String {
        let letters = person.name.split(separator: " ").prefix(2).compactMap(\.first)
        return letters.isEmpty ? "?" : String(letters).uppercased()
    }
}
