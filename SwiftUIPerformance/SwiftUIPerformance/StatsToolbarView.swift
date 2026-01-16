import SwiftUI
import PerformanceShared

struct StatsToolbarView: View {
    let cpu: Int
    let gpu: Int

    var body: some View {
        HStack(spacing: 16) {
            Text("CPU \(cpu)%")
            Text("GPU \(gpu)%")
        }
        .font(.system(size: 12, weight: .semibold, design: .monospaced))
        .foregroundColor(Color(FeedSpec.StatsToolbar.textColor))
        .frame(width: FeedSpec.StatsToolbar.size.width, height: FeedSpec.StatsToolbar.size.height)
        .background(Color(FeedSpec.StatsToolbar.backgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: FeedSpec.StatsToolbar.cornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: FeedSpec.StatsToolbar.cornerRadius)
                .stroke(Color(FeedSpec.StatsToolbar.borderColor), lineWidth: FeedSpec.StatsToolbar.borderWidth)
        )
    }
}
