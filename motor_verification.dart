import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class MotorVerificationPage extends StatefulWidget {
  const MotorVerificationPage({
    super.key,
  });

  @override
  State<MotorVerificationPage> createState() => _MotorVerificationPageState();
}

class _MotorVerificationPageState extends State<MotorVerificationPage> {
  static const Color cyberGreen = Color(0xFF00E676);
  static const Color darkGreen = Color(0xFF071A12);

  final TextEditingController deviceIdController = TextEditingController();
  final TextEditingController passkeyController = TextEditingController();

  bool loading = false;
  bool obscurePasskey = true;

  // ============================================================
  // SHA-256
  // ============================================================

  String hashPasskey(String passkey) {
    final bytes = utf8.encode(passkey);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  // ============================================================
  // VERIFY & CONNECT
  // ============================================================

  Future<void> verifyMotor() async {
    if (loading) return;

    final deviceId = deviceIdController.text.trim();
    final passkey = passkeyController.text.trim();

    if (deviceId.isEmpty) {
      showMessage('Enter your device ID.');
      return;
    }

    if (passkey.isEmpty) {
      showMessage('Enter your motor passkey.');
      return;
    }

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      showMessage('Please login first.');
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      loading = true;
    });

    try {
      final passkeyHash = hashPasskey(passkey);

      final deviceRef =
          FirebaseFirestore.instance.collection('iotDevices').doc(deviceId);

      // ========================================================
      // IMPORTANT
      //
      // We DO NOT read the device first.
      //
      // We directly attempt the update.
      //
      // Firestore Rules should verify:
      // - device is currently available
      // - submitted hash == stored hash
      // - connectedUserId == current user
      // - status becomes connected
      // ========================================================

      await deviceRef.update({
        'status': 'connected',
        'connectedUserId': user.uid,
        'connectedAt': FieldValue.serverTimestamp(),
        'passkeyHash': passkeyHash,
      });

      // ========================================================
      // SUCCESS
      // ========================================================

      passkeyController.clear();

      if (!mounted) return;

      Navigator.pop(
        context,
        <String, dynamic>{
          'success': true,
          'deviceId': deviceId,
          'status': 'connected',
          'connectedUserId': user.uid,
        },
      );
    } on FirebaseException catch (e) {
      if (!mounted) return;

      String message;

      switch (e.code) {
        case 'permission-denied':
          message =
              'Invalid device ID or passkey, or this motor is already connected.';
          break;

        case 'not-found':
          message = 'Device ID not found.';
          break;

        case 'unauthenticated':
          message = 'Please login first.';
          break;

        default:
          message = e.message ?? 'Unable to verify motor.';
      }

      showMessage(message);
    } catch (_) {
      if (!mounted) return;

      showMessage('Unable to verify motor.');
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  // ============================================================
  // MESSAGE
  // ============================================================

  void showMessage(String message) {
    if (!mounted) return;

    final messenger = ScaffoldMessenger.of(context);

    messenger.hideCurrentSnackBar();

    messenger.showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: const Color(0xFF08110D),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    );
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    deviceIdController.dispose();
    passkeyController.dispose();
    super.dispose();
  }

  // ============================================================
  // TEXT FIELD
  // ============================================================

  InputDecoration fieldDecoration({
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
      prefixIcon: Icon(
        icon,
        color: cyberGreen,
      ),
      hintText: hint,
      hintStyle: const TextStyle(
        color: Colors.white38,
      ),
      filled: true,
      fillColor: Colors.white.withValues(
        alpha: 0.04,
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 18,
        vertical: 17,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide.none,
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(
          Radius.circular(18),
        ),
        borderSide: BorderSide(
          color: cyberGreen,
          width: 1.5,
        ),
      ),
      disabledBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(
          Radius.circular(18),
        ),
        borderSide: BorderSide(
          color: Colors.white12,
        ),
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Verify Motor',
          style: TextStyle(
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(25),
            decoration: BoxDecoration(
              color: darkGreen,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: cyberGreen.withValues(
                  alpha: 0.15,
                ),
              ),
              boxShadow: [
                BoxShadow(
                  color: cyberGreen.withValues(
                    alpha: 0.05,
                  ),
                  blurRadius: 30,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              children: [
                // ==================================================
                // ICON
                // ==================================================

                Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: cyberGreen.withValues(
                      alpha: 0.08,
                    ),
                    border: Border.all(
                      color: cyberGreen.withValues(
                        alpha: 0.25,
                      ),
                    ),
                  ),
                  child: const Icon(
                    Icons.shield_outlined,
                    size: 55,
                    color: cyberGreen,
                  ),
                ),

                const SizedBox(height: 20),

                // ==================================================
                // TITLE
                // ==================================================

                const Text(
                  'Connect Your Motor',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 25,
                    fontWeight: FontWeight.w900,
                  ),
                ),

                const SizedBox(height: 10),

                const Text(
                  'Enter your MotoGuard device ID and '
                  'the passkey provided with your device.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),

                const SizedBox(height: 30),

                // ==================================================
                // DEVICE ID
                // ==================================================

                TextField(
                  controller: deviceIdController,
                  enabled: !loading,
                  autocorrect: false,
                  enableSuggestions: false,
                  textInputAction: TextInputAction.next,
                  textCapitalization: TextCapitalization.none,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: fieldDecoration(
                    hint: 'Device ID',
                    icon: Icons.memory_rounded,
                  ),
                ),

                const SizedBox(height: 15),

                // ==================================================
                // PASSKEY
                // ==================================================

                TextField(
                  controller: passkeyController,
                  obscureText: obscurePasskey,
                  enabled: !loading,
                  autocorrect: false,
                  enableSuggestions: false,
                  textInputAction: TextInputAction.done,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                  onSubmitted: (_) {
                    if (!loading) {
                      verifyMotor();
                    }
                  },
                  decoration: fieldDecoration(
                    hint: 'Motor Passkey',
                    icon: Icons.key_rounded,
                  ).copyWith(
                    suffixIcon: IconButton(
                      onPressed: loading
                          ? null
                          : () {
                              setState(() {
                                obscurePasskey = !obscurePasskey;
                              });
                            },
                      icon: Icon(
                        obscurePasskey
                            ? Icons.visibility_off
                            : Icons.visibility,
                        color: Colors.white54,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 25),

                // ==================================================
                // BUTTON
                // ==================================================

                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: loading ? null : verifyMotor,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: cyberGreen,
                      foregroundColor: Colors.black,
                      disabledBackgroundColor: cyberGreen.withValues(
                        alpha: 0.5,
                      ),
                      disabledForegroundColor: Colors.black54,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(17),
                      ),
                    ),
                    child: loading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              color: Colors.black,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            'VERIFY & CONNECT',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1,
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 16),

                const Text(
                  'Your passkey is converted to a secure '
                  'SHA-256 hash before it is sent to Firestore.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white30,
                    fontSize: 11,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}