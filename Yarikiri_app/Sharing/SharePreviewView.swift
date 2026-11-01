import SwiftUI
import UIKit

struct SharePreviewView: View {
    let data: ShareCardData
    @Environment(\.dismiss) private var dismiss

    @State private var renderedImage: UIImage?
    @State private var isActivitySheetPresented = false
    @State private var showCopiedMessage = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                ScrollView {
                    Group {
                        if let renderedImage {
                            Image(uiImage: renderedImage)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxWidth: 320)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
                        } else {
                            ProgressView()
                                .frame(height: 300)
                        }
                    }
                    .padding(.top, 20)
                }

                VStack(spacing: 12) {
                    Button {
                        isActivitySheetPresented = true
                    } label: {
                        Label("シェアする", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(renderedImage == nil)

                    Button {
                        copyAppLink()
                    } label: {
                        Label(
                            showCopiedMessage ? "コピーしました" : "アプリのリンクをコピー",
                            systemImage: showCopiedMessage ? "checkmark" : "link"
                        )
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
            .navigationTitle(data.pattern == .declaration ? "宣言をシェア" : "達成結果をシェア")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
            .task { renderImage() }
            .sheet(isPresented: $isActivitySheetPresented) {
                if let renderedImage {
                    ActivityShareSheet(activityItems: [renderedImage, data.shareText])
                }
            }
        }
    }

    @MainActor
    private func renderImage() {
        let renderer = ImageRenderer(content: ShareCardView(data: data))
        renderer.scale = 3
        renderedImage = renderer.uiImage
    }

    private func copyAppLink() {
        UIPasteboard.general.string = ShareConfig.appStoreURL.absoluteString
        showCopiedMessage = true
        Task {
            try? await Task.sleep(for: .seconds(2))
            showCopiedMessage = false
        }
    }
}

private struct ActivityShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
