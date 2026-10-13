import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Returns the lowercase-hex SHA-256 of the passkey.
///
/// MUST produce the same value as the ESP32's `sha256Hex(DEVICE_PASSKEY)`,
/// because that hash is the Firebase folder name: `/gps/<hash>/...`
/// The passkey is case-sensitive; only leading/trailing spaces are removed.
String hashPasskey(String passkey) =>
    sha256.convert(utf8.encode(passkey.trim())).toString();