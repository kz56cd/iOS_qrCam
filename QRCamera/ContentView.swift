//
//  ContentView.swift
//  QRCamera
//
//  Created by Masakazu Sano on 2025/11/20.
//

import SwiftUI

struct ContentView: View {
    // CameraViewから検出されたURLを受け取るための状態変数
    @State private var scannedUrl: String?
    
    // URLを開くための環境変数
    @Environment(\.openURL) var openURL
    
    var body: some View {
        ZStack {
            // 1. カメラプレビュー (画面全体に表示)
            CameraView(scannedCode: $scannedUrl)
                .edgesIgnoringSafeArea(.all)
            
            // 2. 読み取り成功時のオーバーレイ（必要に応じて）
            VStack {
                Spacer()
                // 読み取り状態を表示するテキスト
                Text(scannedUrl == nil ? "QRコードをかざしてください" : "読み取り完了！")
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.black.opacity(0.7))
                    .cornerRadius(10)
                    .padding(.bottom, 50)
            }
        }
        // scannedUrlが変更されたときにトリガーされる
        .onChange(of: scannedUrl) { newUrl in
            if let urlString = newUrl, let url = URL(string: urlString) {
                // 有効なURLが読み取られたら自動で開く
                openURL(url)
                
                // 【重要】URLを開いた後、再度スキャンできるように状態をリセット
                // ただし、すぐにリセットするとSafariから戻ってきた瞬間に再開してしまうため
                // アプリケーションライフサイクルに応じてリセットを工夫することも検討してください。
                // (今回は簡潔のため、そのままにしておきますが、実用ではリセットが必要です)
                // 例: DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { self.scannedUrl = nil }
            }
        }
    }
}
