//
//  CameraView.swift
//  Aura Luxe
//
//  Created by CharlotteLee on 11/24/25.
//

import SwiftUI
import AVFoundation

struct CameraView: UIViewRepresentable {

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

        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.videoGravity = .resizeAspectFill

        view.previewLayer = preview
        view.layer.addSublayer(preview)

        session.startRunning()
        view.session = session

        return view
    }

    func updateUIView(_ uiView: PreviewContainerView, context: Context) {
        // Ensure the preview layer matches the current view bounds whenever layout changes.
        uiView.previewLayer?.frame = uiView.bounds
    }
}

/// A simple UIView subclass to hold onto the session and preview layer safely.
final class PreviewContainerView: UIView {
    var session: AVCaptureSession?
    var previewLayer: AVCaptureVideoPreviewLayer?

    override func layoutSubviews() {
        super.layoutSubviews()
        // Keep the preview layer sized to current bounds.
        previewLayer?.frame = bounds
    }

    deinit {
        session?.stopRunning()
    }
}
