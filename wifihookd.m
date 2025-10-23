#import <Foundation/Foundation.h>
#import <CoreFoundation/CoreFoundation.h>

// MobileWiFi.framework forward declarations
typedef struct __WiFiManager *WiFiManagerRef;
typedef struct __WiFiDeviceClient *WiFiDeviceClientRef;
typedef struct __WiFiNetwork *WiFiNetworkRef;

extern WiFiManagerRef WiFiManagerClientCreate(CFAllocatorRef allocator, int flags);
extern CFArrayRef WiFiManagerClientCopyDevices(WiFiManagerRef manager);
extern void WiFiManagerClientScheduleWithRunLoop(WiFiManagerRef manager, CFRunLoopRef runLoop, CFStringRef mode);
extern void WiFiManagerClientUnscheduleFromRunLoop(WiFiManagerRef manager);
extern void WiFiDeviceClientScanAsync(WiFiDeviceClientRef device, CFDictionaryRef scanOptions, void *callback, int token);
extern CFStringRef WiFiNetworkGetSSID(WiFiNetworkRef network);

// ========== CONFIGURATION ==========
// Change these values to customize the daemon behavior
static NSString *const kTargetSSID = @"AppleWorkshop";  // WiFi network name to search for (case-insensitive substring match)
static NSString *const kFlagFilePath = @"/private/var/mobile/alert_trigger.flag";  // Path where flag file will be created
static BOOL kEnableLogging = YES;  // Set to NO to disable all logging (logs write to /var/mobile/wifihooklibd.err)
static const NSTimeInterval kScanInterval = 5.0;  // Seconds between WiFi scans when network not found
static const NSTimeInterval kSleepInterval = 180.0;  // Seconds to sleep when flag file exists (3 minutes)
// ===================================

// Logging macro - only logs if kEnableLogging is YES
#define LOG(fmt, ...) do { if (kEnableLogging) NSLog((@"[WiFiHook] " fmt), ##__VA_ARGS__); } while(0)

// Global state for scan results
static BOOL g_scanComplete = NO;
static BOOL g_networkFound = NO;
static WiFiManagerRef g_manager = NULL;
static WiFiDeviceClientRef g_device = NULL;

@interface WiFiHook : NSObject
- (void)run;
- (void)createFlagFile;
- (BOOL)flagFileExists;
- (BOOL)scanForTargetNetwork;
@end

@implementation WiFiHook

- (BOOL)flagFileExists {
    return [[NSFileManager defaultManager] fileExistsAtPath:kFlagFilePath];
}

- (void)createFlagFile {
    // Check if flag file already exists
    if ([self flagFileExists]) {
        LOG(@"Flag file already exists at: %@", kFlagFilePath);
        return;
    }

    // Create the flag file
    NSString *content = [NSString stringWithFormat:@"WiFi network '%@' detected at %@", kTargetSSID, [NSDate date]];
    NSError *error = nil;
    BOOL success = [content writeToFile:kFlagFilePath atomically:YES encoding:NSUTF8StringEncoding error:&error];

    if (success) {
        LOG(@"Successfully created flag file at: %@", kFlagFilePath);
    } else {
        LOG(@"Failed to create flag file: %@", error);
    }
}

static void scan_callback(WiFiDeviceClientRef device, CFArrayRef results, CFErrorRef error, int token) {
    if (error) {
        LOG(@"Scan error: %@", (__bridge NSError *)error);
        g_scanComplete = YES;
        CFRunLoopStop(CFRunLoopGetCurrent());
        return;
    }

    if (!results) {
        LOG(@"No scan results");
        g_scanComplete = YES;
        CFRunLoopStop(CFRunLoopGetCurrent());
        return;
    }

    NSArray *networks = (__bridge NSArray *)results;
    LOG(@"Scanned %lu nearby networks", (unsigned long)[networks count]);

    for (id networkObj in networks) {
        WiFiNetworkRef network = (__bridge WiFiNetworkRef)networkObj;
        CFStringRef ssidRef = WiFiNetworkGetSSID(network);

        if (ssidRef) {
            NSString *ssid = (__bridge NSString *)ssidRef;
            LOG(@"  Found: %@", ssid);

            // Case-insensitive substring search
            NSRange range = [ssid rangeOfString:kTargetSSID options:NSCaseInsensitiveSearch];
            if (range.location != NSNotFound) {
                LOG(@"TARGET NETWORK FOUND: %@ (contains '%@')", ssid, kTargetSSID);
                g_networkFound = YES;
                break;
            }
        }
    }

    g_scanComplete = YES;
    CFRunLoopStop(CFRunLoopGetCurrent());
}

- (BOOL)scanForTargetNetwork {
    // Initialize WiFi manager if needed
    if (!g_manager) {
        g_manager = WiFiManagerClientCreate(kCFAllocatorDefault, 0);
        if (!g_manager) {
            LOG(@"ERROR: Failed to create WiFiManager");
            return NO;
        }

        // Get WiFi device
        CFArrayRef devices = WiFiManagerClientCopyDevices(g_manager);
        if (!devices || CFArrayGetCount(devices) == 0) {
            LOG(@"ERROR: No WiFi devices found");
            if (devices) CFRelease(devices);
            return NO;
        }

        g_device = (WiFiDeviceClientRef)CFArrayGetValueAtIndex(devices, 0);
        CFRetain(g_device);
        CFRelease(devices);

        // Schedule with run loop
        WiFiManagerClientScheduleWithRunLoop(g_manager, CFRunLoopGetMain(), kCFRunLoopCommonModes);
        LOG(@"WiFi manager initialized");
    }

    // Reset scan state
    g_scanComplete = NO;
    g_networkFound = NO;

    // Trigger scan
    LOG(@"Initiating WiFi scan...");
    WiFiDeviceClientScanAsync(g_device, (__bridge CFDictionaryRef)@{}, (void *)scan_callback, 0);

    // Wait for scan to complete (with timeout)
    CFRunLoopRunInMode(kCFRunLoopDefaultMode, 10.0, false);

    // Create flag file if network was found
    if (g_networkFound) {
        [self createFlagFile];
    }

    return g_networkFound;
}

- (void)run {
    LOG(@"WiFiHook Daemon v1.0.0 starting...");
    LOG(@"Target SSID: %@", kTargetSSID);
    LOG(@"Flag file path: %@", kFlagFilePath);
    LOG(@"Scan interval: %.0f seconds", kScanInterval);
    LOG(@"Sleep interval: %.0f seconds (when flag exists)", kSleepInterval);

    // Main loop - runs forever
    while (YES) {
        @autoreleasepool {
            // Check if flag file exists
            if ([self flagFileExists]) {
                // Flag exists - sleep mode
                LOG(@"Flag file exists - sleeping for %.0f seconds...", kSleepInterval);
                [NSThread sleepForTimeInterval:kSleepInterval];
            } else {
                // Flag doesn't exist - scanning mode
                LOG(@"Scanning for network '%@'...", kTargetSSID);
                [self scanForTargetNetwork];

                // Sleep before next scan
                [NSThread sleepForTimeInterval:kScanInterval];
            }
        }
    }
}

@end

int main(int argc, char *argv[]) {
    @autoreleasepool {
        WiFiHook *hook = [[WiFiHook alloc] init];
        [hook run];
    }

    return 0;
}
