import SwiftUI

struct SettingsView: View {
    var onSaved: () -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var resetHour: Int?
    @State private var isLoading = false
    @State private var error: String?

    private let resetHours = Array(0...6)

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if resetHour != nil {
                        Picker("リセット時刻", selection: Binding(
                            get: { resetHour ?? 0 },
                            set: { resetHour = $0 }
                        )) {
                            ForEach(resetHours, id: \.self) { hour in
                                Text(hour == 0 ? "0:00（標準）" : "\(hour):00").tag(hour)
                            }
                        }
                    } else {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    }
                } header: {
                    Text("目標のリセット時刻")
                } footer: {
                    Text("この時刻になると、新しい1日の目標に切り替わります。たとえば3:00にすると、深夜2時台の達成も前日の記録になります。")
                }

                if let error {
                    Section {
                        Text(error).foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { Task { await save() } }
                        .disabled(resetHour == nil || isLoading)
                }
            }
            .task {
                do {
                    resetHour = try await APIService.shared.fetchSettings().resetHour
                } catch {
                    self.error = "読み込みに失敗しました"
                }
            }
        }
    }

    private func save() async {
        guard let resetHour else { return }
        isLoading = true
        error = nil
        do {
            _ = try await APIService.shared.updateSettings(UserSettings(resetHour: resetHour))
            onSaved()
            dismiss()
        } catch {
            self.error = "保存に失敗しました"
        }
        isLoading = false
    }
}
