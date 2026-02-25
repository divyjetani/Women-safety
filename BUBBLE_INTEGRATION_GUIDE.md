# Flutter Bubble Member System - Integration Guide

## Overview
This Flutter bubble system allows users to:
- ✅ Create safety bubbles with 6-digit invite codes
- ✅ Join bubbles using the 6-digit code
- ✅ Real-time location sharing with bubble members
- ✅ View member locations on a map with battery percentage
- ✅ Automatic location and battery updates via WebSocket

## Features Implemented

### 1. Models (`lib/models/bubble_model.dart`)
- **BubbleMember**: Represents a member with location, battery status
- **Bubble**: Main bubble model with 6-digit code, name, members, etc.

### 2. Services

#### BubbleAPI (`lib/services/bubble_api.dart`)
REST API service for bubble operations:
- `createBubble()` - Create new bubble with 6-digit code
- `joinBubble()` - Join bubble using code
- `getBubble()` - Fetch bubble details
- `getUserBubbles()` - Get all bubbles for user
- `shareLocation()` - Share location to bubbles
- `deleteBubble()` - Delete bubble (admin only)

#### BubbleWebSocketService (`lib/services/bubble_websocket_service.dart`)
Real-time location sharing via WebSocket:
- `connect()` - Connect to bubble WebSocket
- `shareLocation()` - Send location updates
- `disconnect()` - Graceful disconnect
- Callbacks for: `onLocationUpdate`, `onBubbleInfo`, `onError`, `onConnectionChanged`

### 3. Providers (`lib/providers/bubble_provider.dart`)
State management using Provider package:
- Manages bubble list and current bubble
- Handles create/join/delete operations
- Loading and error states

### 4. Screens

#### BubblesListScreen (`lib/screens/bubbles_list_screen.dart`)
Main screen showing all user's bubbles:
- List of all bubbles with member count
- Join/Create floating action buttons
- Admin delete functionality
- Real-time member display with battery %
- Pull-to-refresh

#### CreateBubbleScreen (`lib/screens/create_bubble_screen.dart`)
Create new bubble:
- Enter bubble name
- Select icon (6 options)
- Select color theme
- Auto-generates 6-digit code
- Shows invite code to share

#### JoinBubbleScreen (`lib/screens/join_bubble_screen.dart`)
Join existing bubble:
- 6-digit code input field
- Validation
- Success/error messages
- Link to create new bubble

#### BubbleMembersScreen (`lib/screens/bubble_members_screen.dart`)
Real-time member location tracking:
- Interactive map with member locations
- Member markers with battery status color-coded
- Member list with battery percentage
- Location sharing toggle
- Auto-updates via WebSocket
- Periodic location sharing (every 10 seconds)
- Battery monitoring

## Integration Steps

### Step 1: Add Provider to Main App
In `lib/main.dart`:
```dart
import 'package:provider/provider.dart';
import 'package:mobile/providers/bubble_provider.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => BubbleProvider()),
        // ... other providers
      ],
      child: const MyApp(),
    ),
  );
}
```

### Step 2: Add Navigation Routes
In your app router/navigation:
```dart
'/bubbles': (context) => const BubblesListScreen(),
'/create-bubble': (context) => const CreateBubbleScreen(),
'/join-bubble': (context) => const JoinBubbleScreen(),
'/bubble-members/:code': (context) => BubbleMembersScreen(
  initialBubble: context.read<BubbleProvider>().currentBubble!,
),
```

### Step 3: Add to Main Menu/Sidebar
Add a link to bubbles in your main navigation or as a new menu item.

### Step 4: Update Authentication
Replace placeholder user IDs in:
- `bubble_api.dart` - `createBubble()` and `joinBubble()`
- `bubble_members_screen.dart` - WebSocket connection
- `bubble_provider.dart` - `_userId`

Example:
```dart
// Get userId from auth service
final authService = context.read<AuthService>();
final userId = authService.currentUser?.id ?? 1;
bubbleProvider.setUserId(userId);
```

### Step 5: Update Backend URL
Ensure `lib/conn_url.dart` has correct backend URL:
```dart
class ApiUrls {
  static const String baseUrl = 'http://YOUR_BACKEND_IP:8000';
}
```

## Backend API Endpoints

All endpoints are already implemented in the backend. See `App/backend/routes/bubble.py`:

### Endpoints
- `POST /bubble/create` - Create bubble
- `POST /bubble/join` - Join bubble
- `GET /bubble/list/{user_id}` - Get user bubbles
- `GET /bubble/{code}` - Get bubble details
- `POST /bubble/share-location` - Share location
- `DELETE /bubble/{code}` - Delete bubble
- `WS /ws/bubble/{code}/{user_id}` - WebSocket for real-time location

## Database Collections

Bubbles are stored in MongoDB with schema:
```javascript
{
  code: "XXXXXX",           // 6-digit code
  name: "string",
  icon: 0-5,              // Icon index
  color: 0xFFxxxxxx,      // Color value
  admin_id: number,
  members: [
    {
      user_id: number,
      name: "string",
      lat: number,
      lng: number,
      battery: 0-100,
      joined_at: "ISO8601",
      last_updated: timestamp
    }
  ],
  created_at: "ISO8601"
}
```

## Location & Battery Tracking

### Location Updates
- Uses `geolocator` plugin for GPS
- Updates every 10 seconds when sharing enabled
- Sent via WebSocket to other members
- Requires location permission

### Battery Monitoring
- Uses `battery_plus` plugin
- Displayed as percentage (0-100)
- Color-coded in UI:
  - Green: >= 50%
  - Orange: 20-49%
  - Red: < 20%
- Updates every 30 seconds
- Shown in member list and map markers

## Permissions Required

Add to `AndroidManifest.xml`:
```xml
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.BATTERY" />
```

Add to `Info.plist` (iOS):
```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>We need access to your location to share it with bubble members</string>
<key>NSBatteryLevelDidChangeNotification</key>
<true/>
```

## Testing

### Create Bubble Test
1. Navigate to BubblesListScreen
2. Click "Create Bubble"
3. Fill in name and select options
4. Note the 6-digit code shown
5. Should appear in bubbles list

### Join Bubble Test
1. Click "Join Bubble"
2. Enter the 6-digit code
3. Should see the bubble in list and open members screen
4. Location should update automatically

### Location Sharing Test
1. Open bubble members screen
2. Toggle location sharing on
3. Should see map with your location (blue marker)
4. Invite another user to join
5. Should see their location as they share it

## Troubleshooting

### WebSocket Connection Issues
- Ensure backend is running
- Check `conn_url.dart` backend URL
- Check backend WebSocket endpoint in `routes/websocket.py`
- Verify firewall allows WebSocket connections

### Location Permission Issues
- Grant location permission when prompted
- Check AndroidManifest.xml and Info.plist
- Use `permission_handler` for explicit requests

### Battery Not Updating
- Some devices require background battery service
- Check `battery_plus` plugin documentation
- May need to grant additional permissions

### Member Locations Not Appearing
- Ensure other members have location sharing enabled
- Check WebSocket connection is active (watch logs)
- Verify map is loading (check MapLayer configuration)

## Future Enhancements

1. **Push Notifications** - Notify members of location updates
2. **Geofencing** - Alert when members leave safe zones
3. **SOS Quick Share** - Emergency location to specific members
4. **Message Encryption** - End-to-end encrypted messages
5. **Offline Support** - Store location cache locally
6. **Analytics** - Track movement patterns and safety metrics
7. **Family Icons** - Custom avatars for members
8. **Schedule Sharing** - Automatic sharing during specific hours
