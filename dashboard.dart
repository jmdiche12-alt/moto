import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'profile.dart';
import 'map.dart';
import 'add_motor.dart';
import 'motor_verification.dart';
import 'notification_page.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  int currentTab = 0;

  String motorcycleName = 'Loading...';

  bool isDarkMode = true;
  bool isRefreshing = false;

  // Display placeholder only. Replace with actual battery telemetry
  // when your ESP32 sends battery data to Firebase.
  int batteryLevel = 92;

  final NotificationService _svc = NotificationService.instance;
  Timer? _statusTimer;

  late final AnimationController _radarController;

  Color get _bg =>
      isDarkMode ? const Color(0xFF0A0E17) : const Color(0xFFEDF1F6);

  Color get _bg2 =>
      isDarkMode ? const Color(0xFF0D1220) : const Color(0xFFE4E9F0);

  Color get _panelStart => isDarkMode
      ? const Color(0xFF121826).withValues(alpha: 0.92)
      : Colors.white.withValues(alpha: 0.96);

  Color get _panelEnd => isDarkMode
      ? const Color(0xFF171E30).withValues(alpha: 0.85)
      : const Color(0xFFF7F9FC);

  Color get _border =>
      isDarkMode ? const Color(0xFF2A3346) : const Color(0xFFD3DAE3);

  Color get _signal =>
      isDarkMode ? const Color(0xFF00E5C7) : const Color(0xFF00A88F);

  Color get _amber =>
      isDarkMode ? const Color(0xFFFFB020) : const Color(0xFFC97A00);

  Color get _crimson =>
      isDarkMode ? const Color(0xFFFF3B5C) : const Color(0xFFD8214A);

  Color get _text =>
      isDarkMode ? const Color(0xFFF4F6F9) : const Color(0xFF11151E);

  Color get _mist =>
      isDarkMode ? const Color(0xFF8A93A6) : const Color(0xFF5B6472);

  Color get _shadowColor => isDarkMode
      ? Colors.black.withValues(alpha: 0.30)
      : Colors.black.withValues(alpha: 0.07);

  OwnedDevice? get _primaryDevice =>
      _svc.devices.value.isEmpty ? null : _svc.devices.value.first;

  bool get _deviceOnline {
    final device = _primaryDevice;
    return device != null && _svc.isOnline(device.id);
  }

  // DeviceStatus only contains online and lastSeen.
  // Do not access a nonexistent DeviceStatus.status field.
  String get _gpsLabel {
    final device = _primaryDevice;

    if (device == null) return 'NO DEVICE';
    if (!_svc.isOnline(device.id)) return 'OFFLINE';

    // Online status alone does not confirm a valid GPS fix.
    return 'NO DATA';
  }

  Color get _gpsColor {
    switch (_gpsLabel) {
      case 'STRONG':
        return _signal;
      case 'OFFLINE':
        return _crimson;
      default:
        return _amber;
    }
  }

  String get _lastPingLabel {
    final device = _primaryDevice;
    if (device == null) return '--';

    final seen = _svc.lastSeen(device.id);
    if (seen == null) return '--';

    final difference = DateTime.now().difference(seen);

    if (difference.isNegative) return 'JUST NOW';
    if (difference.inSeconds < 5) return 'JUST NOW';
    if (difference.inMinutes < 1) {
      return '${difference.inSeconds}S AGO';
    }
    if (difference.inHours < 1) {
      return '${difference.inMinutes}M AGO';
    }
    if (difference.inDays < 1) {
      return '${difference.inHours}H AGO';
    }

    return '${difference.inDays}D AGO';
  }

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    _radarController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );

    if (!WidgetsBinding
        .instance.platformDispatcher.accessibilityFeatures.disableAnimations) {
      _radarController.repeat();
    }

    _svc.start();

    _statusTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) {
        if (mounted) setState(() {});
      },
    );

    _initializeApp();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _initializeApp();
      _svc.start();
    }
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _radarController.dispose();
    super.dispose();
  }

  Future<void> _initializeApp() async {
    await loadTheme();
    if (!mounted) return;
    await _loadUserProfile();
  }

  Future<void> _fetchLatestData() async {
    if (!mounted) return;

    setState(() => isRefreshing = true);

    try {
      await _loadUserProfile();
      await _svc.start();
    } finally {
      if (mounted) {
        setState(() => isRefreshing = false);
      }
    }
  }

  Future<void> loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;

    setState(() {
      isDarkMode = prefs.getBool('isDarkMode') ?? true;
    });

    _updateSystemUI();
  }

  void _updateSystemUI() {
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness:
            isDarkMode ? Brightness.light : Brightness.dark,
        systemNavigationBarColor: _bg,
        systemNavigationBarIconBrightness:
            isDarkMode ? Brightness.light : Brightness.dark,
      ),
    );
  }

  Future<void> _loadUserProfile() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      if (!mounted) return;
      setState(() => motorcycleName = 'Honda XRM 125');
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final data = doc.data();

      if (!mounted) return;

      setState(() {
        motorcycleName = data?['motorcycleName']?.toString() ?? 'Honda XRM 125';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => motorcycleName = 'Honda XRM 125');
    }
  }

  Future<void> saveMotorcycleName(String newName) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      snack('Please sign in first.');
      return;
    }

    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set(
        {'motorcycleName': newName},
        SetOptions(merge: true),
      );

      if (!mounted) return;
      setState(() => motorcycleName = newName);
    } catch (_) {
      if (!mounted) return;
      snack('Unable to save motorcycle name.');
    }
  }

  Future<void> nav(int index) async {
    if (!mounted) return;

    setState(() => currentTab = index);

    if (index == 0) return;

    if (index == 1) {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const TrackPage()),
      );

      if (!mounted) return;
      setState(() => currentTab = 0);
    } else if (index == 2) {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ProfilePage()),
      );

      if (!mounted) return;
      await loadTheme();

      if (!mounted) return;
      setState(() => currentTab = 0);
    }
  }

  Future<void> openNotifications() async {
    if (!mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NotificationPage(isDarkMode: isDarkMode),
      ),
    );

    if (!mounted) return;
    await loadTheme();
  }

  Future<void> openEditPage() async {
    if (!mounted) return;

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddMotorPage(currentName: motorcycleName),
      ),
    );

    if (!mounted) return;

    if (result != null) {
      await saveMotorcycleName(result.toString());
    }
  }

  void _openMyDevice() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const MotorVerificationPage(),
      ),
    );
  }

  void snack(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        elevation: 8,
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDarkMode ? const Color(0xFF171E30) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        content: Text(
          message,
          style: GoogleFonts.manrope(
            color: _text,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  TextStyle _display({
    required double size,
    FontWeight weight = FontWeight.w700,
    Color? color,
    double? letterSpacing,
  }) {
    return GoogleFonts.rajdhani(
      fontSize: size,
      fontWeight: weight,
      color: color ?? _text,
      letterSpacing: letterSpacing,
      height: 1,
    );
  }

  TextStyle _mono({
    required double size,
    FontWeight weight = FontWeight.w600,
    Color? color,
    double letterSpacing = 1,
  }) {
    return GoogleFonts.jetBrainsMono(
      fontSize: size,
      fontWeight: weight,
      color: color ?? _mist,
      letterSpacing: letterSpacing,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: Stack(
        children: [
          _buildStaticBackground(),
          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: RefreshIndicator(
                    color: _signal,
                    backgroundColor: _panelStart,
                    onRefresh: _fetchLatestData,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics(),
                      ),
                      padding: const EdgeInsets.only(bottom: 20),
                      children: [
                        const SizedBox(height: 16),
                        _header(),
                        _guardConsoleCard(),
                        _quickActions(),
                      ],
                    ),
                  ),
                ),
                _bottomNav(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStaticBackground() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_bg, _bg2],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -110,
            right: -60,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _signal.withValues(
                  alpha: isDarkMode ? 0.07 : 0.05,
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -130,
            left: -60,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _amber.withValues(
                  alpha: isDarkMode ? 0.05 : 0.04,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Header: brand and notification bell, without greeting.
  Widget _header() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _signal.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _signal.withValues(alpha: 0.30),
                  ),
                ),
                child: Icon(
                  Icons.shield_moon_rounded,
                  color: _signal,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: 'MOTO',
                      style: _display(
                        size: 18,
                        letterSpacing: 1.5,
                      ),
                    ),
                    TextSpan(
                      text: 'GUARD',
                      style: _display(
                        size: 18,
                        color: _signal,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          _notificationBell(),
        ],
      ),
    );
  }

  Widget _notificationBell() {
    return AnimatedBuilder(
      animation: _svc.changes,
      builder: (context, _) {
        final unread = _svc.unreadCount;

        return GestureDetector(
          onTap: openNotifications,
          behavior: HitTestBehavior.opaque,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _signal.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _signal.withValues(alpha: 0.30),
                  ),
                ),
                child: Icon(
                  Icons.notifications_rounded,
                  color: _signal,
                  size: 21,
                ),
              ),
              if (unread > 0)
                Positioned(
                  top: -6,
                  right: -6,
                  child: Container(
                    constraints: const BoxConstraints(
                      minWidth: 18,
                      minHeight: 18,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: _crimson,
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(color: _bg, width: 1.5),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      unread > 99 ? '99+' : '$unread',
                      style: _mono(
                        size: 9,
                        color: Colors.white,
                        weight: FontWeight.w800,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _guardConsoleCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_panelStart, _panelEnd],
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: _border, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: _shadowColor,
            blurRadius: 26,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: _signal.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _signal.withValues(alpha: 0.35),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: _signal,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 7),
                    Text(
                      'ACTIVE GUARD',
                      style: _mono(
                        size: 11,
                        weight: FontWeight.w700,
                        color: _signal,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: openEditPage,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _amber.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _amber.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Icon(
                    Icons.edit_rounded,
                    color: _amber,
                    size: 19,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Text(
            'YOUR MOTORCYCLE',
            style: _mono(size: 11.5, letterSpacing: 1.4),
          ),
          const SizedBox(height: 6),
          Text(
            motorcycleName,
            style: _display(size: 30, letterSpacing: -0.3),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 20),
          Center(child: _radarBike()),
          const SizedBox(height: 20),
          _telemetryStrip(),
        ],
      ),
    );
  }

  Widget _radarBike() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 168,
          width: 168,
          child: Stack(
            alignment: Alignment.center,
            children: [
              AnimatedBuilder(
                animation: _radarController,
                builder: (context, _) {
                  return CustomPaint(
                    size: const Size(168, 168),
                    painter: _RadarPainter(
                      progress: _radarController.value,
                      color: _signal,
                    ),
                  );
                },
              ),
              ConstrainedBox(
                constraints: const BoxConstraints(
                  maxHeight: 108,
                  maxWidth: 140,
                ),
                child: Image.asset(
                  'assets/bike.png',
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      height: 96,
                      width: 96,
                      decoration: BoxDecoration(
                        color: _signal.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _signal.withValues(alpha: 0.30),
                        ),
                      ),
                      child: Icon(
                        Icons.motorcycle_rounded,
                        size: 46,
                        color: _signal,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 6,
          ),
          decoration: BoxDecoration(
            color: _signal.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _signal.withValues(alpha: 0.25),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: _signal,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 7),
              Text(
                'LIVE VIEW',
                style: _mono(
                  size: 10.5,
                  weight: FontWeight.w700,
                  color: _signal,
                  letterSpacing: 1.1,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _telemetryStrip() {
    return AnimatedBuilder(
      animation: _svc.changes,
      builder: (context, _) {
        return Container(
          padding: const EdgeInsets.only(top: 14),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: _border)),
          ),
          child: Row(
            children: [
              Expanded(
                child: _telemetryStat('GPS', _gpsLabel, _gpsColor),
              ),
              Container(width: 1, height: 30, color: _border),
              Expanded(
                child: _telemetryStat(
                  'BATTERY',
                  '$batteryLevel%',
                  _amber,
                ),
              ),
              Container(width: 1, height: 30, color: _border),
              Expanded(
                child: _telemetryStat(
                  'LAST PING',
                  _lastPingLabel,
                  _mist,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _telemetryStat(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: _mono(
              size: 9,
              color: _mist,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _mono(
              size: 12,
              weight: FontWeight.w700,
              color: color,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _quickActions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _actionCard(
                  Icons.explore_rounded,
                  'LIVE\nTRACK',
                  _signal,
                  () => nav(1),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _actionCard(
                  Icons.shield_rounded,
                  'SECURITY\nMODE',
                  _amber,
                  () => snack(
                      'Security mode status is controlled by your device.'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _actionCard(
                  Icons.emergency_share_rounded,
                  'EMERGENCY\nSOS',
                  _crimson,
                  () => snack(
                    'SOS is not connected to an emergency service yet.',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          GestureDetector(
            onTap: _openMyDevice,
            behavior: HitTestBehavior.opaque,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    _signal.withValues(alpha: 0.14),
                    _panelStart,
                  ],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: _signal.withValues(alpha: 0.35),
                ),
                boxShadow: [
                  BoxShadow(
                    color: _signal.withValues(alpha: 0.06),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: _signal.withValues(alpha: 0.14),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _signal.withValues(alpha: 0.30),
                      ),
                    ),
                    child: Icon(
                      Icons.memory_rounded,
                      color: _signal,
                      size: 27,
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'MY DEVICE',
                          style: _mono(
                            size: 11,
                            weight: FontWeight.w800,
                            color: _signal,
                            letterSpacing: 1.4,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          'Manage your MotoGuard connection',
                          style: _mono(
                            size: 10,
                            color: _mist,
                            letterSpacing: 0,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _deviceStatusPill(),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: _signal,
                    size: 17,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 22),
          _recentMessages(),
        ],
      ),
    );
  }

  Widget _deviceStatusPill() {
    return AnimatedBuilder(
      animation: _svc.changes,
      builder: (context, _) {
        final device = _primaryDevice;
        final online = _deviceOnline;

        final color = device == null
            ? _mist
            : online
                ? _signal
                : _crimson;

        final label = device == null
            ? 'NO DEVICE'
            : online
                ? 'ONLINE'
                : 'OFFLINE';

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.13),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: color.withValues(alpha: 0.35),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: _mono(
                  size: 9,
                  weight: FontWeight.w800,
                  color: color,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _recentMessages() {
    final palette = MgPalette(isDarkMode);

    return AnimatedBuilder(
      animation: _svc.changes,
      builder: (context, _) {
        final recent = _svc.visible.take(2).toList();

        Widget body;

        if (_svc.error.value != null && _svc.devices.value.isEmpty) {
          body = _messageInfoCard(
            Icons.error_outline_rounded,
            _crimson,
            _svc.error.value!,
          );
        } else if (!_svc.loaded.value) {
          body = Padding(
            padding: const EdgeInsets.symmetric(vertical: 22),
            child: Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: _signal,
                ),
              ),
            ),
          );
        } else if (_svc.devices.value.isEmpty) {
          body = _messageInfoCard(
            Icons.memory_rounded,
            _amber,
            'No registered MotoGuard device found. Register your device to receive security alerts.',
          );
        } else if (recent.isEmpty) {
          body = _messageInfoCard(
            Icons.notifications_none_rounded,
            _mist,
            'No alerts yet. Notifications from your registered devices will appear here.',
          );
        } else {
          body = Column(
            children: [
              for (final notification in recent)
                NotificationTile(
                  n: notification,
                  p: palette,
                  compact: true,
                  onTap: () async {
                    await _svc.markRead(notification.id);
                    if (!mounted) return;
                    await openNotifications();
                  },
                ),
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'RECENT ACTIVITY',
                  style: _mono(
                    size: 11,
                    weight: FontWeight.w800,
                    color: _mist,
                    letterSpacing: 1.4,
                  ),
                ),
                GestureDetector(
                  onTap: openNotifications,
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                      'VIEW ALL',
                      style: _mono(
                        size: 10,
                        weight: FontWeight.w800,
                        color: _signal,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            body,
          ],
        );
      },
    );
  }

  Widget _messageInfoCard(
    IconData icon,
    Color color,
    String message,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _panelStart,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.manrope(
                fontSize: 12,
                height: 1.35,
                color: _mist,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionCard(
    IconData icon,
    String label,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Container(
          height: 140,
          decoration: BoxDecoration(
            color: _panelStart,
            border: Border.all(color: _border),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            children: [
              Container(height: 3, color: color),
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.14),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(icon, size: 26, color: color),
                      ),
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Text(
                          label,
                          textAlign: TextAlign.center,
                          style: _mono(
                            size: 10,
                            weight: FontWeight.w700,
                            color: _text,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bottomNav() {
    return Container(
      height: 74,
      margin: const EdgeInsets.only(
        left: 24,
        right: 24,
        bottom: 24,
        top: 8,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: _panelStart,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _border, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: _shadowColor,
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _navItem(Icons.grid_view_rounded, 'HOME', 0),
          _navItem(Icons.map_rounded, 'MAP', 1),
          _navItem(Icons.person_rounded, 'PROFILE', 2),
        ],
      ),
    );
  }

  Widget _navItem(IconData icon, String label, int index) {
    final active = currentTab == index;

    return GestureDetector(
      onTap: () => nav(index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: active ? _signal.withValues(alpha: 0.14) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: active ? _signal : _mist,
              size: 22,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: _mono(
                size: 9,
                weight: FontWeight.w700,
                color: active ? _signal : _mist,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RadarPainter extends CustomPainter {
  final double progress;
  final Color color;

  const _RadarPainter({
    required this.progress,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final maxRadius = size.shortestSide / 2;

    for (int i = 0; i < 3; i++) {
      final t = (progress + i / 3) % 1.0;
      final radius = maxRadius * t;
      final opacity = (1 - t).clamp(0.0, 1.0) * 0.55;

      final paint = Paint()
        ..color = color.withValues(alpha: opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4;

      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _RadarPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}
