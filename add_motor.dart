import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AddMotorPage extends StatefulWidget {
  final String currentName;

  const AddMotorPage({
    super.key,
    required this.currentName,
  });

  @override
  State<AddMotorPage> createState() => _AddMotorPageState();
}

class _AddMotorPageState extends State<AddMotorPage> {
  late TextEditingController controller;
  bool isSaving = false;

  @override
  void initState() {
    super.initState();
    controller = TextEditingController(text: widget.currentName);
  }

  Future<void> _saveAndExit() async {
    if (isSaving) return;

    setState(() => isSaving = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString("motorcycleName", controller.text);

      if (mounted) {
        Navigator.pop(context, controller.text);
      }
    } catch (e) {
      debugPrint("SharedPreferences error: $e");
    }

    if (mounted) {
      setState(() => isSaving = false);
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        title: const Text("Edit Motorcycle"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _saveAndExit,
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: controller,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: "Motorcycle Name",
                labelStyle: const TextStyle(color: Colors.grey),
                filled: true,
                fillColor: const Color(0xFF161B22),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                ),
                onPressed: isSaving ? null : _saveAndExit,
                child: Text(
                  isSaving ? "Saving..." : "Save",
                  style: const TextStyle(
                    fontSize: 18,
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
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
