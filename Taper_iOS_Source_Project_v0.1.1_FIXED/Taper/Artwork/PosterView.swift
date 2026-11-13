import SwiftUI

struct PosterView: View {
    let artist: String
    let date: String?
    let venue: String?
    private var seed: UInt64 {
        (artist + (date ?? "") + (venue ?? "")).utf8.reduce(UInt64(14695981039346656037)) {
            ($0 ^ UInt64($1)) &* 1099511628211
        }
    }
    private var color: Color {
        switch seed % 4 {
        case 0: Color(red: 0.78, green: 0.37, blue: 0.19)
        case 1: Color(red: 0.30, green: 0.47, blue: 0.43)
        case 2: Color(red: 0.57, green: 0.35, blue: 0.49)
        default: Color(red: 0.65, green: 0.49, blue: 0.23)
        }
    }
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Rectangle().fill(color.gradient)
                Circle().stroke(.white.opacity(0.3), lineWidth: 8).frame(width: geometry.size.width * 0.7)
                    .offset(x: geometry.size.width * 0.23, y: -geometry.size.height * 0.2)
                Circle().stroke(.black.opacity(0.24), lineWidth: 20).frame(width: geometry.size.width * 0.53)
                    .offset(x: -geometry.size.width * 0.30, y: geometry.size.height * 0.22)
                VStack(alignment: .leading, spacing: 8) {
                    Text("TAPER · LIVE RECORDING").font(.system(size: 10, weight: .black, design: .monospaced)).tracking(2)
                    Spacer()
                    Text(artist.uppercased()).font(.system(size: max(21, geometry.size.width / 10), weight: .black, design: .rounded))
                        .minimumScaleFactor(0.55).lineLimit(3)
                    if let date { Text(date).font(.system(.headline, design: .monospaced)) }
                    if let venue { Text(venue).font(.caption.weight(.bold)).lineLimit(2) }
                    Rectangle().frame(height: 3)
                }
                .foregroundStyle(Color(red: 0.97, green: 0.91, blue: 0.78))
                .padding(geometry.size.width * 0.09)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .clipped()
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityLabel("Concert poster for \(artist)")
    }
}
