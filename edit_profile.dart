import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';

class EditProfilePage extends StatefulWidget {
  final String currentName;
  final String currentEmail;
  final String currentPhone;

  const EditProfilePage({
    super.key,
    required this.currentName,
    required this.currentEmail,
    required this.currentPhone,
  });

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;

  bool isLoading = false;
  bool isPhoneVerified = false;

  String verificationId = "";

  @override
  void initState() {
    super.initState();

    _nameController = TextEditingController(
      text: widget.currentName,
    );

    _emailController = TextEditingController(
      text: widget.currentEmail,
    );

    // Auto set to 09 kapag empty
    _phoneController = TextEditingController(
      text: widget.currentPhone.isEmpty ? "09" : widget.currentPhone,
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  // ================= VERIFY PHONE =================
  Future<void> _verifyPhoneNumber() async {
    try {
      String phone = _phoneController.text.trim();

      // Validation
      if (phone.length != 11 || !phone.startsWith("09")) {
        _showError(
          "Enter valid PH number",
        );
        return;
      }

      // Convert to Firebase format
      phone = "+63${phone.substring(1)}";

      setState(() {
        isLoading = true;
      });

      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: phone,
        timeout: const Duration(seconds: 60),

        // AUTO VERIFY
        verificationCompleted: (PhoneAuthCredential credential) async {
          try {
            User? user = FirebaseAuth.instance.currentUser;

            if (user != null) {
              await user.updatePhoneNumber(
                credential,
              );
            }

            if (!mounted) return;

            setState(() {
              isLoading = false;
              isPhoneVerified = true;
            });

            _showSuccess(
              "Phone verified automatically",
            );
          } catch (e) {
            if (!mounted) return;

            setState(() {
              isLoading = false;
            });

            _showError(
              "Auto verification failed",
            );
          }
        },

        // FAILED
        verificationFailed: (FirebaseAuthException e) {
          if (!mounted) return;

          setState(() {
            isLoading = false;
          });

          _showError(
            e.message ?? "Verification failed",
          );
        },

        // OTP SENT
        codeSent: (String verId, int? resendToken) {
          verificationId = verId;

          if (!mounted) return;

          setState(() {
            isLoading = false;
          });

          _showOTPDialog();
        },

        // TIMEOUT
        codeAutoRetrievalTimeout: (String verId) {
          verificationId = verId;
        },
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
      });

      _showError(
        "Failed to verify phone",
      );
    }
  }

  // ================= OTP DIALOG =================
  void _showOTPDialog() {
    final otpController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return AlertDialog(
          backgroundColor: const Color(0xFF0F1318),
          title: const Text(
            "OTP Verification",
            style: TextStyle(
              color: Colors.white,
            ),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: TextField(
              controller: otpController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              style: const TextStyle(
                color: Colors.white,
              ),
              decoration: const InputDecoration(
                hintText: "Enter 6-digit OTP",
                counterText: "",
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                "Cancel",
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  String code = otpController.text.trim();

                  if (code.length != 6) {
                    _showError("Invalid OTP");
                    return;
                  }

                  Navigator.pop(context);

                  setState(() {
                    isLoading = true;
                  });

                  PhoneAuthCredential credential = PhoneAuthProvider.credential(
                    verificationId: verificationId,
                    smsCode: code,
                  );

                  User? user = FirebaseAuth.instance.currentUser;

                  if (user != null) {
                    await user.updatePhoneNumber(
                      credential,
                    );
                  }

                  if (!mounted) return;

                  setState(() {
                    isLoading = false;
                    isPhoneVerified = true;
                  });

                  _showSuccess(
                    "Phone verified successfully",
                  );
                } catch (e) {
                  if (!mounted) return;

                  setState(() {
                    isLoading = false;
                  });

                  _showError(
                    "Invalid OTP",
                  );
                }
              },
              child: const Text(
                "Verify",
              ),
            ),
          ],
        );
      },
    );
  }

  // ================= SAVE =================
  Future<void> _saveChanges() async {
    try {
      setState(() {
        isLoading = true;
      });

      final prefs = await SharedPreferences.getInstance();

      await prefs.setString(
        "name",
        _nameController.text.trim(),
      );

      await prefs.setString(
        "email",
        _emailController.text.trim(),
      );

      await prefs.setString(
        "phone",
        _phoneController.text.trim(),
      );

      User? user = FirebaseAuth.instance.currentUser;

      if (user != null) {
        await user.updateDisplayName(
          _nameController.text.trim(),
        );

        if (_emailController.text.trim() != user.email) {
          await user.verifyBeforeUpdateEmail(
            _emailController.text.trim(),
          );
        }

        await user.reload();
      }

      if (!mounted) return;

      _showSuccess(
        "Profile updated",
      );

      Navigator.pop(
        context,
        true,
      );
    } catch (e) {
      _showError(
        "Failed saving profile",
      );
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  // ================= UI =================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050709),
      appBar: AppBar(
        title: const Text(
          "Edit Profile",
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 20),
            const CircleAvatar(
              radius: 50,
              backgroundColor: Colors.orange,
              child: Icon(
                Icons.person,
                size: 50,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 30),
            _buildTextField(
              "Full Name",
              _nameController,
              Icons.person,
            ),
            const SizedBox(height: 20),
            _buildTextField(
              "Email",
              _emailController,
              Icons.email,
            ),
            const SizedBox(height: 20),
            _buildPhoneField(),
            const SizedBox(height: 15),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: isLoading ? null : _verifyPhoneNumber,
                child: Text(
                  isPhoneVerified ? "Verified" : "Verify Phone",
                ),
              ),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: isLoading ? null : _saveChanges,
                child: isLoading
                    ? const CircularProgressIndicator(
                        color: Colors.black,
                      )
                    : const Text(
                        "Save Changes",
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ================= NORMAL FIELD =================
  Widget _buildTextField(
    String label,
    TextEditingController controller,
    IconData icon,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          style: const TextStyle(
            color: Colors.white,
          ),
          decoration: InputDecoration(
            prefixIcon: Icon(icon),
          ),
        ),
      ],
    );
  }

  // ================= PHONE FIELD =================
  Widget _buildPhoneField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Phone Number",
          style: TextStyle(
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          maxLength: 11,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            TextInputFormatter.withFunction(
              (
                oldValue,
                newValue,
              ) {
                String text = newValue.text;

                // Auto start with 09
                if (text.isEmpty) {
                  return const TextEditingValue(
                    text: "09",
                    selection: TextSelection.collapsed(
                      offset: 2,
                    ),
                  );
                }

                // Force 09 start
                if (!text.startsWith("09")) {
                  text = "09";
                }

                // Max 11 digits
                if (text.length > 11) {
                  text = text.substring(
                    0,
                    11,
                  );
                }

                return TextEditingValue(
                  text: text,
                  selection: TextSelection.collapsed(
                    offset: text.length,
                  ),
                );
              },
            ),
          ],
          style: const TextStyle(
            color: Colors.white,
          ),
          decoration: const InputDecoration(
            prefixIcon: Icon(
              Icons.phone,
            ),
            hintText: "09XXXXXXXXX",
            counterText: "",
          ),
        ),
      ],
    );
  }

  // ================= SNACKBAR =================
  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.red,
        content: Text(message),
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.green,
        content: Text(message),
      ),
    );
  }
}