import SwiftUI

struct ShareCardView: View {
    let data: ShareCardData

    private let cardWidth: CGFloat = 400
    private let cardHeight: CGFloat = 700

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            header
            Group {
                switch data.pattern {
                case .declaration:
                    declarationContent
                case .achievement:
                    achievementContent
                }
            }
            Spacer(minLength: 0)
            footer
        }
        .padding(28)
        .frame(width: cardWidth, height: cardHeight, alignment: .topLeading)
        .background(Color(.systemBackground))
        .environment(\.colorScheme, .light)
    }

    private var header: some View {
        HStack {
            Image("AppLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 28, height: 28)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            Text(ShareConfig.appName)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.blue)
            Spacer()
            Text(data.dateStr)
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
        }
    }

    private var declarationContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("今日のタスク")
                .font(.system(size: 26, weight: .bold))

            goalList(showsDoneState: false)
        }
    }

    private func goalList(showsDoneState: Bool) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(data.displayedGoals) { goal in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: showsDoneState && goal.isDone ? "checkmark.square.fill" : "square")
                        .font(.system(size: 16))
                        .foregroundStyle(.blue)
                    Text(goal.title)
                        .font(.system(size: 18, weight: .medium))
                        .strikethrough(showsDoneState && goal.isDone)
                        .foregroundStyle(showsDoneState && goal.isDone ? .secondary : .primary)
                        .lineLimit(2)
                        .truncationMode(.tail)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            if data.remainingCount > 0 {
                Text("ほか\(data.remainingCount)件")
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
                    .padding(.leading, 26)
            }
        }
    }

    private var achievementContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("今日の達成結果")
                .font(.system(size: 26, weight: .bold))

            Text("\(data.progressPercent)%")
                .font(.system(size: 64, weight: .bold))
                .foregroundStyle(.blue)

            HStack {
                Text("達成した目標：\(data.doneCount) / \(data.totalCount)")
                    .font(.system(size: 17))
                    .foregroundStyle(.secondary)
                Spacer()
                if data.streakDays > 0 {
                    Label("\(data.streakDays)日連続100%", systemImage: "flame.fill")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(.orange)
                }
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(.systemGray5))
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.blue)
                        .frame(width: proxy.size.width * CGFloat(min(100, max(0, data.progressPercent))) / 100)
                }
            }
            .frame(height: 12)

            goalList(showsDoneState: true)
                .padding(.top, 6)
        }
    }

    private var footer: some View {
        VStack(spacing: 6) {
            Text(catchphrase)
                .font(.system(size: 16, weight: .bold))
            (Text("App Storeで「")
                + Text(ShareConfig.appName).foregroundColor(.blue)
                + Text("」を検索"))
                .font(.system(size: 16, weight: .bold))
        }
        .frame(maxWidth: .infinity)
    }

    private var catchphrase: String {
        switch data.pattern {
        case .declaration:
            return "サボり癖は宣言で治せる。"
        case .achievement:
            return "過程にも達成感を。"
        }
    }
}
