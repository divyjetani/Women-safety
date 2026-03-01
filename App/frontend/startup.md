# to start app

from capstone root folder
1. cd app/backend  
2. python main.py

3. open new terminal
4. cd app/frontend/web
5. npm run dev

# to change ip

1. go to terminal
2. ipconfig
3. copy ip of "Wireless LAN adapter Wi-Fi IPv4 Address"
3. replace in App/frontend/mobile/lib/conn_url.dart
4. App/frontend/mobile/android/app/src/main/kotlin/com/example/mobile/
        - LocationSharingService.kt : line 156
        - SafetySocket.kt : line 60
