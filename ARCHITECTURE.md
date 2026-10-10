# Metric AR implementation

## Non-negotiable invariant

Every published asset uses metres: `1 GLB unit = 1 metre`. No client is allowed
to apply a display-only scale multiplier. USDZ is generated from the same canonical
metre-scale asset.

## Capture paths

1. **LiDAR path (default):** native iOS Object Capture records calibrated images,
   poses, depth and confidence data. The capture service writes a `ScaleManifest`
   where `scaleSource=lidar`.
2. **Reference card fallback:** the user places a 100 mm × 100 mm coded card in
   the first and last capture arc. Detection supplies the metric constraint; the
   job records `scaleSource=referenceCard`.
3. **Operator verification:** if confidence is low or the resulting dimensions
   diverge from the captured dimensions, the job remains blocked until an operator
   confirms width, height and depth with a physical measurement.

## Pipeline

`iPhone ObjectCaptureSession → object storage → queue → reconstruction worker →
GLB/USDZ conversion → bounding-box validation → signed delivery URLs → QR/AR`

The web app is deliberately not the capture authority: `getUserMedia` can provide
camera frames, but it does not expose the calibrated ARKit depth/pose data needed
to promise metric scale on iPhone.

## Publish gate

The worker compares model bounds with `dimensionsMeters`. Publishing is denied
when confidence is below 0.85 or when any axis differs by more than 2% (minimum
5 mm). The dashboard shows the measured dimensions and an explicit confirmation
before it generates a QR code.
