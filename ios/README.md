# Forma Scanner (native iPhone capture)

This is the iPhone capture module that complements the web dashboard. Add these
files to an iOS 18+ SwiftUI target in Xcode, set the bundle identifier and add
`NSCameraUsageDescription` to `Info.plist`.

## Hardware gate

The production flow requires a physical iPhone/iPad with LiDAR, A14 Bionic or
newer, and iOS/iPadOS 18+. The app checks `ObjectCaptureSession.isSupported`
before presenting the capture UI. Unsupported devices must use the fixed-size
reference-card route, not an invented scale.

## Production handoff

After `ObjectCaptureSession` reaches `completed`, archive its images and submit
them with a `ScaleManifest` to `POST /v1/scans`. Reconstruction is a background
job. The worker must preserve metre units in the generated GLB and USDZ, validate
the resulting bounding box against `dimensionsMeters`, and reject jobs beyond
the configured tolerance before publishing.

This module must be tested on a physical device; the Simulator does not support
ARKit/Object Capture.
