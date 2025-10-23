# WiFiHook - WiFi Network Scanner Daemon

A lightweight iOS daemon that continuously scans for specific WiFi networks and creates a flag file when detected.

## Features

- **Runs Forever**: Daemon continuously runs with two modes (scanning/sleeping)
- **Smart Mode Switching**:
  - **Scanning Mode**: Scans every 5 seconds when flag file doesn't exist
  - **Sleeping Mode**: Sleeps for 3 minutes when flag file exists, then checks again
- **Case-Insensitive Substring Matching**: Finds network names containing the target string
- **No Connection Required**: Only scans networks, never attempts to connect
- **Configurable Logging**: Easy toggle to enable/disable verbose logging
- **Flag File Creation**: Creates a timestamped flag file when target network is detected

## Configuration

All configuration options are located at the top of `wifihookd.m`:

```objc
// ========== CONFIGURATION ==========
// Change these values to customize the daemon behavior
static NSString *const kTargetSSID = @"MyDevice";  // WiFi network name to search for (case-insensitive substring match)
static NSString *const kFlagFilePath = @"/private/var/mobile/mydevice_found.flag";  // Path where flag file will be created
static BOOL kEnableLogging = YES;  // Set to NO to disable all logging
static const NSTimeInterval kScanInterval = 5.0;  // Seconds between WiFi scans when network not found
static const NSTimeInterval kSleepInterval = 180.0;  // Seconds to sleep when flag file exists (3 minutes)
// ===================================
```

### Configuration Options:

1. **kTargetSSID**: The WiFi network name to search for
   - Performs case-insensitive substring matching
   - Examples: "mydevice", "MyNetwork", "Test"
   - Will match: "mydevice", "mydevice", "Mymydevice123", "Testmydevice", etc.

2. **kFlagFilePath**: Where to create the flag file when network is detected
   - Default: `/private/var/mobile/mydevice_found.flag`
   - Change this to any writable path on the device

3. **kEnableLogging**: Enable or disable daemon logging
   - `YES` - Full verbose logging to `/var/mobile/wifihookd.err` (default)
   - `NO` - Silent mode, no logs written

4. **kScanInterval**: How often to scan for WiFi networks (in seconds)
   - Default: `5.0` (scans every 5 seconds when in scanning mode)
   - Only applies when flag file doesn't exist

5. **kSleepInterval**: How long to sleep when flag file exists (in seconds)
   - Default: `180.0` (3 minutes)
   - Daemon will check if flag still exists after each sleep interval

## Building

### Using Docker (Recommended):

```bash
docker build -t wifihook-builder .
docker run --rm -v "$(pwd)/output:/output" wifihook-builder
```

The .deb package will be in the `output/` directory.

### Using GitHub Actions:

Push to the main branch and the workflow will automatically build the .deb package.

## Installation

1. Copy the .deb file to your jailbroken iOS device:
   ```bash
   scp output/com.mydevice.wifihook_1.0.0_iphoneos-arm.deb root@<device-ip>:/private/var/mobile/debs/
   ```

2. SSH into the device and install:
   ```bash
   ssh root@<device-ip>
   cd /private/var/mobile/debs
   dpkg -i com.mydevice.wifihook_1.0.0_iphoneos-arm.deb
   ```

3. Fix permissions and load the daemon:
   ```bash
   chmod 644 /Library/LaunchDaemons/com.mydevice.wifihookd.plist
   chown root:wheel /Library/LaunchDaemons/com.mydevice.wifihookd.plist
   launchctl load /Library/LaunchDaemons/com.mydevice.wifihookd.plist
   ```

## Usage

Once installed, the daemon:
- Starts automatically on boot
- **Runs forever** with two operating modes:
  - **Scanning Mode**: When flag file doesn't exist, scans for WiFi networks every 5 seconds
  - **Sleeping Mode**: When flag file exists, sleeps for 3 minutes, then checks if flag still exists
- Creates the flag file when the target network is detected
- If someone deletes the flag file, daemon automatically resumes scanning

### Behavior Flow:

```
Boot → Start Daemon
         ↓
    Flag exists? ──No──→ Scan for network
         ↓ Yes               ↓
    Sleep 3 min         Found? ──Yes──→ Create flag
         ↓                   ↓ No
    Check again         Sleep 5 sec
         ↓                   ↓
    Flag exists? ←──────────┘
```

### Checking Logs:

```bash
tail -f /var/mobile/wifihookd.err
```

### Manually Testing:

```bash
# Unload daemon
launchctl unload /Library/LaunchDaemons/com.mydevice.wifihookd.plist

# Remove old flag file
rm -f /private/var/mobile/mydevice_found.flag

# Reload daemon
launchctl load /Library/LaunchDaemons/com.mydevice.wifihookd.plist

# Check if flag file was created
ls -l /private/var/mobile/mydevice_found.flag
cat /private/var/mobile/mydevice_found.flag
```

## Uninstallation

```bash
launchctl unload /Library/LaunchDaemons/com.mydevice.wifihookd.plist
dpkg -r com.mydevice.wifihook
```

## Requirements

- Jailbroken iOS device (iOS 7.0+)
- Root access
- MobileWiFi.framework (built-in on iOS)

## License

Open source - modify as needed.
