# Quick Reference & Code Examples

## 🚀 Quick Integration (Copy-Paste)

### 1. Add to main.dart
```dart
import 'package:provider/provider.dart';
import 'package:mobile/providers/bubble_provider.dart';

Future<void> main() async {
  runApp(
    MultiProvider(
      providers: [
        // ... existing providers
        ChangeNotifierProvider(create: (_) => BubbleProvider()),
      ],
      child: const MyApp(),
    ),
  );
}
```

### 2. Add to Routes/Navigation
```dart
// In your router setup:
routes: {
  '/bubbles': (context) => const BubblesListScreen(),
  '/create-bubble': (context) => const CreateBubbleScreen(),
  '/join-bubble': (context) => const JoinBubbleScreen(),
},

// Or with named route handling:
case '/bubbles':
  return MaterialPageRoute(builder: (context) => const BubblesListScreen());
```

### 3. Add Menu Item to Sidebar/Navigation
```dart
// In your navigation drawer/sidebar:
ListTile(
  leading: const Icon(Icons.bubble_chart),
  title: const Text('Safety Bubbles'),
  onTap: () {
    Navigator.pushNamed(context, '/bubbles');
  },
),
```

### 4. Get User ID from Auth (Example)
```dart
import 'package:mobile/providers/bubble_provider.dart';

// In your auth/login screen after login:
Future<void> _setupBubbleProvider(int userId, String userName) {
  final provider = context.read<BubbleProvider>();
  provider.setUserId(userId);
  // Username is passed per request
}

// Replace placeholder in bubble_api.dart:
static Future<Bubble> createBubble({
  required String name,
  required int icon,
  required int color,
  required int adminId,        // ← Use actual user ID
  required String adminName,   // ← Use actual user name
}) async {
  // ...
}
```

### 5. Update Backend URL
```dart
// In lib/conn_url.dart:
class ApiUrls {
  // For development:
  static const String baseUrl = 'http://192.168.1.100:8000';
  
  // For production:
  // static const String baseUrl = 'https://api.yourbackend.com';
}
```

### 6. Add Permissions

**Android** (android/app/src/main/AndroidManifest.xml):
```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
  <!-- Location -->
  <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
  <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
  
  <!-- Network -->
  <uses-permission android:name="android.permission.INTERNET" />
  
  <!-- Battery -->
  <uses-permission android:name="android.permission.BATTERY_STATS" />
  <uses-permission android:name="android.permission.READ_BATTERY_STATS" />

  <application>
    <!-- ... -->
  </application>
</manifest>
```

**iOS** (ios/Runner/Info.plist):
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" ...>
<plist version="1.0">
<dict>
  <!-- Location Usage -->
  <key>NSLocationWhenInUseUsageDescription</key>
  <string>We need access to your location to share it with bubble members for safety</string>
  
  <key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
  <string>We need access to your location to share it with bubble members for safety</string>
  
  <!-- Battery -->
  <key>UIDeviceBatteryLevelDidChangeNotification</key>
  <true/>
  
  <!-- Network -->
  <key>NSBonjourServices</key>
  <array>
    <string>_http._tcp</string>
    <string>_ws._tcp</string>
  </array>

  <!-- ... rest of plist -->
</dict>
</plist>
```

---

## 📋 API Usage Examples

### Create Bubble
```dart
// From Your Screen
final bubble = await BubbleAPI.createBubble(
  name: 'Campus Safety',
  icon: 0,           // 🛡️
  color: 0xFFFF1744, // Red
  adminId: userId,
  adminName: userName,
);

print('Created! Code: ${bubble.code}');
// Output: Created! Code: ABCDEF
```

### Join Bubble
```dart
try {
  final bubble = await BubbleAPI.joinBubble(
    code: 'ABCDEF',
    userId: userId,
    userName: userName,
  );
  print('Joined ${bubble.name}!');
  
  // Navigate to members screen
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => BubbleMembersScreen(initialBubble: bubble),
    ),
  );
} catch (e) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Error: $e')),
  );
}
```

### Get All User Bubbles
```dart
// Automatically done by BubbleProvider.fetchUserBubbles()
// Or manually:
final bubbles = await BubbleAPI.getUserBubbles(userId);
print('Found ${bubbles.length} bubbles');

// bubbles = [
//   Bubble(code: 'ABCDEF', name: 'Campus Safety', members: [...]),
//   Bubble(code: 'GHIJKL', name: 'Family Watch', members: [...]),
// ]
```

### Share Location
```dart
// From BubbleMembersScreen (automatic every 10 seconds)
// Or manually:
await BubbleAPI.shareLocation(
  userId: userId,
  lat: 40.7128,
  lng: -74.0060,
  battery: 85,
  incognito: false,
);
```

### Delete Bubble (Admin Only)
```dart
try {
  await BubbleAPI.deleteBubble(
    code: 'ABCDEF',
    adminId: userId, // Must be bubble admin
  );
  print('Bubble deleted!');
} catch (e) {
  print('Error: $e');
}
```

---

## 🔌 WebSocket Usage Examples

### Connect to Bubble
```dart
final wsService = BubbleWebSocketService(
  bubbleCode: 'ABCDEF',
  userId: userId,
);

// Set up callbacks BEFORE connecting
wsService.onLocationUpdate = (members) {
  setState(() => _members = members);
  _updateMapMarkers();
};

wsService.onBubbleInfo = (bubble) {
  setState(() => _bubble = bubble);
};

wsService.onError = (error) {
  print('Error: $error');
};

wsService.onConnectionChanged = (connected) {
  print(connected ? 'Connected' : 'Disconnected');
};

// Connect
try {
  await wsService.connect();
  print('✅ WebSocket connected!');
} catch (e) {
  print('❌ Connection failed: $e');
}
```

### Share Location via WebSocket
```dart
wsService.shareLocation(
  lat: currentPosition.latitude,
  lng: currentPosition.longitude,
  battery: batteryLevel,
);
```

### Keep Connection Alive
```dart
// Send ping every 30 seconds
Timer.periodic(Duration(seconds: 30), (_) {
  if (wsService.isConnected) {
    wsService.sendPing();
  }
});
```

### Disconnect
```dart
await wsService.disconnect();
print('Disconnected from WebSocket');
```

### Listen to Real-time Updates
```dart
// In BubbleMembersScreen initState:

_wsService.onLocationUpdate = (members) {
  // Update UI with new member locations
  setState(() {
    _members = members;
  });
  
  // Optionally update map
  setState(() {
    _updateMapMarkers();
  });
  
  // Log
  print('📍 Location update: ${members.length} members');
};

_wsService.onError = (error) {
  // Show error to user
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('Error: $error'),
      backgroundColor: Colors.red,
    ),
  );
};
```

---

## 🔪 Backend API Responses

### POST /bubble/create - Response
```json
{
  "success": true,
  "bubble": {
    "code": "ABCDEF",
    "name": "Campus Safety",
    "icon": 0,
    "color": 16713540,
    "admin_id": 1,
    "members": [
      {
        "user_id": 1,
        "name": "Alice",
        "lat": null,
        "lng": null,
        "battery": 100,
        "joined_at": "2026-02-25T10:30:00Z"
      }
    ],
    "created_at": "2026-02-25T10:30:00Z"
  },
  "code": "ABCDEF",
  "message": "Bubble created successfully"
}
```

### POST /bubble/join - Response
```json
{
  "success": true,
  "bubble": {
    "code": "ABCDEF",
    "name": "Campus Safety",
    "members": [
      {
        "user_id": 1,
        "name": "Alice",
        "lat": 40.7128,
        "lng": -74.0060,
        "battery": 85,
        "joined_at": "2026-02-25T10:30:00Z"
      },
      {
        "user_id": 2,
        "name": "Bob",
        "lat": null,
        "lng": null,
        "battery": 100,
        "joined_at": "2026-02-25T10:35:00Z"
      }
    ]
  },
  "message": "Joined bubble successfully"
}
```

### WebSocket Messages

**Incoming - bubble_info (on connect):**
```json
{
  "type": "bubble_info",
  "bubble": {
    "code": "ABCDEF",
    "name": "Campus Safety",
    "members": [...]
  }
}
```

**Incoming - location_update:**
```json
{
  "type": "location_update",
  "data": {
    "user_id": 2,
    "lat": 40.7130,
    "lng": -74.0061,
    "battery": 82,
    "members": [...]
  }
}
```

**Outgoing - location_update:**
```json
{
  "type": "location_update",
  "lat": 40.7128,
  "lng": -74.0060,
  "battery": 85
}
```

---

## 🎨 UI Component Examples

### Battery Color (Reusable Function)
```dart
Color _getBatteryColor(int battery) {
  if (battery >= 50) return Colors.green;
  if (battery >= 20) return Colors.orange;
  return Colors.red;
}

// Usage
Color color = _getBatteryColor(member.battery);
Icon(
  _getBatteryIcon(member.battery),
  color: color,
)
```

### Battery Icon (Reusable Function)
```dart
IconData _getBatteryIcon(int battery) {
  if (battery >= 75) return Icons.battery_full;
  if (battery >= 50) return Icons.battery_6_bar;
  if (battery >= 25) return Icons.battery_3_bar;
  return Icons.battery_1_bar;
}
```

### Member Card Widget
```dart
Widget _buildMemberCard(BubbleMember member) {
  return Container(
    margin: const EdgeInsets.only(right: 12),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFF151B23),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: member.lat != null ? Colors.green : Colors.grey,
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: member.lat != null ? Colors.green : Colors.grey,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                member.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(
              _getBatteryIcon(member.battery),
              size: 16,
              color: _getBatteryColor(member.battery),
            ),
            const SizedBox(width: 4),
            Text(
              '${member.battery}%',
              style: TextStyle(
                color: _getBatteryColor(member.battery),
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ],
    ),
  );
}
```

---

## ⚠️ Error Handling Examples

### Try-Catch for API Calls
```dart
try {
  final bubble = await BubbleAPI.joinBubble(
    code: code,
    userId: userId,
    userName: userName,
  );
  // Success
} on SocketException {
  setState(() => _error = 'No internet connection');
} on TimeoutException {
  setState(() => _error = 'Request timed out');
} catch (e) {
  setState(() => _error = 'Error: ${e.toString()}');
}
```

### WebSocket Error Handling
```dart
_wsService.onError = (error) {
  if (error.contains('Connection refused')) {
    print('Backend not reachable');
  } else if (error.contains('Timeout')) {
    print('Connection timeout');
  } else if (error.contains('404')) {
    print('Bubble not found');
  }
};
```

### Location Permission Handling
```dart
import 'package:geolocator/geolocator.dart';

Future<void> _requestLocationPermission() async {
  final status = await Geolocator.requestPermission();
  
  if (status == LocationPermission.denied) {
    setState(() => _error = 'Location permission denied');
  } else if (status == LocationPermission.deniedForever) {
    setState(() => _error = 'Location permission permanently denied. Open settings.');
    await openAppSettings();
  } else if (status == LocationPermission.whileInUse ||
             status == LocationPermission.always) {
    // Permission granted
    _updateLocation();
  }
}
```

---

## 🧪 Testing Checklist

- [ ] Create bubble → See 6-digit code
- [ ] Copy code → Join on another device
- [ ] Both see each other in members list
- [ ] Server shows both in bubble members
- [ ] Location markers appear on map
- [ ] Battery % displays on markers
- [ ] Disable location → Icons change color
- [ ] Enable location → Markers update
- [ ] Navigate map → Markers track movement
- [ ] Toggle sharing on/off → Status changes
- [ ] Battery updates → Percentage decreases
- [ ] Close app → Reconnect → Shows correct data
- [ ] Admin delete → Removes bubble for all
- [ ] Join invalid code → Error message

---

## 📚 Reference Links

- [Flutter geolocator](https://pub.dev/packages/geolocator)
- [Flutter battery_plus](https://pub.dev/packages/battery_plus)
- [Flutter flutter_map](https://pub.dev/packages/flutter_map)
- [Web Socket Channel](https://pub.dev/packages/web_socket_channel)
- [Provider State Management](https://pub.dev/packages/provider)
- [FastAPI WebSocket Docs](https://fastapi.tiangolo.com/advanced/websockets/)

---

✅ **Everything Ready to Use!**
