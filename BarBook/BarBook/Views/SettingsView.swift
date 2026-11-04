import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(SyncMonitor.self) private var sync
    @Environment(PurchaseManager.self) private var purchases
    @Environment(AdsManager.self) private var ads
    @Query private var bartenders: [Bartender]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent("Status") {
                        HStack(spacing: 6) {
                            if sync.isSyncing { ProgressView().controlSize(.small) }
                            Text(sync.accountDescription)
                        }
                    }
                    if let date = sync.lastSyncDate {
                        LabeledContent("Last synced", value: date.formatted(.relative(presentation: .named)))
                    }
                    LabeledContent("Bartenders saved", value: "\(bartenders.count)")
                    if let error = sync.lastErrorMessage {
                        Text(error).font(.caption).foregroundStyle(.red)
                    }
                } header: {
                    Text("iCloud backup")
                } footer: {
                    Text("Everything is stored in your private iCloud and backed up automatically. On a new iPhone, or after reinstalling, sign in with the same Apple ID and open BarBook — your bartenders and photos are restored by themselves. Nothing is shared with anyone else.")
                }

                Section {
                    if purchases.hasRemovedAds {
                        Label("Ads removed — cheers!", systemImage: "checkmark.seal.fill")
                            .foregroundStyle(.green)
                    } else {
                        Button {
                            Task { await purchases.purchaseRemoveAds() }
                        } label: {
                            HStack {
                                Label("Remove ads", systemImage: "nosign")
                                Spacer()
                                if purchases.isPurchasing {
                                    ProgressView()
                                } else if let product = purchases.removeAdsProduct {
                                    Text(product.displayPrice).foregroundStyle(.secondary)
                                }
                            }
                        }
                        .disabled(purchases.removeAdsProduct == nil || purchases.isPurchasing)
                    }
                    Button("Restore purchases") {
                        Task { await purchases.restorePurchases() }
                    }
                    if ads.isPrivacyOptionsRequired {
                        Button("Ad privacy choices") {
                            Task { await ads.presentPrivacyOptions() }
                        }
                    }
                } header: {
                    Text("Adverts")
                } footer: {
                    Text("BarBook is free and kept going by a small banner at the bottom of the screen — never pop-ups or videos. A one-off purchase removes it for good.")
                }

                Section("About") {
                    LabeledContent("Version", value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—")
                }
            }
            .navigationTitle("Settings")
            .alert("Purchase problem", isPresented: Binding(
                get: { purchases.errorMessage != nil },
                set: { if !$0 { purchases.errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(purchases.errorMessage ?? "")
            }
            .task { await sync.refreshAccountStatus() }
        }
    }
}
