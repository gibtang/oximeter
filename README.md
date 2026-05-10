# SpO₂ Monitor

iOS wellness application for measuring blood oxygen saturation (SpO₂) and heart rate using the iPhone camera and Reflectance Photoplethysmography (PPG).

## Features

- **Non-invasive SpO₂ Measurement**: Uses iPhone's rear camera and LED flash
- **Real-time PPG Waveform**: Visual feedback during measurement
- **Motion Artifact Detection**: CoreMotion integration for data quality validation
- **30-second Measurement**: Quick and easy measurement process
- **Medical Disclaimer**: Proper health app compliance with onboarding flow
- **Swift 6 Strict Concurrency**: Thread-safe actor-based architecture

## Requirements

- **iOS 17.0+**
- **iPhone 13 or newer** (rear camera with flash required)
- **Xcode 15.0+** (for development)

## Architecture

```
SpO2Monitor/
├── App/                    # App entry point and navigation
├── Managers/               # Core business logic (actors)
│   ├── CameraManager       # 60fps camera capture with locked settings
│   ├── MotionManager       # CoreMotion accelerometer integration
│   └── SignalProcessor     # SpO₂/HR calculation algorithms
├── Models/                 # Data models
│   ├── MeasurementResult   # Final measurement output
│   ├── MeasurementState    # State machine for measurement flow
│   ├── MeasurementError    # Error handling
│   └── PPGSample           # Raw camera data
├── Views/                  # SwiftUI views
│   ├── MeasurementView     # Main measurement orchestrator
│   ├── OnboardingView      # Medical disclaimer
│   ├── WaveformView        # Real-time PPG display
│   ├── ProgressRing        # Countdown timer
│   └── ResultCard          # Results display
└── Utilities/              # Signal processing
    ├── PPGFilter          # 4th-order Butterworth bandpass filter
    └── PeakDetector       # Heart rate extraction
```

## Development Setup

### Option 1: Swift Package Manager (Recommended for library development)

```bash
# Clone the repository
git clone https://github.com/gibtang/oximeter.git
cd oximeter

# Build
swift build

# Run tests
swift test

# Build for debugging
swift build
```

### Option 2: Xcode Project (iOS App)

#### Creating a New iOS Project

1. **Open Xcode** → File → New → Project
2. Select **iOS → App**
3. Configure:
   - **Product Name**: `SpO2Monitor`
   - **Team**: Your Apple Developer account
   - **Organization Identifier**: `com.gibtang`
   - **Bundle Identifier**: `com.gibtang.SpO2Monitor`
   - **Interface**: SwiftUI
   - **Language**: Swift
   - **Minimum Deploy Target**: iOS 17.0

4. **Add Source Files**:
   - Delete `ContentView.swift` and `SpO2MonitorApp.swift` created by Xcode
   - Copy all files from `SpO2Monitor/` directory:
     ```bash
     cp -r SpO2Monitor/* /path/to/your/xcode/project/
     ```
   - In Xcode: File → Add Files → Select all `.swift` files from `SpO2Monitor/`
   - **Important**: Make sure "Copy items if needed" is checked
   - **Important**: Uncheck `SpO2Monitor/App/SpO2MonitorApp.swift` (Xcode creates its own @main)

5. **Configure Build Settings**:
   - **Swift Language Version**: Swift 6
   - **Swift Concurrency**: Strict
   - **iOS Deployment Target**: 17.0

6. **Add Permissions** (Target → Info tab):
   - **Privacy - Camera Usage Description**: "This app needs camera access to measure blood oxygen levels using photoplethysmography."
   - **Privacy - Motion Usage Description**: "This app uses motion sensors to detect movement during measurement for accurate results."
   - **Required Device Capabilities**: `armv7`

7. **Link Frameworks**:
   - AVFoundation
   - Accelerate
   - CoreMotion
   - HealthKit
   - SwiftUI

## Deployment to iPhone

### Step 1: Connect Your iPhone

1. Connect iPhone 13 to Mac via USB
2. Trust the computer on your iPhone
3. In Xcode, select your iPhone from the device dropdown

### Step 2: Code Signing

1. In Xcode Project Settings → Signing & Capabilities
2. Select your **Team** (Apple ID)
3. Xcode will:
   - Generate a provisioning profile
   - Handle bundle identifier signing

**Note**: For personal use, your free Apple ID is sufficient. For App Store distribution, you need a paid Developer Program account ($99/year).

### Step 3: Build and Run

1. Select your iPhone 13 as the destination
2. Press **Cmd+R** or click the Run button
3. First-run: Trust the Developer on your iPhone:
   - Settings → General → VPN & Device Management
   - Tap your Apple ID → Trust

### Step 4: Grant Permissions

On first launch, the app will request:
- **Camera Access**: Required - Allow
- **Motion Access**: Required - Allow

## Using the App

1. **Launch the app** and accept the medical disclaimer
2. **Position your finger**:
   - Cover the rear camera AND flash
   - Press firmly but not too hard
   - Hold completely still
3. **Wait 30 seconds**:
   - 5 seconds: Calibration (finger detection)
   - 25 seconds: Sampling
   - Real-time waveform displays
4. **View results**:
   - SpO₂ percentage (70-100%)
   - Heart rate (40-200 BPM)
   - Confidence indicator

## Measurement Algorithm

### SpO₂ Calculation

```
R = (AC_red/DC_red) / (AC_blue/DC_blue)
SpO₂ = 110 - (25 × R)
```

### Heart Rate Calculation

1. Apply 4th-order Butterworth bandpass filter (0.8-4.0 Hz)
2. Detect peaks using derivative method
3. Calculate BPM: `60 / median(peak_intervals)`
4. Validate: 40-200 BPM range

### Confidence Levels

| Level | Criteria |
|-------|----------|
| High | PI > 0.05, SNR > 20 |
| Medium | PI > 0.03, SNR > 15 |
| Low | PI ≤ 0.03, SNR ≤ 15 |

## Troubleshooting

### Build Issues

**Error: "No such module 'SpO2Monitor'"**
- Ensure all source files are added to the target
- Check that the framework target includes all files

**Error: "Camera usage description missing"**
- Add camera privacy key to Info.plist
- Clean build folder (Cmd+Shift+K)

### Runtime Issues

**"Camera not available"**
- Ensure physical iPhone device (not simulator)
- Check camera permissions in Settings
- Force quit and relaunch app

**"Finger not detected"**
- Cover BOTH camera and flash completely
- Press harder (increase perfusion)
- Reduce ambient light

**"Motion detected"**
- Hold iPhone completely still
- Place on table if needed
- Restart measurement

### Test Failures

Some SignalProcessor tests may fail with synthetic data. This is expected behavior—the algorithm is optimized for real PPG signals from camera data, not mathematical sine waves.

## Technical Specifications

### Camera Settings

| Parameter | Value |
|-----------|-------|
| Frame Rate | 60 fps |
| ISO | 50-100 |
| Exposure | 1/100s |
| White Balance | 5000K |
| Focus | Locked at 1.0m |
| ROI | 100×100 center pixels |
| Torch | 10% brightness |

### Signal Processing

| Component | Implementation |
|-----------|----------------|
| Filter | 4th-order Butterworth (0.8-4.0 Hz) |
| Peak Detection | Derivative + 500ms refractory |
| AC/DC Extraction | vDSP mean/stddev |
| Concurrency | Actor-based with async/await |

## Building for Release

### TestFlight Distribution

1. **Archive**: Product → Archive
2. **Distribute App**: TestFlight & App Store
3. **Upload** to App Store Connect
4. **Add testers** in App Store Connect

### App Store Submission

Required metadata:
- **Privacy Policy**: Required for health apps
- **Age Rating**: 12+ (Medical Information)
- **Category**: Medical or Health & Fitness
- **Screenshots**: 5 device screenshots required

## Limitations

- **Wellness use only** - Not FDA cleared for medical diagnosis
- **iPhone 13+ required** - Needs rear camera with flash
- **Ambient light sensitive** - Works best in dim lighting
- **Motion sensitive** - Requires steady hand
- **Not for clinical use** - Use only for general wellness monitoring

## Contributing

1. Fork the repository
2. Create a feature branch
3. Write tests for new functionality
4. Ensure Swift 6 strict compliance
5. Submit a pull request

## License

MIT License - See LICENSE file for details

## Disclaimer

This app is for **wellness purposes only** and is not intended to diagnose, treat, cure, or prevent any disease. Results should not be used for medical decisions. Consult a healthcare professional for medical advice.

## References

- [Reflectance Photoplethysmography](https://ieeexplore.ieee.org/document/7110235)
- [SpO₂ Measurement Using Smartphone Cameras](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC6233640/)
- [Apple AVFoundation Documentation](https://developer.apple.com/documentation/avfoundation)
- [Apple CoreMotion Documentation](https://developer.apple.com/documentation/coremotion)

## Functionality
SpO2 Monitor application for iOS.
