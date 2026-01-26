// import 'package:flutter/material.dart';
//
// void main() {
//   runApp(const SafeGuardApp());
// }
//
// class SafeGuardApp extends StatelessWidget {
//   const SafeGuardApp({Key? key}) : super(key: key);
//
//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       title: 'She Raksha',
//       debugShowCheckedModeBanner: false,
//       theme: ThemeData(
//         primarySwatch: Colors.purple,
//         fontFamily: 'SF Pro',
//       ),
//       home: const MainScreen(),
//     );
//   }
// }
//
// class MainScreen extends StatefulWidget {
//   const MainScreen({Key? key}) : super(key: key);
//
//   @override
//   State<MainScreen> createState() => _MainScreenState();
// }
//
// class _MainScreenState extends State<MainScreen> {
//   int _selectedIndex = 0;
//   bool nightMode = false;
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       body: IndexedStack(
//         index: _selectedIndex,
//         children: [
//           const HomeScreen(),
//           const MapScreen(),
//           const AnalyticsScreen(),
//           ProfileScreen(
//             nightMode: nightMode,
//             onNightModeChanged: (value) {
//               setState(() {
//                 nightMode = value;
//               });
//             },
//           ),
//         ],
//       ),
//       bottomNavigationBar: BottomNavigationBar(
//         currentIndex: _selectedIndex,
//         onTap: (index) {
//           setState(() {
//             _selectedIndex = index;
//           });
//         },
//         type: BottomNavigationBarType.fixed,
//         selectedItemColor: Colors.purple,
//         unselectedItemColor: Colors.grey,
//         selectedFontSize: 12,
//         unselectedFontSize: 12,
//         items: const [
//           BottomNavigationBarItem(
//             icon: Icon(Icons.home),
//             label: 'Home',
//           ),
//           BottomNavigationBarItem(
//             icon: Icon(Icons.map),
//             label: 'Map',
//           ),
//           BottomNavigationBarItem(
//             icon: Icon(Icons.bar_chart),
//             label: 'Analytics',
//           ),
//           BottomNavigationBarItem(
//             icon: Icon(Icons.person),
//             label: 'Profile',
//           ),
//         ],
//       ),
//     );
//   }
// }
//
// // Home Screen
// class HomeScreen extends StatelessWidget {
//   const HomeScreen({Key? key}) : super(key: key);
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Colors.grey[50],
//       body: SafeArea(
//         child: SingleChildScrollView(
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               // Header
//               Container(
//                 color: Colors.white,
//                 padding: const EdgeInsets.all(24),
//                 child: Column(
//                   children: [
//                     Row(
//                       mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                       children: [
//                         const Text(
//                           'She Raksha',
//                           style: TextStyle(
//                             fontSize: 28,
//                             fontWeight: FontWeight.bold,
//                           ),
//                         ),
//                         Icon(Icons.notifications_outlined,
//                             color: Colors.purple.shade600, size: 28),
//                       ],
//                     ),
//                     const SizedBox(height: 24),
//
//                     // Emergency SOS Button
//                     Container(
//                       decoration: BoxDecoration(
//                         gradient: LinearGradient(
//                           colors: [Colors.red.shade500, Colors.pink.shade400],
//                         ),
//                         borderRadius: BorderRadius.circular(20),
//                       ),
//                       padding: const EdgeInsets.all(24),
//                       child: const Column(
//                         children: [
//                           Icon(Icons.shield, color: Colors.white, size: 40),
//                           SizedBox(height: 8),
//                           Text(
//                             'Emergency SOS',
//                             style: TextStyle(
//                               color: Colors.white,
//                               fontSize: 22,
//                               fontWeight: FontWeight.bold,
//                             ),
//                           ),
//                           SizedBox(height: 4),
//                           Text(
//                             'Press & Hold for 3 seconds',
//                             style: TextStyle(
//                               color: Colors.white,
//                               fontSize: 14,
//                             ),
//                           ),
//                         ],
//                       ),
//                     ),
//                     const SizedBox(height: 16),
//
//                     // Safety Score
//                     Container(
//                       decoration: BoxDecoration(
//                         gradient: LinearGradient(
//                           colors: [Colors.purple.shade600, Colors.purple.shade700],
//                         ),
//                         borderRadius: BorderRadius.circular(20),
//                       ),
//                       padding: const EdgeInsets.all(24),
//                       child: Column(
//                         children: [
//                           Row(
//                             mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                             children: [
//                               const Column(
//                                 crossAxisAlignment: CrossAxisAlignment.start,
//                                 children: [
//                                   Text(
//                                     'Your Safety Score',
//                                     style: TextStyle(
//                                       color: Colors.white70,
//                                       fontSize: 14,
//                                     ),
//                                   ),
//                                   SizedBox(height: 4),
//                                   Row(
//                                     crossAxisAlignment: CrossAxisAlignment.baseline,
//                                     textBaseline: TextBaseline.alphabetic,
//                                     children: [
//                                       Text(
//                                         '92',
//                                         style: TextStyle(
//                                           color: Colors.white,
//                                           fontSize: 40,
//                                           fontWeight: FontWeight.bold,
//                                         ),
//                                       ),
//                                       Text(
//                                         '/100',
//                                         style: TextStyle(
//                                           color: Colors.white,
//                                           fontSize: 18,
//                                         ),
//                                       ),
//                                     ],
//                                   ),
//                                 ],
//                               ),
//                               const Icon(Icons.bar_chart,
//                                   color: Colors.white, size: 32),
//                             ],
//                           ),
//                           const SizedBox(height: 12),
//                           ClipRRect(
//                             borderRadius: BorderRadius.circular(10),
//                             child: LinearProgressIndicator(
//                               value: 0.92,
//                               backgroundColor: Colors.purple.shade400,
//                               valueColor: const AlwaysStoppedAnimation<Color>(
//                                 Colors.white,
//                               ),
//                               minHeight: 8,
//                             ),
//                           ),
//                           const SizedBox(height: 8),
//                           const Align(
//                             alignment: Alignment.centerRight,
//                             child: Text(
//                               'Excellent',
//                               style: TextStyle(
//                                 color: Colors.white,
//                                 fontSize: 14,
//                                 fontWeight: FontWeight.bold,
//                               ),
//                             ),
//                           ),
//                         ],
//                       ),
//                     ),
//                     const SizedBox(height: 16),
//
//                     // Stats Row
//                     Row(
//                       children: [
//                         Expanded(
//                           child: Container(
//                             decoration: BoxDecoration(
//                               color: Colors.white,
//                               border: Border.all(color: Colors.grey.shade200),
//                               borderRadius: BorderRadius.circular(16),
//                             ),
//                             padding: const EdgeInsets.all(16),
//                             child: Column(
//                               crossAxisAlignment: CrossAxisAlignment.start,
//                               children: [
//                                 Row(
//                                   children: [
//                                     Icon(Icons.location_on,
//                                         color: Colors.green.shade600, size: 20),
//                                     const SizedBox(width: 8),
//                                     Text(
//                                       'Safe Zones',
//                                       style: TextStyle(
//                                         color: Colors.grey.shade600,
//                                         fontSize: 14,
//                                       ),
//                                     ),
//                                   ],
//                                 ),
//                                 const SizedBox(height: 8),
//                                 const Text(
//                                   '12',
//                                   style: TextStyle(
//                                     fontSize: 28,
//                                     fontWeight: FontWeight.bold,
//                                   ),
//                                 ),
//                               ],
//                             ),
//                           ),
//                         ),
//                         const SizedBox(width: 16),
//                         Expanded(
//                           child: Container(
//                             decoration: BoxDecoration(
//                               color: Colors.white,
//                               border: Border.all(color: Colors.grey.shade200),
//                               borderRadius: BorderRadius.circular(16),
//                             ),
//                             padding: const EdgeInsets.all(16),
//                             child: Column(
//                               crossAxisAlignment: CrossAxisAlignment.start,
//                               children: [
//                                 Row(
//                                   children: [
//                                     Icon(Icons.warning_amber,
//                                         color: Colors.orange.shade600, size: 20),
//                                     const SizedBox(width: 8),
//                                     Text(
//                                       'Alerts Today',
//                                       style: TextStyle(
//                                         color: Colors.grey.shade600,
//                                         fontSize: 14,
//                                       ),
//                                     ),
//                                   ],
//                                 ),
//                                 const SizedBox(height: 8),
//                                 const Text(
//                                   '3',
//                                   style: TextStyle(
//                                     fontSize: 28,
//                                     fontWeight: FontWeight.bold,
//                                   ),
//                                 ),
//                               ],
//                             ),
//                           ),
//                         ),
//                       ],
//                     ),
//                   ],
//                 ),
//               ),
//               const SizedBox(height: 8),
//
//               // Quick Actions
//               Container(
//                 color: Colors.white,
//                 padding: const EdgeInsets.all(24),
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     const Text(
//                       'Quick Actions',
//                       style: TextStyle(
//                         fontSize: 20,
//                         fontWeight: FontWeight.bold,
//                       ),
//                     ),
//                     const SizedBox(height: 16),
//                     Container(
//                       decoration: BoxDecoration(
//                         color: Colors.blue.shade50,
//                         borderRadius: BorderRadius.circular(16),
//                       ),
//                       padding: const EdgeInsets.all(16),
//                       child: Row(
//                         children: [
//                           Container(
//                             padding: const EdgeInsets.all(12),
//                             decoration: BoxDecoration(
//                               color: Colors.blue.shade100,
//                               borderRadius: BorderRadius.circular(12),
//                             ),
//                             child: Icon(Icons.phone,
//                                 color: Colors.blue.shade600, size: 24),
//                           ),
//                           const SizedBox(width: 16),
//                           const Expanded(
//                             child: Column(
//                               crossAxisAlignment: CrossAxisAlignment.start,
//                               children: [
//                                 Text(
//                                   'Emergency Contacts',
//                                   style: TextStyle(
//                                     fontWeight: FontWeight.bold,
//                                     fontSize: 16,
//                                   ),
//                                 ),
//                                 SizedBox(height: 4),
//                                 Text(
//                                   '5 contacts added',
//                                   style: TextStyle(
//                                     color: Colors.grey,
//                                     fontSize: 14,
//                                   ),
//                                 ),
//                               ],
//                             ),
//                           ),
//                         ],
//                       ),
//                     ),
//                     const SizedBox(height: 12),
//                     Container(
//                       decoration: BoxDecoration(
//                         color: Colors.purple.shade50,
//                         borderRadius: BorderRadius.circular(16),
//                       ),
//                       padding: const EdgeInsets.all(16),
//                       child: Row(
//                         children: [
//                           Container(
//                             padding: const EdgeInsets.all(12),
//                             decoration: BoxDecoration(
//                               color: Colors.purple.shade100,
//                               borderRadius: BorderRadius.circular(12),
//                             ),
//                             child: Icon(Icons.location_on,
//                                 color: Colors.purple.shade600, size: 24),
//                           ),
//                           const SizedBox(width: 16),
//                           const Expanded(
//                             child: Column(
//                               crossAxisAlignment: CrossAxisAlignment.start,
//                               children: [
//                                 Text(
//                                   'Share Location',
//                                   style: TextStyle(
//                                     fontWeight: FontWeight.bold,
//                                     fontSize: 16,
//                                   ),
//                                 ),
//                                 SizedBox(height: 4),
//                                 Text(
//                                   'With trusted contacts',
//                                   style: TextStyle(
//                                     color: Colors.grey,
//                                     fontSize: 14,
//                                   ),
//                                 ),
//                               ],
//                             ),
//                           ),
//                         ],
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//               const SizedBox(height: 8),
//
//               // Recent Activity
//               Container(
//                 color: Colors.white,
//                 padding: const EdgeInsets.all(24),
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     const Text(
//                       'Recent Activity',
//                       style: TextStyle(
//                         fontSize: 20,
//                         fontWeight: FontWeight.bold,
//                       ),
//                     ),
//                     const SizedBox(height: 16),
//                     Row(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         Container(
//                           margin: const EdgeInsets.only(top: 6),
//                           width: 8,
//                           height: 8,
//                           decoration: BoxDecoration(
//                             color: Colors.green.shade500,
//                             shape: BoxShape.circle,
//                           ),
//                         ),
//                         const SizedBox(width: 12),
//                         const Expanded(
//                           child: Column(
//                             crossAxisAlignment: CrossAxisAlignment.start,
//                             children: [
//                               Text(
//                                 'Entered Safe Zone',
//                                 style: TextStyle(
//                                   fontWeight: FontWeight.bold,
//                                   fontSize: 16,
//                                 ),
//                               ),
//                               SizedBox(height: 4),
//                               Text(
//                                 'Himalaya Mall',
//                                 style: TextStyle(
//                                   color: Colors.grey,
//                                   fontSize: 14,
//                                 ),
//                               ),
//                               SizedBox(height: 4),
//                               Text(
//                                 '2 hours ago',
//                                 style: TextStyle(
//                                   color: Colors.grey,
//                                   fontSize: 12,
//                                 ),
//                               ),
//                             ],
//                           ),
//                         ),
//                       ],
//                     ),
//                   ],
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }
//
// // Map Screen
// class MapScreen extends StatelessWidget {
//   const MapScreen({Key? key}) : super(key: key);
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Colors.grey[50],
//       body: SafeArea(
//         child: SingleChildScrollView(
//           child: Container(
//             color: Colors.white,
//             padding: const EdgeInsets.all(24),
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Row(
//                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                   children: [
//                     const Text(
//                       'Threat Map',
//                       style: TextStyle(
//                         fontSize: 28,
//                         fontWeight: FontWeight.bold,
//                       ),
//                     ),
//                     Icon(Icons.navigation,
//                         color: Colors.purple.shade600, size: 28),
//                   ],
//                 ),
//                 const SizedBox(height: 16),
//
//                 // Search Bar
//                 Container(
//                   decoration: BoxDecoration(
//                     color: Colors.grey.shade100,
//                     borderRadius: BorderRadius.circular(16),
//                   ),
//                   padding: const EdgeInsets.symmetric(horizontal: 16),
//                   child: const TextField(
//                     decoration: InputDecoration(
//                       hintText: 'Search location...',
//                       border: InputBorder.none,
//                       icon: Icon(Icons.search, color: Colors.grey),
//                     ),
//                   ),
//                 ),
//                 const SizedBox(height: 16),
//
//                 // Current Location
//                 Container(
//                   decoration: BoxDecoration(
//                     color: Colors.green.shade50,
//                     border: Border.all(color: Colors.green.shade200),
//                     borderRadius: BorderRadius.circular(16),
//                   ),
//                   padding: const EdgeInsets.all(16),
//                   child: Row(
//                     children: [
//                       Icon(Icons.location_on,
//                           color: Colors.green.shade600, size: 20),
//                       const SizedBox(width: 12),
//                       const Expanded(
//                         child: Column(
//                           crossAxisAlignment: CrossAxisAlignment.start,
//                           children: [
//                             Text(
//                               'Current Location',
//                               style: TextStyle(
//                                 color: Colors.grey,
//                                 fontSize: 12,
//                               ),
//                             ),
//                             SizedBox(height: 2),
//                             Text(
//                               'Downtown, Safe Zone',
//                               style: TextStyle(
//                                 fontWeight: FontWeight.bold,
//                                 fontSize: 16,
//                               ),
//                             ),
//                           ],
//                         ),
//                       ),
//                       Container(
//                         padding: const EdgeInsets.symmetric(
//                           horizontal: 12,
//                           vertical: 6,
//                         ),
//                         decoration: BoxDecoration(
//                           color: Colors.green.shade500,
//                           borderRadius: BorderRadius.circular(20),
//                         ),
//                         child: const Text(
//                           'Safe',
//                           style: TextStyle(
//                             color: Colors.white,
//                             fontSize: 12,
//                             fontWeight: FontWeight.bold,
//                           ),
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//                 const SizedBox(height: 16),
//
//                 // Map
//                 Container(
//                   height: 320,
//                   decoration: BoxDecoration(
//                     color: Colors.grey.shade200,
//                     borderRadius: BorderRadius.circular(20),
//                   ),
//                   child: Stack(
//                     children: [
//                       // High Risk Area
//                       Positioned(
//                         top: 60,
//                         left: 60,
//                         child: Container(
//                           width: 80,
//                           height: 80,
//                           decoration: BoxDecoration(
//                             color: Colors.red.withOpacity(0.4),
//                             shape: BoxShape.circle,
//                           ),
//                           child: const Center(
//                             child: Text(
//                               'High Risk',
//                               style: TextStyle(
//                                 color: Colors.white,
//                                 fontSize: 10,
//                                 fontWeight: FontWeight.bold,
//                               ),
//                             ),
//                           ),
//                         ),
//                       ),
//                       // Safe Zone with Current Location
//                       Positioned(
//                         bottom: 60,
//                         left: 0,
//                         right: 0,
//                         child: Center(
//                           child: Column(
//                             children: [
//                               Stack(
//                                 alignment: Alignment.center,
//                                 children: [
//                                   Container(
//                                     width: 80,
//                                     height: 80,
//                                     decoration: BoxDecoration(
//                                       color: Colors.green.withOpacity(0.3),
//                                       shape: BoxShape.circle,
//                                     ),
//                                   ),
//                                   Container(
//                                     width: 64,
//                                     height: 64,
//                                     decoration: BoxDecoration(
//                                       color: Colors.orange.withOpacity(0.5),
//                                       shape: BoxShape.circle,
//                                     ),
//                                   ),
//                                   Container(
//                                     width: 48,
//                                     height: 48,
//                                     decoration: BoxDecoration(
//                                       color: Colors.green.withOpacity(0.6),
//                                       shape: BoxShape.circle,
//                                     ),
//                                   ),
//                                   Container(
//                                     width: 32,
//                                     height: 32,
//                                     decoration: const BoxDecoration(
//                                       color: Colors.blue,
//                                       shape: BoxShape.circle,
//                                     ),
//                                     child: Center(
//                                       child: Container(
//                                         width: 16,
//                                         height: 16,
//                                         decoration: const BoxDecoration(
//                                           color: Colors.white,
//                                           shape: BoxShape.circle,
//                                         ),
//                                       ),
//                                     ),
//                                   ),
//                                 ],
//                               ),
//                               const SizedBox(height: 8),
//                               const Text(
//                                 'Safe Zone',
//                                 style: TextStyle(
//                                   fontSize: 12,
//                                   fontWeight: FontWeight.bold,
//                                 ),
//                               ),
//                             ],
//                           ),
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//                 const SizedBox(height: 24),
//
//                 // Threat Levels Legend
//                 Container(
//                   decoration: BoxDecoration(
//                     border: Border.all(color: Colors.grey.shade200),
//                     borderRadius: BorderRadius.circular(16),
//                   ),
//                   padding: const EdgeInsets.all(16),
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       const Text(
//                         'Threat Levels',
//                         style: TextStyle(
//                           fontWeight: FontWeight.bold,
//                           fontSize: 16,
//                         ),
//                       ),
//                       const SizedBox(height: 16),
//                       _buildLegendItem(
//                         Colors.red.shade500,
//                         'High Risk - Avoid this area',
//                       ),
//                       const SizedBox(height: 12),
//                       _buildLegendItem(
//                         Colors.orange.shade500,
//                         'Medium Risk - Stay alert',
//                       ),
//                       const SizedBox(height: 12),
//                       _buildLegendItem(
//                         Colors.green.shade500,
//                         'Safe Zone - Well lit & monitored',
//                       ),
//                       const SizedBox(height: 12),
//                       _buildLegendItem(
//                         Colors.blue.shade600,
//                         'Your current location',
//                       ),
//                     ],
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         ),
//       ),
//     );
//   }
//
//   Widget _buildLegendItem(Color color, String text) {
//     return Row(
//       children: [
//         Container(
//           width: 12,
//           height: 12,
//           decoration: BoxDecoration(
//             color: color,
//             shape: BoxShape.circle,
//           ),
//         ),
//         const SizedBox(width: 12),
//         Expanded(
//           child: Text(
//             text,
//             style: const TextStyle(fontSize: 14),
//           ),
//         ),
//       ],
//     );
//   }
// }
//
// // Analytics Screen
// class AnalyticsScreen extends StatelessWidget {
//   const AnalyticsScreen({Key? key}) : super(key: key);
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Colors.grey[50],
//       body: SafeArea(
//         child: SingleChildScrollView(
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               // Header
//               Container(
//                 color: Colors.white,
//                 padding: const EdgeInsets.all(24),
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Row(
//                       mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                       children: [
//                         const Text(
//                           'Safety Analytics',
//                           style: TextStyle(
//                             fontSize: 28,
//                             fontWeight: FontWeight.bold,
//                           ),
//                         ),
//                         Icon(Icons.insights,
//                             color: Colors.purple.shade600, size: 32),
//                       ],
//                     ),
//                     const SizedBox(height: 8),
//                     const Text(
//                       'Track your safety patterns and threat detection',
//                       style: TextStyle(
//                         color: Colors.grey,
//                         fontSize: 14,
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//               const SizedBox(height: 8),
//
//               // Weekly Safety Score
//               Container(
//                 color: Colors.white,
//                 padding: const EdgeInsets.all(24),
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     const Text(
//                       'Weekly Safety Score',
//                       style: TextStyle(
//                         fontSize: 20,
//                         fontWeight: FontWeight.bold,
//                       ),
//                     ),
//                     const SizedBox(height: 16),
//                     Container(
//                       height: 200,
//                       child: Row(
//                         mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//                         crossAxisAlignment: CrossAxisAlignment.end,
//                         children: [
//                           _buildBarChartItem('Mon', 80, Colors.green.shade400),
//                           _buildBarChartItem('Tue', 75, Colors.orange.shade400),
//                           _buildBarChartItem('Wed', 92, Colors.green.shade400),
//                           _buildBarChartItem('Thu', 60, Colors.red.shade400),
//                           _buildBarChartItem('Fri', 85, Colors.green.shade400),
//                           _buildBarChartItem('Sat', 70, Colors.orange.shade400),
//                           _buildBarChartItem('Sun', 88, Colors.green.shade400),
//                         ],
//                       ),
//                     ),
//                     const SizedBox(height: 16),
//                     const Divider(),
//                     const SizedBox(height: 16),
//                     Row(
//                       mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                       children: [
//                         const Text(
//                           'Average Score',
//                           style: TextStyle(
//                             fontSize: 16,
//                             fontWeight: FontWeight.w500,
//                           ),
//                         ),
//                         Text(
//                           '78.6',
//                           style: TextStyle(
//                             fontSize: 24,
//                             fontWeight: FontWeight.bold,
//                             color: Colors.purple.shade600,
//                           ),
//                         ),
//                       ],
//                     ),
//                   ],
//                 ),
//               ),
//               const SizedBox(height: 8),
//
//               // Threat Detection Stats
//               Container(
//                 color: Colors.white,
//                 padding: const EdgeInsets.all(24),
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     const Text(
//                       'Threat Detection',
//                       style: TextStyle(
//                         fontSize: 20,
//                         fontWeight: FontWeight.bold,
//                       ),
//                     ),
//                     const SizedBox(height: 16),
//                     Row(
//                       children: [
//                         Expanded(
//                           child: Container(
//                             decoration: BoxDecoration(
//                               color: Colors.red.shade50,
//                               borderRadius: BorderRadius.circular(16),
//                               border: Border.all(color: Colors.red.shade100),
//                             ),
//                             padding: const EdgeInsets.all(16),
//                             child: Column(
//                               children: [
//                                 Container(
//                                   padding: const EdgeInsets.all(12),
//                                   decoration: BoxDecoration(
//                                     color: Colors.red.shade100,
//                                     shape: BoxShape.circle,
//                                   ),
//                                   child: Icon(Icons.warning,
//                                       color: Colors.red.shade600, size: 24),
//                                 ),
//                                 const SizedBox(height: 12),
//                                 const Text(
//                                   '12',
//                                   style: TextStyle(
//                                     fontSize: 28,
//                                     fontWeight: FontWeight.bold,
//                                   ),
//                                 ),
//                                 const SizedBox(height: 4),
//                                 const Text(
//                                   'High Threats',
//                                   style: TextStyle(
//                                     color: Colors.grey,
//                                     fontSize: 14,
//                                   ),
//                                 ),
//                               ],
//                             ),
//                           ),
//                         ),
//                         const SizedBox(width: 16),
//                         Expanded(
//                           child: Container(
//                             decoration: BoxDecoration(
//                               color: Colors.orange.shade50,
//                               borderRadius: BorderRadius.circular(16),
//                               border: Border.all(color: Colors.orange.shade100),
//                             ),
//                             padding: const EdgeInsets.all(16),
//                             child: Column(
//                               children: [
//                                 Container(
//                                   padding: const EdgeInsets.all(12),
//                                   decoration: BoxDecoration(
//                                     color: Colors.orange.shade100,
//                                     shape: BoxShape.circle,
//                                   ),
//                                   child: Icon(Icons.warning_amber,
//                                       color: Colors.orange.shade600, size: 24),
//                                 ),
//                                 const SizedBox(height: 12),
//                                 const Text(
//                                   '24',
//                                   style: TextStyle(
//                                     fontSize: 28,
//                                     fontWeight: FontWeight.bold,
//                                   ),
//                                 ),
//                                 const SizedBox(height: 4),
//                                 const Text(
//                                   'Medium Threats',
//                                   style: TextStyle(
//                                     color: Colors.grey,
//                                     fontSize: 14,
//                                   ),
//                                 ),
//                               ],
//                             ),
//                           ),
//                         ),
//                       ],
//                     ),
//                     const SizedBox(height: 16),
//                     Row(
//                       children: [
//                         Expanded(
//                           child: Container(
//                             decoration: BoxDecoration(
//                               color: Colors.blue.shade50,
//                               borderRadius: BorderRadius.circular(16),
//                               border: Border.all(color: Colors.blue.shade100),
//                             ),
//                             padding: const EdgeInsets.all(16),
//                             child: Column(
//                               children: [
//                                 Container(
//                                   padding: const EdgeInsets.all(12),
//                                   decoration: BoxDecoration(
//                                     color: Colors.blue.shade100,
//                                     shape: BoxShape.circle,
//                                   ),
//                                   child: Icon(Icons.shield,
//                                       color: Colors.blue.shade600, size: 24),
//                                 ),
//                                 const SizedBox(height: 12),
//                                 const Text(
//                                   '156',
//                                   style: TextStyle(
//                                     fontSize: 28,
//                                     fontWeight: FontWeight.bold,
//                                   ),
//                                 ),
//                                 const SizedBox(height: 4),
//                                 const Text(
//                                   'Safe Hours',
//                                   style: TextStyle(
//                                     color: Colors.grey,
//                                     fontSize: 14,
//                                   ),
//                                 ),
//                               ],
//                             ),
//                           ),
//                         ),
//                         const SizedBox(width: 16),
//                         Expanded(
//                           child: Container(
//                             decoration: BoxDecoration(
//                               color: Colors.green.shade50,
//                               borderRadius: BorderRadius.circular(16),
//                               border: Border.all(color: Colors.green.shade100),
//                             ),
//                             padding: const EdgeInsets.all(16),
//                             child: Column(
//                               children: [
//                                 Container(
//                                   padding: const EdgeInsets.all(12),
//                                   decoration: BoxDecoration(
//                                     color: Colors.green.shade100,
//                                     shape: BoxShape.circle,
//                                   ),
//                                   child: Icon(Icons.check_circle,
//                                       color: Colors.green.shade600, size: 24),
//                                 ),
//                                 const SizedBox(height: 12),
//                                 const Text(
//                                   '92%',
//                                   style: TextStyle(
//                                     fontSize: 28,
//                                     fontWeight: FontWeight.bold,
//                                   ),
//                                 ),
//                                 const SizedBox(height: 4),
//                                 const Text(
//                                   'Prevention Rate',
//                                   style: TextStyle(
//                                     color: Colors.grey,
//                                     fontSize: 14,
//                                   ),
//                                 ),
//                               ],
//                             ),
//                           ),
//                         ),
//                       ],
//                     ),
//                   ],
//                 ),
//               ),
//               const SizedBox(height: 8),
//
//               // Time-based Analysis
//               Container(
//                 color: Colors.white,
//                 padding: const EdgeInsets.all(24),
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     const Text(
//                       'Time-based Analysis',
//                       style: TextStyle(
//                         fontSize: 20,
//                         fontWeight: FontWeight.bold,
//                       ),
//                     ),
//                     const SizedBox(height: 16),
//                     const Text(
//                       'Most Common Threat Times',
//                       style: TextStyle(
//                         fontSize: 16,
//                         fontWeight: FontWeight.w500,
//                       ),
//                     ),
//                     const SizedBox(height: 12),
//                     _buildTimeSlotItem('6 PM - 9 PM', '45%', Colors.red.shade500),
//                     _buildTimeSlotItem('9 PM - 12 AM', '35%', Colors.orange.shade500),
//                     _buildTimeSlotItem('12 AM - 3 AM', '15%', Colors.red.shade700),
//                     _buildTimeSlotItem('3 AM - 6 AM', '5%', Colors.grey.shade500),
//                     const SizedBox(height: 16),
//                     const Divider(),
//                     const SizedBox(height: 16),
//                     const Text(
//                       'Safest Time to Travel',
//                       style: TextStyle(
//                         fontSize: 16,
//                         fontWeight: FontWeight.w500,
//                       ),
//                     ),
//                     const SizedBox(height: 12),
//                     Container(
//                       decoration: BoxDecoration(
//                         color: Colors.green.shade50,
//                         borderRadius: BorderRadius.circular(12),
//                       ),
//                       padding: const EdgeInsets.all(16),
//                       child: const Row(
//                         children: [
//                           Icon(Icons.lightbulb_outline,
//                               color: Colors.green, size: 24),
//                           SizedBox(width: 12),
//                           Expanded(
//                             child: Text(
//                               'Consider traveling between 10 AM - 4 PM when threat levels are lowest',
//                               style: TextStyle(
//                                 fontSize: 14,
//                               ),
//                             ),
//                           ),
//                         ],
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//               const SizedBox(height: 8),
//
//               // Location Safety Trends
//               Container(
//                 color: Colors.white,
//                 padding: const EdgeInsets.all(24),
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     const Text(
//                       'Location Safety Trends',
//                       style: TextStyle(
//                         fontSize: 20,
//                         fontWeight: FontWeight.bold,
//                       ),
//                     ),
//                     const SizedBox(height: 16),
//                     _buildLocationSafetyItem(
//                       'Downtown Mall',
//                       'High traffic, well-lit',
//                       Colors.green,
//                       95,
//                     ),
//                     _buildLocationSafetyItem(
//                       'Central Park',
//                       'Evenings are risky',
//                       Colors.orange,
//                       65,
//                     ),
//                     _buildLocationSafetyItem(
//                       'North Station',
//                       'Crowded, pickpocket area',
//                       Colors.red,
//                       45,
//                     ),
//                     _buildLocationSafetyItem(
//                       'University Campus',
//                       'Patrolled, emergency stations',
//                       Colors.green,
//                       90,
//                     ),
//                   ],
//                 ),
//               ),
//               const SizedBox(height: 8),
//
//               // Threat Prevention Tips
//               Container(
//                 color: Colors.white,
//                 padding: const EdgeInsets.all(24),
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     const Text(
//                       'Threat Prevention Tips',
//                       style: TextStyle(
//                         fontSize: 20,
//                         fontWeight: FontWeight.bold,
//                       ),
//                     ),
//                     const SizedBox(height: 16),
//                     _buildTipItem(
//                       Icons.share_location,
//                       'Share your live location with trusted contacts when traveling alone',
//                     ),
//                     _buildTipItem(
//                       Icons.phone,
//                       'Keep emergency contacts on speed dial',
//                     ),
//                     _buildTipItem(
//                       Icons.lightbulb_outline,
//                       'Avoid poorly lit areas after sunset',
//                     ),
//                     _buildTipItem(
//                       Icons.group,
//                       'Use the buddy system when possible',
//                     ),
//                   ],
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
//
//   Widget _buildBarChartItem(String day, int value, Color color) {
//     return Column(
//       children: [
//         Text(
//           '$value',
//           style: const TextStyle(
//             fontSize: 12,
//             fontWeight: FontWeight.bold,
//           ),
//         ),
//         const SizedBox(height: 4),
//         Container(
//           width: 24,
//           height: value.toDouble(),
//           decoration: BoxDecoration(
//             color: color,
//             borderRadius: BorderRadius.circular(6),
//           ),
//         ),
//         const SizedBox(height: 8),
//         Text(
//           day,
//           style: const TextStyle(
//             fontSize: 12,
//             color: Colors.grey,
//           ),
//         ),
//       ],
//     );
//   }
//
//   Widget _buildTimeSlotItem(String time, String percentage, Color color) {
//     return Container(
//       margin: const EdgeInsets.only(bottom: 12),
//       child: Row(
//         children: [
//           Container(
//             width: 100,
//             child: Text(
//               time,
//               style: const TextStyle(
//                 fontSize: 14,
//                 fontWeight: FontWeight.w500,
//               ),
//             ),
//           ),
//           Expanded(
//             child: Stack(
//               children: [
//                 Container(
//                   height: 20,
//                   decoration: BoxDecoration(
//                     color: Colors.grey.shade200,
//                     borderRadius: BorderRadius.circular(10),
//                   ),
//                 ),
//                 Container(
//                   height: 20,
//                   width: double.parse(percentage.replaceAll('%', '')) * 2,
//                   decoration: BoxDecoration(
//                     color: color,
//                     borderRadius: BorderRadius.circular(10),
//                   ),
//                 ),
//               ],
//             ),
//           ),
//           const SizedBox(width: 12),
//           Text(
//             percentage,
//             style: TextStyle(
//               fontSize: 14,
//               fontWeight: FontWeight.bold,
//               color: color,
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildLocationSafetyItem(
//       String location, String description, Color color, int score) {
//     return Container(
//       margin: const EdgeInsets.only(bottom: 16),
//       decoration: BoxDecoration(
//         border: Border.all(color: Colors.grey.shade200),
//         borderRadius: BorderRadius.circular(12),
//       ),
//       padding: const EdgeInsets.all(16),
//       child: Row(
//         children: [
//           Container(
//             width: 8,
//             height: 40,
//             decoration: BoxDecoration(
//               color: color,
//               borderRadius: BorderRadius.circular(4),
//             ),
//           ),
//           const SizedBox(width: 16),
//           Expanded(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Text(
//                   location,
//                   style: const TextStyle(
//                     fontSize: 16,
//                     fontWeight: FontWeight.bold,
//                   ),
//                 ),
//                 const SizedBox(height: 4),
//                 Text(
//                   description,
//                   style: const TextStyle(
//                     color: Colors.grey,
//                     fontSize: 14,
//                   ),
//                 ),
//               ],
//             ),
//           ),
//           Column(
//             children: [
//               Text(
//                 '$score',
//                 style: TextStyle(
//                   fontSize: 28,
//                   fontWeight: FontWeight.bold,
//                   color: color,
//                 ),
//               ),
//               const Text(
//                 'Score',
//                 style: TextStyle(
//                   fontSize: 12,
//                   color: Colors.grey,
//                 ),
//               ),
//             ],
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildTipItem(IconData icon, String text) {
//     return Container(
//       margin: const EdgeInsets.only(bottom: 12),
//       child: Row(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Icon(icon, color: Colors.purple.shade600, size: 24),
//           const SizedBox(width: 16),
//           Expanded(
//             child: Text(
//               text,
//               style: const TextStyle(fontSize: 14),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }
//
// // Profile Screen
// class ProfileScreen extends StatelessWidget {
//   final bool nightMode;
//   final ValueChanged<bool> onNightModeChanged;
//
//   const ProfileScreen({
//     Key? key,
//     required this.nightMode,
//     required this.onNightModeChanged,
//   }) : super(key: key);
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Colors.grey[50],
//       body: SafeArea(
//         child: SingleChildScrollView(
//           child: Container(
//             color: Colors.white,
//             padding: const EdgeInsets.all(24),
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 const Text(
//                   'Profile',
//                   style: TextStyle(
//                     fontSize: 28,
//                     fontWeight: FontWeight.bold,
//                   ),
//                 ),
//                 const SizedBox(height: 4),
//                 const Text(
//                   'Manage your safety settings',
//                   style: TextStyle(
//                     color: Colors.grey,
//                     fontSize: 14,
//                   ),
//                 ),
//                 const SizedBox(height: 24),
//
//                 // User Card
//                 Container(
//                   decoration: BoxDecoration(
//                     gradient: LinearGradient(
//                       colors: [Colors.purple.shade600, Colors.purple.shade700],
//                     ),
//                     borderRadius: BorderRadius.circular(20),
//                   ),
//                   padding: const EdgeInsets.all(24),
//                   child: Column(
//                     children: [
//                       Row(
//                         children: [
//                           Container(
//                             width: 48,
//                             height: 48,
//                             decoration: BoxDecoration(
//                               color: Colors.white.withOpacity(0.3),
//                               shape: BoxShape.circle,
//                             ),
//                             child: const Icon(
//                               Icons.person,
//                               color: Colors.white,
//                               size: 24,
//                             ),
//                           ),
//                           const SizedBox(width: 16),
//                           const Expanded(
//                             child: Column(
//                               crossAxisAlignment: CrossAxisAlignment.start,
//                               children: [
//                                 Text(
//                                   'Sarah Johnson',
//                                   style: TextStyle(
//                                     color: Colors.white,
//                                     fontSize: 20,
//                                     fontWeight: FontWeight.bold,
//                                   ),
//                                 ),
//                                 SizedBox(height: 4),
//                                 Text(
//                                   'sarah@email.com',
//                                   style: TextStyle(
//                                     color: Colors.white70,
//                                     fontSize: 14,
//                                   ),
//                                 ),
//                               ],
//                             ),
//                           ),
//                         ],
//                       ),
//                       const SizedBox(height: 16),
//                       const Row(
//                         children: [
//                           Icon(Icons.shield, color: Colors.white, size: 16),
//                           SizedBox(width: 8),
//                           Text(
//                             'Premium Member',
//                             style: TextStyle(
//                               color: Colors.white,
//                               fontSize: 14,
//                               fontWeight: FontWeight.bold,
//                             ),
//                           ),
//                         ],
//                       ),
//                     ],
//                   ),
//                 ),
//                 const SizedBox(height: 24),
//
//                 // Emergency Contacts
//                 const Text(
//                   'Emergency Contacts',
//                   style: TextStyle(
//                     fontWeight: FontWeight.bold,
//                     fontSize: 18,
//                   ),
//                 ),
//                 const SizedBox(height: 12),
//                 _buildEmergencyContact(
//                   Icons.phone,
//                   Colors.blue,
//                   'Mom',
//                   '+1 (555) 123-4567',
//                   isPrimary: true,
//                 ),
//                 const SizedBox(height: 12),
//                 _buildEmergencyContact(
//                   Icons.phone,
//                   Colors.purple,
//                   'Best Friend',
//                   '+1 (555) 234-5678',
//                 ),
//                 const SizedBox(height: 12),
//                 _buildEmergencyContact(
//                   Icons.phone,
//                   Colors.purple,
//                   'Sister',
//                   '+1 (555) 345-6789',
//                 ),
//                 const SizedBox(height: 16),
//                 Center(
//                   child: TextButton(
//                     onPressed: () {},
//                     child: const Text(
//                       '+ Add New Contact',
//                       style: TextStyle(
//                         color: Colors.purple,
//                         fontWeight: FontWeight.bold,
//                         fontSize: 16,
//                       ),
//                     ),
//                   ),
//                 ),
//                 const SizedBox(height: 24),
//
//                 // Settings
//                 const Text(
//                   'Settings',
//                   style: TextStyle(
//                     fontWeight: FontWeight.bold,
//                     fontSize: 18,
//                   ),
//                 ),
//                 const SizedBox(height: 12),
//                 _buildSettingItem(
//                   Icons.notifications,
//                   Colors.orange,
//                   'Notifications',
//                   'Manage alert preferences',
//                 ),
//                 const SizedBox(height: 8),
//                 _buildSettingItem(
//                   Icons.location_on,
//                   Colors.green,
//                   'Location Sharing',
//                   'Control who sees your location',
//                 ),
//                 const SizedBox(height: 8),
//                 _buildSettingItem(
//                   Icons.shield,
//                   Colors.purple,
//                   'Safety Preferences',
//                   'Customize threat sensitivity',
//                 ),
//                 const SizedBox(height: 8),
//                 _buildNightModeItem(),
//                 const SizedBox(height: 24),
//
//                 // Upgrade Button
//                 Container(
//                   width: double.infinity,
//                   decoration: BoxDecoration(
//                     gradient: LinearGradient(
//                       colors: [Colors.purple.shade600, Colors.purple.shade700],
//                     ),
//                     borderRadius: BorderRadius.circular(16),
//                   ),
//                   child: Material(
//                     color: Colors.transparent,
//                     child: InkWell(
//                       onTap: () {},
//                       borderRadius: BorderRadius.circular(16),
//                       child: const Padding(
//                         padding: EdgeInsets.symmetric(vertical: 16),
//                         child: Row(
//                           mainAxisAlignment: MainAxisAlignment.center,
//                           children: [
//                             Icon(Icons.shield, color: Colors.white, size: 20),
//                             SizedBox(width: 8),
//                             Text(
//                               'Upgrade to Premium',
//                               style: TextStyle(
//                                 color: Colors.white,
//                                 fontSize: 16,
//                                 fontWeight: FontWeight.bold,
//                               ),
//                             ),
//                           ],
//                         ),
//                       ),
//                     ),
//                   ),
//                 ),
//                 const SizedBox(height: 16),
//
//                 // Sign Out
//                 Center(
//                   child: TextButton(
//                     onPressed: () {},
//                     child: const Row(
//                       mainAxisSize: MainAxisSize.min,
//                       children: [
//                         Icon(Icons.logout, color: Colors.red, size: 20),
//                         SizedBox(width: 8),
//                         Text(
//                           'Sign Out',
//                           style: TextStyle(
//                             color: Colors.red,
//                             fontWeight: FontWeight.bold,
//                             fontSize: 16,
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),
//                 ),
//                 const SizedBox(height: 16),
//               ],
//             ),
//           ),
//         ),
//       ),
//     );
//   }
//
//   Widget _buildEmergencyContact(
//       IconData icon,
//       Color color,
//       String name,
//       String phone, {
//         bool isPrimary = false,
//       }) {
//     return Container(
//       decoration: BoxDecoration(
//         color: color.withOpacity(0.1),
//         borderRadius: BorderRadius.circular(16),
//       ),
//       padding: const EdgeInsets.all(16),
//       child: Row(
//         children: [
//           Container(
//             padding: const EdgeInsets.all(12),
//             decoration: BoxDecoration(
//               color: color.withOpacity(0.2),
//               shape: BoxShape.circle,
//             ),
//             child: Icon(icon, color: color, size: 24),
//           ),
//           const SizedBox(width: 16),
//           Expanded(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Text(
//                   name,
//                   style: const TextStyle(
//                     fontWeight: FontWeight.bold,
//                     fontSize: 16,
//                   ),
//                 ),
//                 const SizedBox(height: 4),
//                 Text(
//                   phone,
//                   style: const TextStyle(
//                     color: Colors.grey,
//                     fontSize: 14,
//                   ),
//                 ),
//               ],
//             ),
//           ),
//           if (isPrimary)
//             Container(
//               padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
//               decoration: BoxDecoration(
//                 color: color,
//                 borderRadius: BorderRadius.circular(20),
//               ),
//               child: const Text(
//                 'Primary',
//                 style: TextStyle(
//                   color: Colors.white,
//                   fontSize: 12,
//                   fontWeight: FontWeight.bold,
//                 ),
//               ),
//             ),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildSettingItem(
//       IconData icon,
//       Color color,
//       String title,
//       String subtitle,
//       ) {
//     return Container(
//       decoration: BoxDecoration(
//         border: Border.all(color: Colors.grey.shade200),
//         borderRadius: BorderRadius.circular(12),
//       ),
//       padding: const EdgeInsets.all(16),
//       child: Row(
//         children: [
//           Container(
//             padding: const EdgeInsets.all(12),
//             decoration: BoxDecoration(
//               color: color.withOpacity(0.1),
//               shape: BoxShape.circle,
//             ),
//             child: Icon(icon, color: color, size: 24),
//           ),
//           const SizedBox(width: 16),
//           Expanded(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Text(
//                   title,
//                   style: const TextStyle(
//                     fontWeight: FontWeight.bold,
//                     fontSize: 16,
//                   ),
//                 ),
//                 const SizedBox(height: 4),
//                 Text(
//                   subtitle,
//                   style: const TextStyle(
//                     color: Colors.grey,
//                     fontSize: 14,
//                   ),
//                 ),
//               ],
//             ),
//           ),
//           const Icon(Icons.chevron_right, color: Colors.grey),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildNightModeItem() {
//     return Container(
//       decoration: BoxDecoration(
//         border: Border.all(color: Colors.grey.shade200),
//         borderRadius: BorderRadius.circular(12),
//       ),
//       padding: const EdgeInsets.all(16),
//       child: Row(
//         children: [
//           Container(
//             padding: const EdgeInsets.all(12),
//             decoration: BoxDecoration(
//               color: Colors.blueGrey.withOpacity(0.1),
//               shape: BoxShape.circle,
//             ),
//             child: const Icon(Icons.nightlight_round,
//                 color: Colors.blueGrey, size: 24),
//           ),
//           const SizedBox(width: 16),
//           const Expanded(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Text(
//                   'Night Mode',
//                   style: TextStyle(
//                     fontWeight: FontWeight.bold,
//                     fontSize: 16,
//                   ),
//                 ),
//                 SizedBox(height: 4),
//                 Text(
//                   'Dark theme for low-light conditions',
//                   style: TextStyle(
//                     color: Colors.grey,
//                     fontSize: 14,
//                   ),
//                 ),
//               ],
//             ),
//           ),
//           Switch(
//             value: nightMode,
//             onChanged: onNightModeChanged,
//             activeColor: Colors.purple.shade600,
//           ),
//         ],
//       ),
//     );
//   }
// }

import 'package:flutter/material.dart';
import 'app/app.dart';

void main() {
  runApp(const SafeGuardApp());
}