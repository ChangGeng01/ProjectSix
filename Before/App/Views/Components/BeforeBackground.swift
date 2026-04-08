import SwiftUI

struct BeforeBackground: View {
    var body: some View {
        ZStack {
            BeforeTheme.background
                .ignoresSafeArea()

            Circle()
                .fill(BeforeTheme.ember.opacity(0.10))
                .frame(width: 260)
                .blur(radius: 8)
                .offset(x: 140, y: -220)

            RoundedRectangle(cornerRadius: 48, style: .continuous)
                .fill(BeforeTheme.ink.opacity(0.04))
                .frame(width: 300, height: 200)
                .rotationEffect(.degrees(-12))
                .offset(x: -120, y: 260)
        }
    }
}
