import SwiftUI
import SwiftData

/// The main screen: which pub you're in, and the bartenders you've recorded there.
struct HereView: View {
    @Environment(CurrentPubModel.self) private var pubModel
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Bartender.name) private var allBartenders: [Bartender]

    @State private var showingAdd = false
    @State private var showingPubPicker = false

    private var bartendersHere: [Bartender] {
        guard let pub = pubModel.currentPub else { return [] }
        return allBartenders
            .filter { $0.pub.isSamePlace(as: pub) }
            .sorted { ($0.isFavourite ? 0 : 1, $0.name) < ($1.isFavourite ? 0 : 1, $1.name) }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    CurrentPubCard(onChangePub: { showingPubPicker = true })
                }

                if let pub = pubModel.currentPub {
                    Section {
                        if bartendersHere.isEmpty {
                            ContentUnavailableView {
                                Label("No bartenders yet", systemImage: "person.crop.circle.badge.plus")
                            } description: {
                                Text("Add the first bartender you meet at \(pub.name).")
                            } actions: {
                                Button("Add bartender") { showingAdd = true }
                                    .buttonStyle(.borderedProminent)
                            }
                        } else {
                            ForEach(bartendersHere) { bartender in
                                NavigationLink(value: bartender) {
                                    BartenderRow(bartender: bartender, showsPub: false)
                                }
                            }
                            .onDelete { offsets in
                                let targets = offsets.map { bartendersHere[$0] }
                                targets.forEach { modelContext.delete($0) }
                            }
                        }
                    } header: {
                        Text("Bartenders here (\(bartendersHere.count))")
                    }
                }
            }
            .navigationTitle("Here")
            .navigationDestination(for: Bartender.self) { BartenderDetailView(bartender: $0) }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { showingAdd = true } label: {
                        Label("Add bartender", systemImage: "plus")
                    }
                }
            }
            .refreshable { await pubModel.refresh() }
            .sheet(isPresented: $showingAdd) {
                BartenderEditView(mode: .create(pub: pubModel.currentPub))
            }
            .sheet(isPresented: $showingPubPicker) {
                PubPickerView { pubModel.select($0) }
            }
            .bannerAdInset()
        }
    }
}

/// Shows the detected pub, or whatever's stopping us detecting it.
struct CurrentPubCard: View {
    @Environment(CurrentPubModel.self) private var pubModel
    @Environment(\.openURL) private var openURL
    var onChangePub: () -> Void

    var body: some View {
        switch pubModel.state {
        case .idle, .needsPermission:
            status(icon: "location", title: "Allow location", detail: "BarBook needs your location to tell which pub you're in.") {
                Button("Allow") { Task { await pubModel.refresh() } }
            }
        case .denied:
            status(icon: "location.slash", title: "Location is off", detail: "You can still pick a pub by hand, or turn location on in Settings.") {
                HStack {
                    Button("Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                    }
                    Button("Pick pub", action: onChangePub)
                }
            }
        case .locating where pubModel.currentPub == nil:
            HStack(spacing: 12) {
                ProgressView()
                Text("Finding the pub you're in…").foregroundStyle(.secondary)
            }
            .padding(.vertical, 8)
        case .failed(let message) where pubModel.currentPub == nil:
            status(icon: "exclamationmark.triangle", title: "Couldn't find you", detail: message) {
                HStack {
                    Button("Try again") { Task { await pubModel.refresh() } }
                    Button("Pick pub", action: onChangePub)
                }
            }
        default:
            if let pub = pubModel.currentPub {
                pubSummary(pub)
            } else {
                status(icon: "mappin.slash", title: "No pubs found nearby", detail: "Pick one from search or enter its name.") {
                    Button("Pick pub", action: onChangePub)
                }
            }
        }
    }

    private func pubSummary(_ pub: Pub) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "mug.fill")
                .font(.title2)
                .foregroundStyle(.tint)
                .frame(width: 36)
            VStack(alignment: .leading, spacing: 4) {
                Text(pubModel.isManualSelection ? "You're at" : "Looks like you're at")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(pub.name).font(.title3.bold())
                if !pub.address.isEmpty {
                    Text(pub.address).font(.subheadline).foregroundStyle(.secondary)
                }
                if let distance = pub.distance(from: pubModel.location), distance > 30 {
                    Text("\(distance.formattedDistance) away")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Button("Not here? Change pub", action: onChangePub)
                    .font(.subheadline)
                    .padding(.top, 4)
            }
            Spacer(minLength: 0)
            if pubModel.state == .locating {
                ProgressView()
            }
        }
        .padding(.vertical, 4)
    }

    private func status<Actions: View>(icon: String, title: String, detail: String, @ViewBuilder actions: () -> Actions) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.secondary)
                .frame(width: 36)
            VStack(alignment: .leading, spacing: 6) {
                Text(title).font(.headline)
                Text(detail).font(.subheadline).foregroundStyle(.secondary)
                actions()
                    .buttonStyle(.bordered)
                    .padding(.top, 2)
            }
        }
        .padding(.vertical, 4)
    }
}
