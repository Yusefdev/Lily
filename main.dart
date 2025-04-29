import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:installed_apps/installed_apps.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:notification_listener_service/notification_listener_service.dart';
import 'package:http/http.dart' as http;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Notification Forwarder',
      home: NotificationForwarderPage(),
    );
  }
}

class NotificationForwarderPage extends StatefulWidget {
  @override
  _NotificationForwarderPageState createState() => _NotificationForwarderPageState();
}

class _NotificationForwarderPageState extends State<NotificationForwarderPage> {
  Widget? avatar;
  String _status = "Initializing…";
  String? _serverIp;
  bool _notifPermission = false;
  final _ipController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _setup();
  }

  void _update(String msg) => setState(() => _status = msg);

  Future<void> _setup() async {
    // 1) Notification permission
    bool granted = await NotificationListenerService.isPermissionGranted();
    if (!granted) {
      _update("Requesting notification access…");
      granted = await NotificationListenerService.requestPermission();
    }
    if (!granted) {
      _update("❌ Notification access denied.\nEnable it in Settings → Notification access.");
      return;
    }
    _notifPermission = true;
    _update("✅ Notification access granted.\nStarting listener…");

    // start listening RIGHT AWAY (so we print every notif)
    _startListening();

    // 2) Discover Python server on whatever network is active
    _update("Scanning network(s) for server…");
    final ip = await _discoverServer();
    if (ip == null) {
      _update("⚠️ Server not found.\nEnter it manually below:");
    } else {
      _serverIp = ip;
      _update("✅ Connected to server at $_serverIp");
    }
  }

  /// List all IPv4 interfaces (excluding loopback/link-local),
  /// take each address's /24 prefix, and scan for port 5000.
  Future<String?> _discoverServer() async {
    // need location to get Wifi info on Android 10+
    if (!await Permission.location.isGranted) {
      await Permission.location.request();
    }

    // get all IPv4 interfaces
    final interfaces = await NetworkInterface.list(
      includeLinkLocal: true,
      type: InternetAddressType.IPv4,
    );

    for (var iface in interfaces) {
      for (var addr in iface.addresses) {
        final ip = addr.address;
        // skip loopback and link-local
        if (ip.startsWith('127.') || ip.startsWith('169.254.')) continue;

        final prefix = ip.substring(0, ip.lastIndexOf('.'));
        final found = await _scanPrefix(prefix);
        if (found != null) return found;
      }
    }
    return null;
  }

  /// Scan <prefix>.1–254 on port 5000 with a short timeout
  Future<String?> _scanPrefix(String prefix) {
    const port = 5000;
    const timeout = Duration(milliseconds: 300);
    final completer = Completer<String?>();
    int pending = 0;

    for (var i = 1; i <= 254; i++) {
      final host = '$prefix.$i';
      pending++;
      Socket.connect(host, port, timeout: timeout).then((socket) {
        socket.destroy();
        if (!completer.isCompleted) completer.complete(host);
      }).catchError((_) {
        // ignore
      }).whenComplete(() {
        if (--pending == 0 && !completer.isCompleted) {
          completer.complete(null);
        }
      });
    }

    return completer.future;
  }

  void _startListening() {
  NotificationListenerService.notificationsStream.listen((evt) {
    final pkg   = evt.packageName ?? 'unknown';
    final title = evt.title      ?? '';
    final body  = evt.content    ?? '';
    final info  = '🔔 $pkg: $title — $body';

    // 1) Log & show in UI immediately
    debugPrint(info);
    _update(info);

    if (_serverIp == null) return;

    final uri = Uri.parse('http://$_serverIp:5000/notify');
    // start building the payload
    final payload = <String, dynamic>{
      'type':    'notifs',
      'content': '$title\n$body',
    };

    // 2) Chain the async calls instead of `await`
    InstalledApps
      .getAppInfo(pkg, null)                            // fetch app info
      .then((app) {
        if (app != null) {
          payload['name'] = app.name;
          if (app.icon != null) {
            payload['logo'] = base64Encode(app.icon!);
          }
        }
        return http.post(                                // then POST
          uri,
          headers: {'Content-Type':'application/json'},
          body: jsonEncode(payload),
        );
      })
      .then((resp) {
        if (resp.statusCode != 200) {
          debugPrint('Server ${resp.statusCode}: ${resp.body}');
        }
      })
      .catchError((e) {
        debugPrint('Error forwarding notification: $e');
      });
  });
}


  @override
  void dispose() {
    _ipController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext _) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notification Forwarder'),leading: avatar??Text("data")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(_status, textAlign: TextAlign.center),
            if (_notifPermission && _serverIp == null) ...[
              const SizedBox(height: 20),
              TextField(
                controller: _ipController,
                decoration: const InputDecoration(
                  labelText: 'Server IP (e.g. 192.168.203.241)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () {
                  final ip = _ipController.text.trim();
                  if (ip.isNotEmpty) {
                    _serverIp = ip;
                    _update('✅ Connected to server at $ip');
                  }
                },
                child: const Text('Connect'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
