//
//  CameraView.swift
//  Aura Luxe
//
//  Created by CharlotteLee on 11/24/25.
//

import SwiftUI
import AVFoundation

struct CameraView: UIViewRepresentable {
    @Binding var triggerCapture: Bool
    var onCapture: (UIImage) -> Void

    func makeUIView(context: Context) -> PreviewContainerView {
        let view = PreviewContainerView(frame: .zero)

        let session = AVCaptureSession()
        session.sessionPreset = .photo

        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else {
            return view
        }

        session.addInput(input)

        let photoOutput = AVCapturePhotoOutput()
        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
        }

        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.videoGravity = .resizeAspectFill

        view.previewLayer = preview
        view.layer.addSublayer(preview)
        view.photoOutput = photoOutput
        view.onCapture = onCapture

        DispatchQueue.global(qos: .userInitiated).async {
            session.startRunning()
        }
        view.session = session

        return view
    }

    func updateUIView(_ uiView: PreviewContainerView, context: Context) {
        uiView.previewLayer?.frame = uiView.bounds
        uiView.onCapture = onCapture
        if triggerCapture {
            uiView.capturePhoto()
            DispatchQueue.main.async { triggerCapture = false }
        }
    }
}

final class PreviewContainerView: UIView {
    var session: AVCaptureSession?
    var previewLayer: AVCaptureVideoPreviewLayer?
    var photoOutput: AVCapturePhotoOutput?
    var onCapture: ((UIImage) -> Void)?

    func capturePhoto() {
        let settings = AVCapturePhotoSettings()
        settings.flashMode = .auto
        photoOutput?.capturePhoto(with: settings, delegate: self)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        previewLayer?.frame = bounds
    }

    deinit {
        session?.stopRunning()
    }
}

extension PreviewContainerView: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput,
                     didFinishProcessingPhoto photo: AVCapturePhoto,
                     error: Error?) {
        guard error == nil,
              let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data) else { return }
        DispatchQueue.main.async { self.onCapture?(image) }
    }
}
