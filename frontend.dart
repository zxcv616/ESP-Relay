import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:multicast_dns/multicast_dns.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Relay Controller',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: ControlPage(),
    );
  }
}

class ControlPage extends StatefulWidget {
  @override
  _ControlPageState createState() => _ControlPageState();
}

class _ControlPageState extends State<ControlPage> {
  String baseUrl = ""; // Dynamic IP/hostname for ESP8266
  String relayState = "Unknown";
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    discoverDevice();
  }

  Future<void> discoverDevice() async {
    setState(() {
      isLoading = true;
    });

    try {
      final MDnsClient client = MDnsClient();
      await client.start();
      // Look for the "esp-relay" service advertised via mDNS
      await for (final PtrResourceRecord ptr in client.lookup<PtrResourceRecord>(
          ResourceRecordQuery.serverPointer("esp-relay.local"))) {
        await for (final SrvResourceRecord srv
            in client.lookup<SrvResourceRecord>(
                ResourceRecordQuery.service(ptr.domainName))) {
          setState(() {
            baseUrl = "http://${srv.target}:${srv.port}";
          });
          print("Device found at $baseUrl");
          break;
        }
      }
      client.stop();
    } catch (e) {
      print("Error discovering device: $e");
    }

    setState(() {
      isLoading = false;
    });
  }

  Future<void> toggleRelay(bool turnOn) async {
    if (baseUrl.isEmpty) {
      print("No device discovered yet.");
      return;
    }

    try {
      final url = turnOn ? "$baseUrl/on" : "$baseUrl/off";
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        setState(() {
          relayState = turnOn ? "ON" : "OFF";
        });
      } else {
        print("Failed to toggle relay. Status code: ${response.statusCode}");
      }
    } catch (e) {
      print("Error: $e");
    }
  }

  Future<void> getRelayStatus() async {
    if (baseUrl.isEmpty) {
      print("No device discovered yet.");
      return;
    }

    try {
      final response = await http.get(Uri.parse("$baseUrl/status"));

      if (response.statusCode == 200) {
        final body = response.body;
        final state = body.contains("ON") ? "ON" : "OFF";
        setState(() {
          relayState = state;
        });
      } else {
        print("Failed to get relay status. Status code: ${response.statusCode}");
      }
    } catch (e) {
      print("Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Relay Controller"),
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : baseUrl.isEmpty
              ? Center(
                  child: Text(
                    "No device found. Please make sure the relay is powered on.",
                    style: TextStyle(fontSize: 18),
                    textAlign: TextAlign.center,
                  ),
                )
              : Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Relay is $relayState",
                        style: TextStyle(
                            fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: () => toggleRelay(true),
                        child: Text("Turn ON"),
                      ),
                      SizedBox(height: 10),
                      ElevatedButton(
                        onPressed: () => toggleRelay(false),
                        child: Text("Turn OFF"),
                      ),
                      SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: getRelayStatus,
                        child: Text("Refresh Status"),
                      ),
                    ],
                  ),
                ),
    );
  }
}
