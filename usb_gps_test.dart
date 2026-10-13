import 'dart:async';
import 'package:flutter/material.dart';
import 'package:usb_serial_for_android/usb_serial_for_android.dart';
import 'package:usb_serial_for_android/usb_port.dart';

class UsbGpsTestPage extends StatefulWidget {
  const UsbGpsTestPage({super.key});

  @override
  State<UsbGpsTestPage> createState() => _UsbGpsTestPageState();
}

class _UsbGpsTestPageState extends State<UsbGpsTestPage> {
  UsbPort? _port;
  StreamSubscription<List<int>>? _subscription;

  String status = "Searching for Arduino...";
  String receivedData = "";

  double? latitude;
  double? longitude;
  int satellites = 0;

  @override
  void initState() {
    super.initState();
    connectArduino();
  }

  Future<void> connectArduino() async {
    try {
      final devices = await UsbSerial.listDevices();

      if (devices.isEmpty) {
        setState(() {
          status = "No Arduino found";
        });
        return;
      }

      final device = devices.first;

      setState(() {
        status = "Found: ${device.productName ?? "Arduino"}";
      });

      final port = await device.create();

      if (port == null) {
        setState(() {
          status = "Could not create USB port";
        });
        return;
      }

      _port = port;

      final opened = await _port!.open();

      if (!opened) {
        setState(() {
          status = "Could not open USB port";
        });
        return;
      }

      // Arduino Serial.begin(9600)
      await _port!.setPortParameters(
        9600,
        8,
        1,
        0,
      );

      await _port!.setDTR(true);
      await _port!.setRTS(true);

      setState(() {
        status = "Arduino Connected!";
      });

      _subscription = _port!.inputStream?.listen(
        (List<int> data) {
          final text = String.fromCharCodes(data);

          debugPrint("Arduino: $text");

          setState(() {
            receivedData += text;
          });

          parseGPS(text);
        },
      );
    } catch (e) {
      setState(() {
        status = "Connection error: $e";
      });
    }
  }

  void parseGPS(String data) {
    try {
      if (!data.contains(r"$GPS|")) {
        return;
      }

      final start = data.indexOf(r"$GPS|");

      final end = data.indexOf(
        r"$",
        start + 5,
      );

      if (end == -1) {
        return;
      }

      final message = data.substring(
        start + 5,
        end,
      );

      final parts = message.split("|");

      if (parts.length < 3) {
        return;
      }

      final lat = double.tryParse(parts[0]);
      final lng = double.tryParse(parts[1]);
      final sats = int.tryParse(parts[2]);

      if (lat == null || lng == null) {
        return;
      }

      setState(() {
        latitude = lat;
        longitude = lng;
        satellites = sats ?? 0;
      });
    } catch (e) {
      debugPrint("GPS Parse Error: $e");
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _port?.close();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("NEO-6M GPS Test"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              status,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 30),
            const Text(
              "Latitude:",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              latitude?.toStringAsFixed(6) ?? "Waiting...",
              style: const TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 15),
            const Text(
              "Longitude:",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              longitude?.toStringAsFixed(6) ?? "Waiting...",
              style: const TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 15),
            Text(
              "Satellites: $satellites",
              style: const TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 30),
            const Text(
              "Raw Arduino Data:",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: SingleChildScrollView(
                child: Text(
                  receivedData,
                  style: const TextStyle(
                    fontFamily: "monospace",
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
