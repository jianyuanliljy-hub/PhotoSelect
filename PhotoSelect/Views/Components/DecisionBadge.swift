import SwiftUI

extension PhotoDecision {
    var tint: Color {
        switch self {
        case .unreviewed: .secondary
        case .reject: .red
        case .keep: .green
        case .select: .orange
        case .hero: .purple
        }
    }

    var filledSymbol: String {
        switch self {
        case .unreviewed: "circle"
        case .reject: "xmark.circle.fill"
        case .keep: "checkmark.circle.fill"
        case .select: "star.fill"
        case .hero: "sparkles"
        }
    }
}

struct DecisionBadge: View {
    let decision: PhotoDecision

    var body: some View {
        if decision != .unreviewed {
            Label(decision.title, systemImage: decision.filledSymbol)
                .font(.caption.weight(.semibold))
                .foregroundStyle(decision.tint)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(.black.opacity(0.64), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(.white.opacity(0.10))
                }
        }
    }
}
