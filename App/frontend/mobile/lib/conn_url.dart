// App/frontend/mobile/lib/conn_url.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'dart:convert';
import 'app/theme.dart';
import 'widgets/app_snackbar.dart';

class ApiUrls {
  static String baseUrl = '';

  static Future<void> initBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    baseUrl = prefs.getString('ip_address') ?? '';
  }

  static Future<String> getBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('ip_address') ?? '';
  }
}


class IpPromptScreen extends StatefulWidget {
  const IpPromptScreen({Key? key}) : super(key: key);

  @override
  State<IpPromptScreen> createState() => _IpPromptScreenState();
}

class _IpPromptScreenState extends State<IpPromptScreen> {
  final _controller = TextEditingController();
  String _testResult = '';
  bool _testing = false;

  Future<void> _saveIp(String ip) async {
    String formattedIp = ip.trim();
    if (!formattedIp.contains(':')) {
      formattedIp = '$formattedIp:8000';
    }
    if (!formattedIp.startsWith('http://') && !formattedIp.startsWith('https://')) {
      formattedIp = 'http://$formattedIp';
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('ip_address', formattedIp);
    Navigator.pop(context);
    Future.delayed(const Duration(milliseconds: 500), () {
      AppSnackBar.show(
        context,
        'Server IP saved. Please restart the app for changes to take effect.',
        type: AppSnackBarType.warning,
        duration: const Duration(seconds: 10),
      );
    });
  }

  Future<bool> _testHealth(String url) async {
    try {
      final response = await Future.delayed(const Duration(milliseconds: 100), () async {
        return await Uri.tryParse(url) != null
            ? await _fetchHealth(url)
            : null;
      });
      return response == true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _fetchHealth(String url) async {
    try {
      final client = HttpClient();
      final req = await client.getUrl(Uri.parse(url));
      final res = await req.close();
      final body = await res.transform(utf8.decoder).join();
      if (body.contains('SheSafe API is running') && body.contains('healthy')) {
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final text = theme.textTheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Server IP'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Enter your server IP address', style: text.titleLarge),
              const SizedBox(height: 24),
              TextField(
                controller: _controller,
                decoration: InputDecoration(
                  hintText: 'e.g. 192.168.1.10',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  filled: true,
                  fillColor: colors.surface,
                  prefixIcon: const Icon(Icons.dns, color: AppTheme.primaryColor),
                ),
                keyboardType: TextInputType.number,
                style: text.bodyLarge,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _controller.text.isEmpty
                      ? null
                      : () => _saveIp(_controller.text),
                  child: const Text('Save', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton(
                  onPressed: _testing
                      ? null
                      : () async {
                          setState(() {
                            _testing = true;
                            _testResult = '';
                          });
                          final ip = _controller.text;
                          if (ip.isEmpty) {
                            setState(() {
                              _testResult = 'Enter IP to test.';
                              _testing = false;
                            });
                            return;
                          }
                          try {
                            final url = 'http://$ip:8000/';
                            final response = await Uri.tryParse(url) != null
                                ? await _testHealth(url)
                                : null;
                            if (response == true) {
                              setState(() {
                                _testResult = 'Working!';
                                _testing = false;
                              });
                            } else {
                              setState(() {
                                _testResult = 'Not working. Please change IP.';
                                _testing = false;
                              });
                            }
                          } catch (_) {
                            setState(() {
                              _testResult = 'Not working. Please change IP.';
                              _testing = false;
                            });
                          }
                        },
                  child: _testing ? const Text('Testing...') : const Text('Test Connection'),
                ),
              ),
              if (_testResult.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 12.0),
                  child: Text(_testResult, style: text.bodyMedium),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// Usage: Wrap your main app widget with IpPromptScreen
// void main() {
//   runApp(IpPromptScreen(child: MyApp()));
// }
