# ✅ Background Location Sharing Implementation

## Overview
The app now supports background location sharing when closed. Location updates continue to be sent to the safety bubble every 5 seconds, even when the app is minimized or closed.

## Features Implemented

### 1. **Android Background Service**
- `LocationSharingService.kt` - Runs as a foreground service
- Requests location updates every 5 seconds
- Posts location to backend via HTTP endpoint
- Respects incognito mode setting

### 2. **Permissions Required**
- ✅ `ACCESS_FINE_LOCATION` - For high-accuracy GPS
- ✅ `ACCESS_COARSE_LOCATION` - Fallback location
- ✅ `FOREGROUND_SERVICE` - To run in background
- ✅ `FOREGROUND_SERVICE_LOCATION` - For location service specifically

### 3. **Dart Integration**
- `BackgroundLocationService` class manages Android service calls
- `startBackgroundLocationSharing()` - Starts the service with bubble code
- `stopBackgroundLocationSharing()` - Stops the service
- `setIncognitoMode()` - Updates incognito status without restarting

### 4. **Map Screen Integration**
- Calls `_startLocationSharing()` when a group is selected/created/joined
- Passes bubble code and user ID to background service
- Incognito toggle updates background service in real-time
- WebSocket sharing continues while app is open
- Background sharing continues even when app is closed

## How It Works

### When User Selects/Creates/Joins a Bubble
1. `_startLocationSharing()` is called in map_screen.dart
2. WebSocket connection starts (for real-time updates)
3. Background service is started with bubble code and user ID
4. SharedPreferences stores: `selected_bubble_code`, `user_id`, `incognito_mode`

### While App is Running
- **Foreground**: WebSocket sends location updates every 5 seconds
- **Background**: Background service also sends location every 5 seconds
- Both work simultaneously for redundancy

### When App is Closed
- WebSocket closes
- **Background service continues running** and keeps sharing location
- Shows persistent notification with "Location sharing active" status
- User can tap "Stop" on notification to stop sharing

### Incognito Mode
- Toggle in UI updates both WebSocket and background service
- When enabled: location is NOT shared to the bubble
- When incognito is ON for background service: it simply skips sending location

## Configuration for Production

### ⚠️ Important: Backend URL Configuration

The current implementation uses `http://10.0.2.2:8000` which is:
- ✅ Correct for Android emulator (maps to localhost)
- ❌ Wrong for physical Android devices

**For Physical Devices**, you need to:
1. Update the URL in `LocationSharingService.kt` line ~159
2. Use your actual backend IP/domain instead of `10.0.2.2`

Example:
```kotlin
val url = "http://192.168.1.100:8000/bubble/share-location"  // Real device
// or
val url = "https://api.yourdomain.com/bubble/share-location"  // Production
```

### Configuration Strategy
Consider adding a configuration file or environment variable to set the backend URL dynamically rather than hardcoding it.

## Notification Display
- Service shows a foreground notification so Android doesn't kill it
- Title: "Safety Bubble"
- Subtitle: "Location sharing active"
- Action button to stop the service

## API Endpoint
The background service uses the existing `/bubble/share-location` endpoint which expects:
```json
{
  "user_id": 123,
  "lat": 23.6145,
  "lng": 72.2098,
  "battery": 85,
  "incognito": false
}
```

## Stopping Background Sharing
The service is stopped when:
1. User taps "Stop" on the notification
2. User leaves the bubble (app-side logic needed)
3. System kills the service (unlikely while in foreground)

## Testing Checklist
- [ ] Create/join a bubble
- [ ] Close the app
- [ ] Check if location is still being updated on other devices
- [ ] Toggle incognito mode - verify location stops sharing
- [ ] Tap "Stop" on notification - verify location sharing stops
- [ ] Check that foreground notification is visible
- [ ] Verify battery percentage is correctly sent
- [ ] Test on actual device (not emulator) with correct backend URL

## Future Improvements
1. Make backend URL configurable via app settings
2. Add user preference toggle for background location sharing
3. Add logging/stats about background service activity
4. Implement graceful shutdown when low on battery
5. Add geofencing to optimize location updates based on distance
