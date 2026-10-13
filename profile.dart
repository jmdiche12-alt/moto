import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

import 'edit_profile.dart';
import 'start.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  String name = "Loading...";
  String email = "Loading...";
  String phone = "Loading...";

  // Theme State (device-level — fine to stay local, not personal data)
  bool isDarkMode = true;

  // Profile Image (kept local, but scoped per-uid so it doesn't leak
  // between accounts sharing the same device)
  File? _profileImage;
  final ImagePicker _imagePicker = ImagePicker();

  // ================= DESIGN SYSTEM COLORS =================
  final Color _accent = const Color(0xFFFF1E1E);

  Color get _bg =>
      isDarkMode ? const Color(0xFF060B14) : const Color(0xFFF4F4F4);
  Color get _card =>
      isDarkMode ? const Color(0xFF0D131D) : const Color(0xFFFFFFFF);
  Color get _text =>
      isDarkMode ? const Color(0xFFFFFFFF) : const Color(0xFF111111);
  Color get _subtext =>
      isDarkMode ? const Color(0xFF9CA3AF) : const Color(0xFF666666);
  Color get _buttonBg =>
      isDarkMode ? const Color(0xFF1A2332) : const Color(0xFFF0F0F0);
  Color get _borderColor => isDarkMode
      ? Colors.white.withValues(alpha: 0.05)
      : const Color(0xFFECECEC);
  Color get _shadowColor =>
      isDarkMode ? Colors.black38 : Colors.black.withValues(alpha: 0.04);

  @override
  void initState() {
    super.initState();
    loadProfile();
  }

  // ================= LOAD PROFILE & THEME =================
  // Name / email / phone now come from Firestore, keyed by the logged-in
  // user's uid — so each account only ever sees its own profile data,
  // even if multiple accounts log in on the same device.
  Future<void> loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    User? currentUser = FirebaseAuth.instance.currentUser;

    setState(() {
      isDarkMode = prefs.getBool("isDarkMode") ?? true;
    });

    if (currentUser == null) {
      setState(() {
        name = "Moto Rider";
        email = "motoguard@gmail.com";
        phone = "+63 912 345 6789";
      });
      return;
    }

    // Profile image path is local to the device, so scope its prefs key
    // by uid to avoid one account seeing another account's photo.
    final imagePath = prefs.getString("profileImagePath_${currentUser.uid}");
    if (imagePath != null && File(imagePath).existsSync()) {
      setState(() {
        _profileImage = File(imagePath);
      });
    } else {
      setState(() {
        _profileImage = null;
      });
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();

      final data = doc.data();

      setState(() {
        name = data?['name'] ?? currentUser.displayName ?? "Moto Rider";
        email = currentUser.email ?? data?['email'] ?? "motoguard@gmail.com";
        phone = data?['phone'] ?? "+63 912 345 6789";
      });
    } catch (e) {
      setState(() {
        name = currentUser.displayName ?? "Moto Rider";
        email = currentUser.email ?? "motoguard@gmail.com";
        phone = "+63 912 345 6789";
      });
    }
  }

  // ================= CHANGE PROFILE IMAGE =================
  Future<void> _changeProfileImage() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        final File imageFile = File(pickedFile.path);

        // Save image path scoped to this uid only.
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
            "profileImagePath_${currentUser.uid}", imageFile.path);

        setState(() {
          _profileImage = imageFile;
        });

        if (mounted) {
          _showToast(context, "Profile picture updated!");
        }
      }
    } catch (e) {
      if (mounted) {
        _showToast(context, "Error changing profile picture");
      }
    }
  }

  // ================= TOGGLE THEME =================
  Future<void> _toggleTheme(bool isDark) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool("isDarkMode", isDark);

    setState(() {
      isDarkMode = isDark;
    });

    if (mounted) {
      _showToast(context, isDark ? "Dark mode enabled" : "Light mode enabled");
    }
  }

  // ================= NAVIGATION LOGIC =================
  void handleMenuClick(String title) {
    switch (title) {
      case "Change Password":
        _showToast(context, "Navigating to Change Password...");
        break;
      case "Help Center":
        _showToast(context, "Opening Help Center...");
        break;
    }
  }

  // ================= SNACKBAR =================
  void _showToast(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: _card,
        duration: const Duration(seconds: 1),
      ),
    );
  }

  // ================= OPEN EDIT PROFILE =================
  Future<void> openEditProfile() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditProfilePage(
          currentName: name,
          currentEmail: email,
          currentPhone: phone,
        ),
      ),
    );

    if (result == true) {
      loadProfile();
    }
  }

  // ================= LOGOUT =================
  Future<void> _handleLogout() async {
    await FirebaseAuth.instance.signOut();

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (context) => const StartPage(),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: _text),
        title: Text(
          "My Profile",
          style: TextStyle(
            color: _text,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          // EDIT BUTTON
          IconButton(
            onPressed: openEditProfile,
            icon: Icon(Icons.edit, color: _accent),
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Column(
            children: [
              // ================= PROFILE CARD =================
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(25),
                decoration: BoxDecoration(
                  color: _card,
                  gradient: isDarkMode
                      ? const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF0B111B), Color(0xFF101826)],
                        )
                      : null,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: isDarkMode
                        ? Colors.white.withValues(alpha: 0.05)
                        : const Color(0xFFEEEEEE),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: isDarkMode
                          ? _accent.withValues(alpha: 0.08)
                          : Colors.black.withValues(alpha: 0.08),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Profile Avatar with Change Image Button
                    Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _accent,
                              width: 3,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: _accent.withValues(alpha: 0.3),
                                blurRadius: 15,
                              )
                            ],
                          ),
                          child: CircleAvatar(
                            radius: 45,
                            backgroundColor: _accent.withValues(alpha: 0.1),
                            backgroundImage: _profileImage != null
                                ? FileImage(_profileImage!)
                                : null,
                            child: _profileImage == null
                                ? Icon(
                                    Icons.person,
                                    size: 45,
                                    color: _accent,
                                  )
                                : null,
                          ),
                        ),
                        // Change Image Button
                        GestureDetector(
                          onTap: _changeProfileImage,
                          child: Container(
                            height: 36,
                            width: 36,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _accent,
                              boxShadow: [
                                BoxShadow(
                                  color: _accent.withValues(alpha: 0.4),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.camera_alt_rounded,
                              size: 18,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),
                    Text(
                      name,
                      style: TextStyle(
                        color: _text,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      email,
                      style: TextStyle(
                        color: _subtext,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 15),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 15,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: _accent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Text(
                        phone,
                        style: TextStyle(
                          color: _accent,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 30),

              // ================= THEME TOGGLE SECTION =================
              sectionTitle("Display Preferences"),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: _card,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: _borderColor,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _shadowColor,
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Theme Mode",
                      style: TextStyle(
                        color: _text,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        // Dark Mode Button
                        Expanded(
                          child: GestureDetector(
                            onTap: () => _toggleTheme(true),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 12, horizontal: 16),
                              decoration: BoxDecoration(
                                color: isDarkMode
                                    ? _accent.withValues(alpha: 0.2)
                                    : _buttonBg,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isDarkMode
                                      ? _accent.withValues(alpha: 0.5)
                                      : Colors.transparent,
                                  width: 1.5,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.dark_mode_rounded,
                                    color: isDarkMode ? _accent : _subtext,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    "Dark",
                                    style: TextStyle(
                                      color: isDarkMode ? _accent : _subtext,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Light Mode Button
                        Expanded(
                          child: GestureDetector(
                            onTap: () => _toggleTheme(false),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 12, horizontal: 16),
                              decoration: BoxDecoration(
                                color: !isDarkMode
                                    ? _accent.withValues(alpha: 0.2)
                                    : _buttonBg,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: !isDarkMode
                                      ? _accent.withValues(alpha: 0.5)
                                      : Colors.transparent,
                                  width: 1.5,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.light_mode_rounded,
                                    color: !isDarkMode ? _accent : _subtext,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    "Light",
                                    style: TextStyle(
                                      color: !isDarkMode ? _accent : _subtext,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 30),

              // ================= ACCOUNT SECTION =================
              sectionTitle("Account Settings"),

              profileTile(Icons.lock_outline, "Change Password"),
              profileTile(Icons.help_outline, "Help Center"),

              const SizedBox(height: 30),

              // ================= LOGOUT BUTTON =================
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _accent,
                    shadowColor: _accent.withValues(alpha: 0.5),
                    elevation: 8,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  onPressed: _handleLogout,
                  child: const Text(
                    "Logout",
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  // ================= SECTION TITLE =================
  Widget sectionTitle(String text) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12, left: 5),
        child: Text(
          text,
          style: TextStyle(
            color: _subtext,
            fontSize: 14,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
          ),
        ),
      ),
    );
  }

  // ================= PROFILE TILE =================
  Widget profileTile(IconData icon, String title) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: _borderColor,
        ),
        boxShadow: [
          BoxShadow(
            color: _shadowColor,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        onTap: () => handleMenuClick(title),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
        leading: Icon(icon, color: _accent),
        title: Text(
          title,
          style: TextStyle(
            color: _text,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}