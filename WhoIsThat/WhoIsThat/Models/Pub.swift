import Foundation
import CoreLocation

/// A pub (or bar) — either found via Apple Maps or typed in by hand.
struct Pub: Hashable, Identifiable, Codable {
    var name: String
    var address: String
    var latitude: Double
    var longitude: Double
    /// True when Maps categorised it as nightlife/brewery etc. (vs. e.g. a restaurant).
    var isLikelyPub: Bool = true

    var id: String {
        "\(Pub.normalize(name))|\(String(format: "%.4f", latitude))|\(String(format: "%.4f", longitude))"
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var location: CLLocation {
        CLLocation(latitude: latitude, longitude: longitude)
    }

    /// Same pub if the names match (ignoring case, accents, punctuation and a leading
    /// "The") and the stored coordinates are close. GPS indoors drifts, and a pub picked
    /// from Maps vs. typed by hand will have slightly different coordinates, so we match on
    /// a radius rather than exact position.
    func isSamePlace(as other: Pub) -> Bool {
        Pub.normalize(name) == Pub.normalize(other.name)
            && location.distance(from: other.location) <= AppConfig.samePubDistance
    }

    func distance(from location: CLLocation?) -> CLLocationDistance? {
        guard let location else { return nil }
        return self.location.distance(from: location)
    }

    static func normalize(_ raw: String) -> String {
        let folded = raw
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .replacingOccurrences(of: "&", with: " and ")
        let cleaned = String(String.UnicodeScalarView(folded.unicodeScalars.filter {
            CharacterSet.alphanumerics.contains($0) || $0 == " "
        }))
        var words = cleaned.split(separator: " ").map(String.init)
        if words.first == "the" { words.removeFirst() }
        return words.joined(separator: " ")
    }
}

/// Bartenders grouped under the pub they work at.
struct PubGroup: Identifiable {
    let pub: Pub
    var bartenders: [Bartender]
    var id: String { pub.id }

    static func group(_ bartenders: [Bartender]) -> [PubGroup] {
        var groups: [PubGroup] = []
        for bartender in bartenders {
            let pub = bartender.pub
            if let index = groups.firstIndex(where: { $0.pub.isSamePlace(as: pub) }) {
                groups[index].bartenders.append(bartender)
            } else {
                groups.append(PubGroup(pub: pub, bartenders: [bartender]))
            }
        }
        return groups
    }
}

extension CLLocationDistance {
    /// "40 m", "1.2 km" or "0.8 mi" depending on the user's locale.
    var formattedDistance: String {
        let measurement = Measurement(value: self, unit: UnitLength.meters)
        return measurement.formatted(.measurement(width: .abbreviated, usage: .road, numberFormatStyle: .number.precision(.fractionLength(0...1))))
    }
}
