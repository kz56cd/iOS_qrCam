//
//  CameraView.swift
//  QRCamera
//
//  Created by Masakazu Sano on 2025/11/20.
//

import SwiftUI
import AVFoundation

// QRコードの検出とカメラのストリームを処理するView Representable
struct CameraView: UIViewControllerRepresentable {
    // 読み取られたURLを格納するためのバインディング
    @Binding var scannedCode: String?

    func makeUIViewController(context: Context) -> CameraViewController {
        let controller = CameraViewController()
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: CameraViewController, context: Context) {
        // 更新処理は不要
    }

    // CoordinatorはDelegateパターンでSwiftUIとUIKit間の通信を仲介します
    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    class Coordinator: NSObject, CameraViewControllerDelegate {
        var parent: CameraView

        init(parent: CameraView) {
            self.parent = parent
        }

        // CameraViewControllerからQRコードが読み取られたときに呼ばれる
        func didFindQRCode(code: String) {
            // 親Viewのバインディング変数に検出されたコードを設定
            parent.scannedCode = code
        }
    }
}

// MARK: - CameraViewController

// CameraViewがラップするUIKitのViewController
protocol CameraViewControllerDelegate: AnyObject {
    func didFindQRCode(code: String)
}

class CameraViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    weak var delegate: CameraViewControllerDelegate?
    var captureSession: AVCaptureSession!
    var previewLayer: AVCaptureVideoPreviewLayer!
    
    // 読み取り済みのフラグ
    private var isProcessingCode = false

    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = UIColor.black
        captureSession = AVCaptureSession()

        // 1. 入力デバイスの設定（背面カメラ）
        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else { return }
        let videoInput: AVCaptureDeviceInput
        
        do {
            videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
        } catch {
            print("カメラの入力デバイス設定に失敗しました: \(error)")
            return
        }

        if (captureSession.canAddInput(videoInput)) {
            captureSession.addInput(videoInput)
        } else {
            failed()
            return
        }

        // 2. 出力の設定（メタデータ出力）
        let metadataOutput = AVCaptureMetadataOutput()

        if (captureSession.canAddOutput(metadataOutput)) {
            captureSession.addOutput(metadataOutput)

            metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            // QRコードのみを検出対象に設定
            metadataOutput.metadataObjectTypes = [.qr]
        } else {
            failed()
            return
        }

        // 3. プレビューレイヤーの設定
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.frame = view.layer.bounds
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
        
        // 4. セッションの開始
        captureSession.startRunning()
    }
    
    func failed() {
        let ac = UIAlertController(title: "スキャンに対応していません", message: "このデバイスはカメラを使ったスキャンに対応していません。", preferredStyle: .alert)
        ac.addAction(UIAlertAction(title: "OK", style: .default))
        present(ac, animated: true)
        captureSession = nil
    }

    // AVCaptureMetadataOutputObjectsDelegateの必須メソッド
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        // 一度読み取ったら、処理が完了するまで次の読み取りを防ぐ
        guard !isProcessingCode else { return }
        
        if let metadataObject = metadataObjects.first {
            guard let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject else { return }
            guard let stringValue = readableObject.stringValue else { return }
            
            // 読み取られた値がURLとして有効かチェック（シンプルなチェック）
            if stringValue.starts(with: "http") {
                isProcessingCode = true
                found(code: stringValue)
            }
        }
    }

    // QRコードを検出した際に呼ばれる
    func found(code: String) {
        delegate?.didFindQRCode(code: code)
    }

    // MARK: - View Lifecycle
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        if (captureSession?.isRunning == false) {
            captureSession.startRunning()
            isProcessingCode = false // 画面に戻ってきたらリセット
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        if (captureSession?.isRunning == true) {
            captureSession.stopRunning()
        }
    }

    override var prefersStatusBarHidden: Bool {
        return true
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .portrait
    }
}
