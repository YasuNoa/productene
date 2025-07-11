import SwiftUI
import FirebaseFirestore
import FirebaseAuth
import Combine

struct ProfileView: View {
    @EnvironmentObject var viewModel: MainViewModel
    @State private var editingNickname: String = ""
    @State private var showSaveAlert: Bool = false
    @State private var isEditing: Bool = false
    @State private var userRank: Int? = nil
    @State private var alertMessage: String = ""
    @State private var alertType: AlertType = .success
    
    enum AlertType {
        case success
        case cancel
        case error
    }
    
    var body: some View {
        ZStack {
            // TimerViewと同じ背景
            MinimalDarkBackgroundView()
            
            VStack(spacing: 20) {
                // タイトル
                Text("プロフィール")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .shadow(color: .purple.opacity(0.5), radius: 10)
                    .padding(.top, 50)
                
                if let user = viewModel.user {
                    // ステータスカード
                    VStack(spacing: 20) {
                        // ニックネーム編集セクション
                        ProfileCard {
                            VStack(spacing: 15) {
                                HStack {
                                    Text("ニックネーム")
                                        .font(.headline)
                                        .foregroundColor(.white.opacity(0.7))
                                    Spacer()
                                }
                                
                                if isEditing {
                                    VStack(alignment: .leading, spacing: 5) {
                                        TextField("新しいニックネームを入力", text: $editingNickname)
                                            .textFieldStyle(DarkTextFieldStyle())
                                            .font(.title3)
                                        
                                        if editingNickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !editingNickname.isEmpty {
                                            Text("空白のみのニックネームは使用できません")
                                                .font(.caption)
                                                .foregroundColor(.red)
                                        }
                                    }
                                } else {
                                    HStack {
                                        Text(user.nickname.isEmpty ? "未設定" : user.nickname)
                                            .font(.title2)
                                            .fontWeight(.semibold)
                                            .foregroundColor(user.nickname.isEmpty ? .white.opacity(0.5) : .white)
                                        Spacer()
                                    }
                                }
                            }
                        }
                        
                        // ステータス情報
                        ProfileCard {
                            VStack(spacing: 20) {
                                StatRow(title: "レベル", value: "Lv. \(user.level)", color: .yellow)
                                StatRow(title: "総学習時間", value: viewModel.formatTime(user.totalStudyTime), color: .cyan)
                                StatRow(title: "全国ランク", value: userRank != nil ? "\(userRank!)位" : "---", color: .orange)
                                StatRow(title: "獲得経験値", value: "\(Int(user.experience)) EXP", color: .purple)
                            }
                        }
                        
                        // 編集ボタン
                        if isEditing {
                            HStack(spacing: 20) {
                                DarkButton(title: "キャンセル", color: .gray) {
                                    let originalNickname = viewModel.user?.nickname ?? ""
                                    if editingNickname != originalNickname {
                                        alertMessage = "変更を破棄しました"
                                        alertType = .cancel
                                        showSaveAlert = true
                                    }
                                    editingNickname = originalNickname
                                    isEditing = false
                                }
                                
                                DarkButton(title: "保存", color: .purple) {
                                    saveProfile()
                                }
                                .disabled(editingNickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                                .opacity(editingNickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.5 : 1.0)
                            }
                        } else {
                            DarkButton(title: "プロフィールを編集", color: .blue) {
                                // 現在のニックネームを編集フィールドにセット
                                editingNickname = viewModel.user?.nickname ?? ""
                                // もし現在のニックネームが"挑戦者"の場合は空欄にする
                                if editingNickname == "挑戦者" {
                                    editingNickname = ""
                                }
                                isEditing = true
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                
                Spacer()
            }
            .onAppear {
                findUserRank()
            }
            .onReceive(viewModel.$ranking) { _ in
                findUserRank()
            }
        }
        .overlay(
            DarkAlert(
                isPresented: $showSaveAlert,
                message: alertMessage,
                type: alertType
            )
        )
        .onChange(of: showSaveAlert) { _, newValue in
            if newValue {
                // 3秒後に自動的にアラートを閉じる
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    showSaveAlert = false
                }
            }
        }
    }
    
    private func findUserRank() {
        guard let userId = viewModel.user?.id else { return }
        userRank = viewModel.ranking.firstIndex(where: { $0.id == userId }).map { $0 + 1 }
    }
    
    private func saveProfile() {
        let trimmedNickname = editingNickname.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 空欄チェック（より厳密に）
        guard !trimmedNickname.isEmpty else {
            alertMessage = "ニックネームを入力してください"
            alertType = .error
            showSaveAlert = true
            return
        }
        
        // 最小文字数チェック（オプション）
        guard trimmedNickname.count >= 1 else {
            alertMessage = "ニックネームは1文字以上入力してください"
            alertType = .error
            showSaveAlert = true
            return
        }
        
        guard var updatedUser = viewModel.user else { return }
        updatedUser.nickname = trimmedNickname
        
        viewModel.user = updatedUser
        
        Task {
            do {
                try await viewModel.saveUserData(userToSave: updatedUser)
                
                isEditing = false
                alertMessage = "プロフィールを保存しました"
                alertType = .success
                showSaveAlert = true
                viewModel.loadRanking()
            } catch {
                print("プロフィールの保存に失敗しました: \(error)")
                alertMessage = "保存に失敗しました"
                alertType = .error
                showSaveAlert = true
            }
        }
    }
}

// ダークテーマ用のカスタムコンポーネント
struct ProfileCard<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        content
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(.black.opacity(0.3))
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(
                                LinearGradient(
                                    colors: [.purple.opacity(0.5), .blue.opacity(0.3)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
            )
            .shadow(color: .purple.opacity(0.3), radius: 10)
    }
}

struct StatRow: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack {
            Text(title)
                .font(.headline)
                .foregroundColor(.white.opacity(0.7))
            
            Spacer()
            
            Text(value)
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(color)
                .shadow(color: color.opacity(0.5), radius: 5)
        }
    }
}

struct DarkButton: View {
    let title: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(
                    RoundedRectangle(cornerRadius: 15)
                        .fill(
                            LinearGradient(
                                colors: [color, color.opacity(0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
                .shadow(color: color.opacity(0.5), radius: 10)
        }
    }
}

struct DarkTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(.white.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(.white.opacity(0.3), lineWidth: 1)
                    )
            )
            .foregroundColor(.white)
    }
}

struct BackgroundView: View {
    var body: some View {
        ZStack {
            Color(red: 0.05, green: 0, blue: 0.1)
                .ignoresSafeArea()
            
            RadialGradient(
                gradient: Gradient(colors: [
                    Color.purple.opacity(0.5),
                    Color.blue.opacity(0.2),
                    .clear
                ]),
                center: .center,
                startRadius: 50,
                endRadius: 400
            )
            .ignoresSafeArea()
            
            AngularGradient(
                gradient: Gradient(colors: [
                    .purple, .blue, .purple, .cyan, .blue, .purple
                ]),
                center: .center,
                angle: .degrees(0)
            )
            .blur(radius: 60)
            .opacity(0.7)
            .ignoresSafeArea()
        }
    }
}

struct DarkAlert: View {
    @Binding var isPresented: Bool
    let message: String
    let type: ProfileView.AlertType
    
    var body: some View {
        ZStack {
            if isPresented {
                // 背景のブラー
                Color.black.opacity(0.5)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.spring()) {
                            isPresented = false
                        }
                    }
                
                // アラートカード
                VStack(spacing: 20) {
                    // アイコン
                    Image(systemName: iconName)
                        .font(.system(size: 50))
                        .foregroundColor(iconColor)
                        .shadow(color: iconColor.opacity(0.5), radius: 10)
                    
                    // メッセージ
                    Text(message)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                    
                    // OKボタン
                    Button(action: {
                        withAnimation(.spring()) {
                            isPresented = false
                        }
                    }) {
                        Text("OK")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .frame(width: 100)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(
                                        LinearGradient(
                                            colors: gradientColors,
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                            )
                            .shadow(color: iconColor.opacity(0.5), radius: 5)
                    }
                }
                .padding(30)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color(red: 0.1, green: 0.05, blue: 0.15))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(
                                    LinearGradient(
                                        colors: [iconColor.opacity(0.5), iconColor.opacity(0.2)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 2
                                )
                        )
                )
                .shadow(color: iconColor.opacity(0.3), radius: 20)
                .scaleEffect(isPresented ? 1 : 0.8)
                .opacity(isPresented ? 1 : 0)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPresented)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isPresented)
    }
    
    private var iconName: String {
        switch type {
        case .success:
            return "checkmark.circle.fill"
        case .cancel:
            return "xmark.circle.fill"
        case .error:
            return "exclamationmark.triangle.fill"
        }
    }
    
    private var iconColor: Color {
        switch type {
        case .success:
            return .green
        case .cancel:
            return .orange
        case .error:
            return .red
        }
    }
    
    private var gradientColors: [Color] {
        switch type {
        case .success:
            return [.green, .green.opacity(0.7)]
        case .cancel:
            return [.orange, .orange.opacity(0.7)]
        case .error:
            return [.red, .red.opacity(0.7)]
        }
    }
}

#Preview(traits: .sizeThatFitsLayout) {
    ProfileView()
        .environmentObject(MainViewModel.mock)
}

// アラートのプレビュー
#Preview("Dark Alert") {
    ZStack {
        BackgroundView()
        
        VStack(spacing: 30) {
            DarkAlert(
                isPresented: .constant(true),
                message: "プロフィールを保存しました",
                type: .success
            )
        }
    }
}
