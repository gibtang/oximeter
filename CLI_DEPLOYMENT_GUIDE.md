# Deploy SpO₂ Monitor to iPhone via CLI

## Prerequisites

1. iPhone 13 connected via USB
2. Xcode installed
3. Apple ID configured for code signing

## Step 1: Check if iPhone is Connected

```bash
# List all connected devices
xcrun xctrace list devices

# Or use:
instruments -s devices
```

Look for your iPhone 13 in the list. It will show a device ID like:
`iPhone 13 (00008020-001E75D801EA002E)`

## Step 2: Create a Working Xcode Project

Since our Xcode project has issues, you need to create a fresh one:

1. Open Xcode GUI
2. File → New → Project → iOS → App
3. Configure and save

## Step 3: Build and Deploy via CLI

Once you have a working Xcode project, use these commands:

```bash
# Navigate to your Xcode project directory
cd /path/to/your/Xcode/project

# Build for iOS device (physical iPhone)
xcodebuild -project SpO2Monitor.xcodeproj \
    -scheme SpO2Monitor \
    -configuration Debug \
    -sdk iphoneos \
    -destination 'id=YOUR_DEVICE_ID' \
    clean build

# Install to device
xcrun devicectl device install app --device YOUR_DEVICE_ID ./build/SpO2Monitor.app
```

## Alternative: Using ios-deploy (Third-Party Tool)

```bash
# Install ios-deploy
npm install -g ios-deploy

# Deploy to connected iPhone
ios-deploy --bundle ./build/SpO2Monitor.app
```

## Step 4: Launch the App

```bash
# Launch the app on device
xcrun devicectl device process launch --device YOUR_DEVICE_ID com.gibtang.SpO2Monitor
```

## Step 5: View Logs

```bash
# Stream device logs
xcrun devicectl device log stream --device YOUR_DEVICE_ID --style compact

# Or filter for your app:
xcrun devicectl device log stream --device YOUR_DEVICE_ID --predicate 'process == "SpO2Monitor"'
```

## Notes

- The device ID is a 40-character hex string
- Your iPhone must be unlocked during deployment
- First-time deployment requires trusting the developer certificate on iPhone

## Troubleshooting

**"No such module" error:**
- Ensure all source files are added to Xcode target

**"Code signing" error:**
- Add your Apple ID in Xcode → Preferences → Accounts
- Select your team in project settings

**"Device not found" error:**
- Ensure iPhone is connected and unlocked
- Trust the computer on iPhone
