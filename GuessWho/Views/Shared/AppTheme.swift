import SwiftUI

struct AppPalette {
    let ink = Color(red: 0.09, green: 0.13, blue: 0.22)
    let deepBlue = Color(red: 0.16, green: 0.39, blue: 0.77)
    let sky = Color(red: 0.44, green: 0.75, blue: 0.93)
    let coral = Color(red: 0.96, green: 0.49, blue: 0.41)
    let green = Color(red: 0.24, green: 0.68, blue: 0.52)
    let warning = Color(red: 0.92, green: 0.58, blue: 0.21)
}

func appBackgroundGradient() -> LinearGradient {
    LinearGradient(
        colors: [
            Color(red: 0.99, green: 0.97, blue: 0.94),
            Color(red: 0.95, green: 0.97, blue: 0.99),
            Color(red: 0.92, green: 0.96, blue: 0.95)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

struct SurfaceCardBackground: View {
    let palette: AppPalette

    var body: some View {
        RoundedRectangle(cornerRadius: 30, style: .continuous)
            .fill(.white.opacity(0.78))
            .overlay {
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .stroke(.white.opacity(0.72), lineWidth: 1)
            }
            .shadow(color: palette.ink.opacity(0.07), radius: 22, x: 0, y: 14)
    }
}
