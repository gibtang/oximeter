# SpO₂ Monitor

A wellness app for iPhone that measures blood oxygen saturation (SpO₂) and heart rate using the rear camera and LED flash.

## ⚠️ Medical Disclaimer

**This is NOT a medical device.** This app is for wellness and fitness purposes only. Do not use for medical diagnosis or treatment decisions.

## Requirements

- iPhone XR or later (iPhone 13+ recommended)
- iOS 17.0+
- Camera and motion permissions

## How to Use

1. Open the app and accept the disclaimer
2. Place your finger over the rear camera and flash
3. Keep still for 30 seconds (5s calibration + 25s measurement)
4. View your SpO₂ and heart rate results

## Technical Details

- **Technology**: Reflectance Photoplethysmography (PPG)
- **Camera**: 60fps capture with locked exposure/white balance
- **Processing**: Real-time vDSP filtering and peak detection
- **Privacy**: All processing happens on-device

## Accuracy

- Target accuracy: ±3-5% compared to medical devices
- Factors affecting accuracy: ambient light, motion, skin tone, nail polish, circulation

## Building

```bash
# Open in Xcode
open SpO2Monitor.xcodeproj

# Build and run (Cmd+R)
```

## License

Private repository. See LICENSE file for details.
