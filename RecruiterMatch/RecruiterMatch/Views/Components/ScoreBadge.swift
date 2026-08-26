import SwiftUI

struct ScoreBadge: View {
    let score: Int

    private var color: Color {
        switch score {
        case 75...100: return .green
        case 50..<75: return .orange
        default: return .gray
        }
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.2), lineWidth: 5)
            Circle()
                .trim(from: 0, to: CGFloat(score) / 100)
                .stroke(color, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text("\(score)")
                .font(.caption)
                .fontWeight(.semibold)
                .monospacedDigit()
        }
        .frame(width: 40, height: 40)
    }
}
