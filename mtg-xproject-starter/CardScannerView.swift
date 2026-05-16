import AVFoundation
import SwiftUI
import UIKit

struct CardScannerView: View {
    private let textRecognizer: any CardTextRecognizing
    private let cardIdentifier: any CardIdentifying
    private let onResult: (CardIdentificationResult) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var authorizationState = CameraAuthorizationState.checking
    @State private var captureRequestID = 0
    @State private var isScanning = false
    @State private var errorMessage: String?

    init(
        textRecognizer: any CardTextRecognizing = VisionCardTextRecognizer(),
        cardIdentifier: any CardIdentifying = ScryfallCardService(),
        onResult: @escaping (CardIdentificationResult) -> Void
    ) {
        self.textRecognizer = textRecognizer
        self.cardIdentifier = cardIdentifier
        self.onResult = onResult
    }

    var body: some View {
        NavigationStack {
            ZStack {
                scannerContent

                VStack {
                    Spacer()

                    scanControls
                }
                .padding()
            }
            .navigationTitle("Scan Card")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .task {
                await updateCameraAuthorization()
            }
        }
    }

    @ViewBuilder private var scannerContent: some View {
        switch authorizationState {
        case .checking:
            ProgressView("Checking camera")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .authorized:
            CameraCaptureView(
                captureRequestID: captureRequestID,
                onCapture: handleCapture,
                onFailure: { errorMessage = $0.userFacingMessage }
            )
            .ignoresSafeArea(edges: .bottom)
            .overlay(alignment: .center) {
                RoundedRectangle(cornerRadius: 16)
                    .stroke(.white.opacity(0.75), lineWidth: 2)
                    .frame(width: 250, height: 350)
                    .shadow(radius: 8)
                    .accessibilityHidden(true)
            }
        case .denied:
            ContentUnavailableView(
                "Camera Access Needed",
                systemImage: "camera.fill",
                description: Text("Enable camera access in Settings to scan physical Magic cards.")
            )
        case .unavailable:
            ContentUnavailableView(
                "Camera Unavailable",
                systemImage: "camera.fill",
                description: Text("Run on an iPhone or attach a camera-capable simulator device to scan cards.")
            )
        }
    }

    private var scanControls: some View {
        VStack(spacing: 12) {
            if let errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(.callout)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.red.opacity(0.9), in: RoundedRectangle(cornerRadius: 8))
            }

            Button {
                errorMessage = nil
                captureRequestID += 1
            } label: {
                Label(isScanning ? "Scanning" : "Scan", systemImage: isScanning ? "text.viewfinder" : "camera.viewfinder")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(authorizationState != .authorized || isScanning)
        }
    }

    private func updateCameraAuthorization() async {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            authorizationState = .unavailable
            return
        }

        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            authorizationState = .authorized
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            authorizationState = granted ? .authorized : .denied
        case .denied, .restricted:
            authorizationState = .denied
        @unknown default:
            authorizationState = .denied
        }
    }

    private func handleCapture(_ image: CGImage) {
        isScanning = true

        Task {
            do {
                let recognizedText = try await textRecognizer.recognizeText(from: image)
                let result = try await cardIdentifier.identify(recognizedText)
                onResult(result)
                dismiss()
            } catch {
                errorMessage = error.userFacingMessage
            }

            isScanning = false
        }
    }
}

private enum CameraAuthorizationState {
    case checking
    case authorized
    case denied
    case unavailable
}

private struct CameraCaptureView: UIViewControllerRepresentable {
    let captureRequestID: Int
    let onCapture: (CGImage) -> Void
    let onFailure: (Error) -> Void

    func makeUIViewController(context: Context) -> CameraCaptureViewController {
        let controller = CameraCaptureViewController()
        controller.onCapture = onCapture
        controller.onFailure = onFailure
        controller.configureSession()
        return controller
    }

    func updateUIViewController(_ uiViewController: CameraCaptureViewController, context: Context) {
        guard context.coordinator.lastCaptureRequestID != captureRequestID else {
            return
        }

        context.coordinator.lastCaptureRequestID = captureRequestID
        uiViewController.capturePhoto()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator {
        var lastCaptureRequestID = 0
    }
}

private final class CameraCaptureViewController: UIViewController, AVCapturePhotoCaptureDelegate {
    var onCapture: ((CGImage) -> Void)?
    var onFailure: ((Error) -> Void)?

    private let session = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private let sessionQueue = DispatchQueue(label: "mtg.card-scanner.camera")
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var isConfigured = false

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopSession()
    }

    func configureSession() {
        guard !isConfigured else {
            return
        }

        isConfigured = true
        session.sessionPreset = .photo

        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            onFailure?(CameraCaptureError.cameraUnavailable)
            return
        }

        do {
            let input = try AVCaptureDeviceInput(device: camera)

            session.beginConfiguration()

            if session.canAddInput(input) {
                session.addInput(input)
            }

            if session.canAddOutput(photoOutput) {
                session.addOutput(photoOutput)
            }

            session.commitConfiguration()
            addPreviewLayer()
            startSession()
        } catch {
            onFailure?(error)
        }
    }

    func capturePhoto() {
        let settings = AVCapturePhotoSettings()
        settings.flashMode = .off
        photoOutput.capturePhoto(with: settings, delegate: self)
    }

    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        if let error {
            onFailure?(error)
            return
        }

        guard
            let data = photo.fileDataRepresentation(),
            let image = UIImage(data: data),
            let cgImage = image.cgImage
        else {
            onFailure?(CameraCaptureError.invalidPhoto)
            return
        }

        onCapture?(cgImage)
    }

    private func addPreviewLayer() {
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.frame = view.bounds
        view.layer.insertSublayer(previewLayer, at: 0)
        self.previewLayer = previewLayer
    }

    private func startSession() {
        sessionQueue.async { [session] in
            guard !session.isRunning else {
                return
            }

            session.startRunning()
        }
    }

    private func stopSession() {
        sessionQueue.async { [session] in
            guard session.isRunning else {
                return
            }

            session.stopRunning()
        }
    }
}

private enum CameraCaptureError: Error, LocalizedError {
    case cameraUnavailable
    case invalidPhoto

    var errorDescription: String? {
        switch self {
        case .cameraUnavailable:
            "No back camera is available."
        case .invalidPhoto:
            "The camera captured a photo the app could not read."
        }
    }
}
