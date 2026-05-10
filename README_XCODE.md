# How to Build and Run on iPhone 13

The Xcode project we created earlier has configuration issues. Here's the easiest way to get this running on your iPhone 13:

## Option 1: Create a New Xcode Project (Easiest)

1. **Open Xcode** → File → New → Project
2. Choose **iOS → App**
3. Enter:
   - Product Name: `SpO2Monitor`
   - Team: Select your Apple ID
   - Organization Identifier: `com.gibtang`
   - Bundle Identifier: `com.gibtang.SpO2Monitor`
   - Interface: SwiftUI
   - Language: Swift
4. Save it in a temporary location

5. **Copy the source files** to the new project:
   ```bash
   # Copy all source files to your new Xcode project
   cp -r SpO2Monitor/* /path/to/new/project/
   ```

6. **In Xcode:**
   - Add all `.swift` files from SpO2Monitor/ to your project
   - Make sure `SpO2MonitorApp.swift` is NOT added (it has @main)
   - Delete the default `ContentView.swift` and `PROJECTNAMEApp.swift` that Xcode created
   - Use the `ContentView.swift` from our project

7. **Add Info.plist entries** (in Xcode → Target → Info tab):
   - Privacy - Camera Usage Description: "This app needs camera access to measure blood oxygen levels"
   - Privacy - Motion Usage Description: "This app uses motion sensors to detect movement"

8. **Connect your iPhone 13** and select it as the destination

9. **Build and Run** (Cmd+R)

## Option 2: Use Swift Package Manager + Create iOS App

Create a new iOS app that uses the SpO2Monitor package:

```bash
# Create a new iOS app directory
mkdir SpO2MonitorApp
cd SpO2MonitorApp

# Initialize as an Xcode project
swift package init --type executable --name SpO2MonitorApp
```

Then manually create an Xcode project that imports the SpO2Monitor library.

## Notes

- The project requires **iOS 17.0+**
- You need a **physical iPhone** (camera access doesn't work on simulator)
- **Camera permissions** are required
- **Rear camera** with **flash** is used for PPG measurement

## Testing

Once running on your iPhone 13:
1. Accept the medical disclaimer
2. Place your finger over the rear camera and flash
3. Hold still for 30 seconds
4. View your SpO2 and heart rate results
