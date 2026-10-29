import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart' as rtdb;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const RideApp());
}

/* ============================================================
   APP
============================================================ */

class RideApp extends StatelessWidget {
  const RideApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Ride App',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.green,
        scaffoldBackgroundColor: Colors.white,
      ),
      home: const SplashScreen(),
    );
  }
}

/* ============================================================
   SPLASH SCREEN
============================================================ */
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();

    Future.delayed(const Duration(seconds: 4), () {
      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const AuthGate(),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050807),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF050807),
              Color(0xFF0A1511),
              Color(0xFF000000),
            ],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              // Subtle background glow
              Positioned(
                top: -100,
                left: -80,
                child: Container(
                  width: 260,
                  height: 260,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFB7FF18).withOpacity(0.07),
                  ),
                ),
              ),

              Positioned(
                bottom: -120,
                right: -80,
                child: Container(
                  width: 280,
                  height: 280,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFB7FF18).withOpacity(0.05),
                  ),
                ),
              ),

              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Main app name
                    const Text(
                      'SAWARI',
                      style: TextStyle(
                        color: Color(0xFFB7FF18),
                        fontSize: 46,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 5,
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Tagline
                    const Text(
                      'Your ride, your choice.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 17,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.4,
                      ),
                    ),

                    const SizedBox(height: 48),

                    // Loading indicator
                    const SizedBox(
                      width: 26,
                      height: 26,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Color(0xFFB7FF18),
                        ),
                      ),
                    ),

                    const SizedBox(height: 18),

                    const Text(
                      'Making every journey better...',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white38,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              // Bottom branding
              const Positioned(
                left: 0,
                right: 0,
                bottom: 22,
                child: Text(
                  'SAWARI',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white24,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 3,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
/* ============================================================
   AUTH GATE
============================================================ */

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  Future<Widget> _homeForUser(User user) async {
    final firestore = FirebaseFirestore.instance;
    final driverDoc = await firestore.collection('drivers').doc(user.uid).get();

    if (driverDoc.exists) {
      final driverData = driverDoc.data() ?? <String, dynamic>{};
      if (driverData['registrationComplete'] == true) {
        return HomeScreen(
          initialRole: 'Driver',
          initialVehicle: driverData['vehicleType']?.toString(),
        );
      }
      return const DriverVehicleScreen();
    }

    final userDoc = await firestore.collection('users').doc(user.uid).get();
    final userData = userDoc.data();
    if (userData?['role'] == 'driver') {
      return const DriverVehicleScreen();
    }

    return const HomeScreen();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = snapshot.data;
        if (user == null) return const LoginScreen();

        return FutureBuilder<Widget>(
          future: _homeForUser(user),
          builder: (context, homeSnapshot) {
            if (homeSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            if (homeSnapshot.hasError) {
              debugPrint('Account role lookup error: ${homeSnapshot.error}');
              return const HomeScreen();
            }
            return homeSnapshot.data ?? const HomeScreen();
          },
        );
      },
    );
  }
}

/* ============================================================
   LOGIN SCREEN
============================================================ */

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() =>
      _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final phoneController = TextEditingController();

  bool loading = false;
  bool hidePassword = true;
  bool phoneLoginMode = false;




  Future<void> _emailLogin() async {
    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _message(
        'Please enter your email and password.',
      );
      return;
    }

    setState(() => loading = true);

    try {
      await FirebaseAuth.instance
          .signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      _message(_firebaseError(e));
    } catch (e) {
      debugPrint('$e');
      _message('Login failed.');
    }

    if (mounted) {
      setState(() => loading = false);
    }
  }

  Future<void> _phoneLogin() async {
    final phone = phoneController.text.trim();

    if (phone.isEmpty) {
      _message(
        'Please enter your phone number.',
      );
      return;
    }

    _message(
      'Phone verification is starting...',
    );

    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: phone,
      verificationCompleted:
          (PhoneAuthCredential credential) async {
        try {
          await FirebaseAuth.instance.signInWithCredential(
            credential,
          );
        } catch (e) {
          debugPrint('$e');
        }
      },
      verificationFailed:
          (FirebaseAuthException e) {
        _message(_firebaseError(e));
      },
      codeSent: (
          String verificationId,
          int? resendToken,
          ) {
        if (!mounted) return;

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PhoneOtpScreen(
              verificationId: verificationId,
              phoneNumber: phone,
            ),
          ),
        );
      },
      codeAutoRetrievalTimeout:
          (String verificationId) {},
    );
  }

  Future<void> _googleLogin() async {
    setState(() => loading = true);

    try {
      final GoogleSignIn googleSignIn =
          GoogleSignIn.instance;

      await googleSignIn.initialize();

      final GoogleSignInAccount googleUser =
      await googleSignIn.authenticate();

      final GoogleSignInAuthentication googleAuth =
          googleUser.authentication;

      final credential =
      GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );

      final result = await FirebaseAuth.instance
          .signInWithCredential(credential);

      final user = result.user;

      if (user == null) {
        throw Exception(
          'Google user not found.',
        );
      }

      final userDoc = await FirebaseFirestore
          .instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!userDoc.exists) {
        if (!mounted) return;

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => GooglePassengerRegistration(
              user: user,
              googleEmail: user.email ?? '',
              googleName:
              user.displayName ?? '',
            ),
          ),
        );
      }
    } on GoogleSignInException catch (e) {
      debugPrint(
        'Google Sign-In Error: $e',
      );

      _message(
        'Google login cancel ya fail ho gaya.',
      );
    } on FirebaseAuthException catch (e) {
      _message(_firebaseError(e));
    } catch (e) {
      debugPrint('$e');

      _message(
        'Google login nahi ho saka.',
      );
    }

    if (mounted) {
      setState(() => loading = false);
    }
  }
  String _firebaseError(
      FirebaseAuthException e,
      ) {
    switch (e.code) {
      case 'invalid-email':
        return 'Invalid email address.';
      case 'user-not-found':
        return 'This account was not found.';
      case 'wrong-password':
        return 'Incorrect password.';
      case 'invalid-credential':
        return 'Incorrect email or password.';
      case 'email-already-in-use':
        return 'This email is already registered.';
      case 'weak-password':
        return 'Password is too weak.';
      case 'invalid-phone-number':
        return 'Invalid phone number.';
      case 'network-request-failed':
        return 'Please check your internet connection.';
      default:
        return e.message ??
            'Authentication error.';
    }
  }

  void _message(String text) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text(text),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const lime = Color(0xFFB7FF18);
    const background = Color(0xFF061116);

    return Scaffold(
      backgroundColor: background,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0C241B), background, Color(0xFF020607)],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Keep the complete login and account-creation options on screen.
              final compact = constraints.maxHeight < 760;
              final tiny = constraints.maxHeight < 650;
              final gap = tiny ? 5.0 : (compact ? 7.0 : 10.0);
              return Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: constraints.maxWidth < 500 ? 16 : 24,
                    vertical: tiny ? 3 : (compact ? 6 : 12),
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 460),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: Container(
                            width: tiny ? 44 : (compact ? 52 : 62),
                            height: tiny ? 44 : (compact ? 52 : 62),
                            decoration: BoxDecoration(
                              color: lime,
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: [
                                BoxShadow(color: lime.withOpacity(0.16), blurRadius: 22, spreadRadius: 1),
                              ],
                            ),
                            child: Icon(Icons.local_taxi_rounded, size: tiny ? 27 : 32, color: background),
                          ),
                        ),
                        SizedBox(height: gap),
                        Text(
                          'SAWARI',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: lime, fontSize: tiny ? 25 : (compact ? 28 : 32), fontWeight: FontWeight.w900, letterSpacing: 4),
                        ),
                        SizedBox(height: tiny ? 1 : 3),
                        Text(
                          'Your ride, your choice.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white70, fontSize: tiny ? 11 : 13, letterSpacing: 0.3),
                        ),
                        SizedBox(height: tiny ? 8 : (compact ? 10 : 16)),
                        Container(
                          padding: EdgeInsets.all(tiny ? 11 : (compact ? 13 : 18)),
                          decoration: BoxDecoration(
                            color: const Color(0xE609171B),
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(color: const Color(0x669CFF16)),
                            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 20, offset: Offset(0, 8))],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                phoneLoginMode ? 'Login with phone' : 'Welcome back',
                                style: TextStyle(color: Colors.white, fontSize: tiny ? 19 : (compact ? 21 : 24), fontWeight: FontWeight.w900),
                              ),
                              SizedBox(height: tiny ? 2 : 4),
                              Text(
                                phoneLoginMode ? 'Enter your number to receive a one-time code.' : 'Sign in to continue your Sawari journey.',
                                style: TextStyle(color: Colors.white70, fontSize: tiny ? 11 : 12, height: 1.25),
                              ),
                              SizedBox(height: tiny ? 8 : 11),
                              if (!phoneLoginMode) ...[
                                _inputField(controller: emailController, label: 'Email', hint: 'Enter your email', icon: Icons.email_outlined, keyboardType: TextInputType.emailAddress),
                                SizedBox(height: gap),
                                _inputField(
                                  controller: passwordController,
                                  label: 'Password',
                                  hint: 'Enter your password',
                                  icon: Icons.lock_outline_rounded,
                                  obscureText: hidePassword,
                                  suffixIcon: IconButton(
                                    onPressed: () => setState(() => hidePassword = !hidePassword),
                                    icon: Icon(hidePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: Colors.white70),
                                  ),
                                ),
                                SizedBox(height: gap),
                                _mainButton(text: 'Login', icon: Icons.arrow_forward_rounded, loading: loading, onPressed: _emailLogin),
                                SizedBox(height: gap),
                                _outlineButton(text: 'Continue with Google', icon: Icons.g_mobiledata, onPressed: loading ? null : _googleLogin),
                                SizedBox(height: gap),
                                _outlineButton(text: 'Login with Phone', icon: Icons.phone_android_rounded, onPressed: loading ? null : () => setState(() => phoneLoginMode = true)),
                              ] else ...[
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: TextButton.icon(
                                    onPressed: () => setState(() => phoneLoginMode = false),
                                    icon: const Icon(Icons.arrow_back_rounded, size: 18),
                                    label: const Text('Back to email login'),
                                    style: TextButton.styleFrom(foregroundColor: lime, padding: const EdgeInsets.symmetric(vertical: 3)),
                                  ),
                                ),
                                _inputField(controller: phoneController, label: 'Phone Number', hint: '+92 300 1234567', icon: Icons.phone_outlined, keyboardType: TextInputType.phone),
                                SizedBox(height: gap),
                                _mainButton(text: 'Send OTP', icon: Icons.sms_outlined, loading: loading, onPressed: _phoneLogin),
                                SizedBox(height: gap),
                                const Text('You can also log in with Email/Password or Google.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white70, height: 1.25, fontSize: 11)),
                              ],
                            ],
                          ),
                        ),
                        SizedBox(height: tiny ? 6 : (compact ? 8 : 12)),
                        Row(children: [
                          Expanded(child: Divider(color: Colors.white.withOpacity(0.25))),
                          Padding(padding: const EdgeInsets.symmetric(horizontal: 10), child: Text('NEW TO SAWARI?', style: TextStyle(color: Colors.white70, fontSize: tiny ? 9 : 10, fontWeight: FontWeight.w800, letterSpacing: 1.2))),
                          Expanded(child: Divider(color: Colors.white.withOpacity(0.25))),
                        ]),
                        SizedBox(height: tiny ? 5 : 7),
                        SizedBox(
                          height: tiny ? 38 : (compact ? 42 : 46),
                          child: OutlinedButton.icon(
                            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PassengerRegistrationScreen())),
                            icon: const Icon(Icons.person_add_alt_1_rounded, size: 19),
                            label: const Text('Create Passenger Account', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                            style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Color(0xFFB7FF18)), backgroundColor: const Color(0x3310171A), padding: const EdgeInsets.symmetric(horizontal: 10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13))),
                          ),
                        ),
                        SizedBox(height: tiny ? 5 : 7),
                        SizedBox(
                          height: tiny ? 38 : (compact ? 42 : 46),
                          child: OutlinedButton.icon(
                            onPressed: loading ? null : () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DriverLoginScreen())),
                            icon: const Icon(Icons.drive_eta_rounded, color: lime, size: 19),
                            label: const Text('Driver Login', style: TextStyle(color: lime, fontWeight: FontWeight.w800, fontSize: 12)),
                            style: OutlinedButton.styleFrom(foregroundColor: lime, side: const BorderSide(color: Color(0xFFB7FF18)), backgroundColor: const Color(0x3310171A), padding: const EdgeInsets.symmetric(horizontal: 10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13))),
                          ),
                        ),
                        SizedBox(height: tiny ? 5 : 7),
                        SizedBox(
                          height: tiny ? 38 : (compact ? 42 : 46),
                          child: OutlinedButton.icon(
                            onPressed: loading ? null : () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DriverAccountRegistrationScreen())),
                            icon: const Icon(Icons.local_taxi_rounded, color: lime, size: 19),
                            label: const Text('Create Driver Account', style: TextStyle(color: lime, fontWeight: FontWeight.w800, fontSize: 12)),
                            style: OutlinedButton.styleFrom(foregroundColor: lime, side: const BorderSide(color: Color(0xFFB7FF18)), backgroundColor: const Color(0x3310171A), padding: const EdgeInsets.symmetric(horizontal: 10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13))),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _inputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool obscureText = false,
    TextInputType? keyboardType,
    Widget? suffixIcon,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white, fontSize: 15),
      cursorColor: const Color(0xFFB7FF18),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: const TextStyle(color: Colors.white60),
        hintStyle: const TextStyle(color: Colors.white30),
        prefixIcon: Icon(icon, color: const Color(0xFFB7FF18)),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: const Color(0xFF0A181D),
        contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Colors.white12)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Colors.white12)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFB7FF18), width: 1.5)),
      ),
    );
  }

  Widget _mainButton({
    required String text,
    required IconData icon,
    required bool loading,
    required VoidCallback? onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 44,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: loading
            ? const SizedBox(
          width: 20,
          height: 20,
          child:
          CircularProgressIndicator(
            strokeWidth: 2,
            color: Colors.white,
          ),
        )
            : Icon(icon),
        label: Text(
          loading ? 'Please wait...' : text,
          style: const TextStyle(
            fontSize: 14,
            fontWeight:
            FontWeight.bold,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor:
          const Color(0xFFB7FF18),
          foregroundColor:
          const Color(0xFF061116),
          shape:
          RoundedRectangleBorder(
            borderRadius:
            BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }

  Widget _outlineButton({
    required String text,
    required IconData icon,
    required VoidCallback? onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 42,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(
          text,
          style: const TextStyle(
            fontWeight:
            FontWeight.bold,
          ),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor:
          Colors.white,
          side: const BorderSide(
            color: Color(0xFFB7FF18),
          ),
          shape:
          RoundedRectangleBorder(
            borderRadius:
            BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    phoneController.dispose();
    super.dispose();
  }
}

/* ============================================================
   PHONE OTP
============================================================ */

class PhoneOtpScreen extends StatefulWidget {
  final String verificationId;
  final String phoneNumber;

  const PhoneOtpScreen({
    super.key,
    required this.verificationId,
    required this.phoneNumber,
  });

  @override
  State<PhoneOtpScreen> createState() =>
      _PhoneOtpScreenState();
}

class _PhoneOtpScreenState
    extends State<PhoneOtpScreen> {
  final otpController =
  TextEditingController();

  bool loading = false;

  Future<void> _verifyOtp() async {
    final otp =
    otpController.text.trim();

    if (otp.length < 6) {
      _message(
        'Please enter the 6-digit OTP.',
      );
      return;
    }

    setState(() => loading = true);

    try {
      final credential =
      PhoneAuthProvider.credential(
        verificationId:
        widget.verificationId,
        smsCode: otp,
      );

      final result =
      await FirebaseAuth.instance
          .signInWithCredential(
        credential,
      );

      final user = result.user;

      if (user != null) {
        final userRef =
        FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid);

        final doc =
        await userRef.get();

        if (!doc.exists) {
          await userRef.set({
            'uid': user.uid,
            'name': 'Passenger',
            'phone':
            widget.phoneNumber,
            'email':
            user.email ?? '',
            'role': 'passenger',
            'createdAt':
            FieldValue.serverTimestamp(),
          });
        }
      }
    } on FirebaseAuthException catch (e) {
      _message(
        e.message ??
            'OTP verification failed.',
      );
    } catch (e) {
      debugPrint('$e');
      _message(
        'OTP verification failed.',
      );
    }

    if (mounted) {
      setState(() => loading = false);
    }
  }

  void _message(String text) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(content: Text(text)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title:
        const Text('Verify Phone'),
      ),
      body: SafeArea(
        child: Padding(
          padding:
          const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 35),

              const Icon(
                Icons.sms_outlined,
                size: 70,
                color:
                Color(0xFF0F9D58),
              ),

              const SizedBox(height: 20),

              const Text(
                'Enter OTP',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight:
                  FontWeight.bold,
                ),
              ),

              const SizedBox(height: 10),

              Text(
                'OTP sent to ${widget.phoneNumber}',
                textAlign:
                TextAlign.center,
                style: const TextStyle(
                  color:
                  Colors.black54,
                ),
              ),

              const SizedBox(height: 30),

              TextField(
                controller:
                otpController,
                keyboardType:
                TextInputType.number,
                maxLength: 6,
                textAlign:
                TextAlign.center,
                style: const TextStyle(
                  fontSize: 25,
                  fontWeight:
                  FontWeight.bold,
                  letterSpacing: 8,
                ),
                decoration:
                InputDecoration(
                  hintText: '------',
                  border:
                  OutlineInputBorder(
                    borderRadius:
                    BorderRadius.circular(
                      16,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: loading
                      ? null
                      : _verifyOtp,
                  child: loading
                      ? const CircularProgressIndicator()
                      : const Text(
                    'Verify & Login',
                    style:
                    TextStyle(
                      fontSize: 17,
                      fontWeight:
                      FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    otpController.dispose();
    super.dispose();
  }
}

/* ============================================================
   PASSENGER REGISTRATION
============================================================ */

class PassengerRegistrationScreen
    extends StatefulWidget {
  const PassengerRegistrationScreen({
    super.key,
  });

  @override
  State<PassengerRegistrationScreen>
  createState() =>
      _PassengerRegistrationScreenState();
}

class _PassengerRegistrationScreenState
    extends State<
        PassengerRegistrationScreen> {
  final nameController =
  TextEditingController();

  final emailController =
  TextEditingController();

  final phoneController =
  TextEditingController();

  final passwordController =
  TextEditingController();

  bool loading = false;
  bool hidePassword = true;

  Future<void> _register() async {
    final name =
    nameController.text.trim();

    final email =
    emailController.text.trim();

    final phone =
    phoneController.text.trim();

    final password =
    passwordController.text.trim();

    if (name.isEmpty ||
        email.isEmpty ||
        phone.isEmpty ||
        password.isEmpty) {
      _message(
        'Full Name, Email, Phone Number and Password are required.',
      );
      return;
    }

    if (password.length < 6) {
      _message(
        'Password must be at least 6 characters long.',
      );
      return;
    }

    setState(() => loading = true);

    try {
      final credential =
      await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user =
          credential.user;

      if (user == null) {
        throw Exception(
          'User creation failed.',
        );
      }

      await user.updateDisplayName(
        name,
      );

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set({
        'uid': user.uid,
        'name': name,
        'email': email,
        'phone': phone,
        'role': 'passenger',
        'createdAt':
        FieldValue.serverTimestamp(),
      });

      _message(
        'Passenger account created successfully.',
      );
    } on FirebaseAuthException catch (e) {
      _message(
        _firebaseError(e),
      );
    } catch (e) {
      debugPrint('$e');
      _message(
        'Registration failed.',
      );
    }

    if (mounted) {
      setState(() => loading = false);
    }
  }

  String _firebaseError(
      FirebaseAuthException e,
      ) {
    switch (e.code) {
      case 'invalid-email':
        return 'Invalid email address.';
      case 'email-already-in-use':
        return 'This email is already registered.';
      case 'weak-password':
        return 'Password is too weak.';
      case 'network-request-failed':
        return 'Please check your internet connection.';
      default:
        return e.message ??
            'Registration error.';
    }
  }

  void _message(String text) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        behavior:
        SnackBarBehavior.floating,
        content: Text(text),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscureText = false,
    TextInputType? keyboardType,
    Widget? suffixIcon,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white),
      cursorColor: const Color(0xFFB7FF18),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white60),
        prefixIcon: Icon(icon, color: const Color(0xFFB7FF18)),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: const Color(0xFF0A181D),
        contentPadding: const EdgeInsets.symmetric(vertical: 17, horizontal: 16),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Colors.white12)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Colors.white12)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFB7FF18), width: 1.5)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const lime = Color(0xFFB7FF18);
    return Scaffold(
      backgroundColor: const Color(0xFF061116),
      appBar: AppBar(
        backgroundColor: const Color(0xFF061116),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Passenger Signup', style: TextStyle(fontWeight: FontWeight.w900)),
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF0C241B), Color(0xFF061116), Color(0xFF020607)])),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(22, 14, 22, 28),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: const Color(0xE609171B), borderRadius: BorderRadius.circular(26), border: Border.all(color: const Color(0x449CFF16))),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(child: Container(width: 58, height: 58, decoration: BoxDecoration(color: lime, borderRadius: BorderRadius.circular(20)), child: const Icon(Icons.person_add_alt_1_rounded, size: 32, color: Color(0xFF061116)))),
                      const SizedBox(height: 10),
                      const Text('Join SAWARI', textAlign: TextAlign.center, style: TextStyle(color: lime, fontSize: 29, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
                      const SizedBox(height: 8),
                      const Text('Create your passenger account and start your journey.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white60, height: 1.45)),
                      const SizedBox(height: 14),
                      _field(controller: nameController, label: 'Full Name', icon: Icons.person_outline_rounded),
                      const SizedBox(height: 8),
                      _field(controller: emailController, label: 'Email', icon: Icons.email_outlined, keyboardType: TextInputType.emailAddress),
                      const SizedBox(height: 8),
                      _field(controller: phoneController, label: 'Phone Number', icon: Icons.phone_outlined, keyboardType: TextInputType.phone),
                      const SizedBox(height: 8),
                      _field(controller: passwordController, label: 'Password', icon: Icons.lock_outline_rounded, obscureText: hidePassword, suffixIcon: IconButton(onPressed: () => setState(() => hidePassword = !hidePassword), icon: Icon(hidePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: Colors.white54))),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: loading ? null : _register,
                          style: ElevatedButton.styleFrom(backgroundColor: lime, foregroundColor: const Color(0xFF061116), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                          child: loading ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Color(0xFF061116))) : const Text('Create Passenger Account', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextButton(onPressed: loading ? null : () => Navigator.pop(context), style: TextButton.styleFrom(foregroundColor: lime), child: const Text('Already have an account? Login')),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    passwordController.dispose();
    super.dispose();
  }
}

/* ============================================================
   GOOGLE PASSENGER REGISTRATION
============================================================ */

class GooglePassengerRegistration
    extends StatefulWidget {
  final User user;
  final String googleEmail;
  final String googleName;

  const GooglePassengerRegistration({
    super.key,
    required this.user,
    required this.googleEmail,
    required this.googleName,
  });

  @override
  State<GooglePassengerRegistration>
  createState() =>
      _GooglePassengerRegistrationState();
}

class _GooglePassengerRegistrationState
    extends State<
        GooglePassengerRegistration> {
  final phoneController =
  TextEditingController();

  bool loading = false;

  Future<void> _completeRegistration() async {
    final phone =
    phoneController.text.trim();

    if (phone.isEmpty) {
      _message(
        'Please enter your phone number.',
      );
      return;
    }

    setState(() => loading = true);

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.user.uid)
          .set({
        'uid': widget.user.uid,
        'name':
        widget.googleName.isNotEmpty
            ? widget.googleName
            : 'Passenger',
        'email': widget.googleEmail,
        'phone': phone,
        'role': 'passenger',
        'provider': 'google',
        'createdAt':
        FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) =>
          const HomeScreen(),
        ),
            (route) => false,
      );
    } catch (e) {
      debugPrint('$e');
      _message(
        'Registration could not be completed.',
      );
    }

    if (mounted) {
      setState(() => loading = false);
    }
  }

  void _message(String text) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content: Text(text),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Complete Registration',
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding:
          const EdgeInsets.all(24),
          child: Column(
            children: [
              Container(
                width: 90,
                height: 90,
                decoration:
                BoxDecoration(
                  color:
                  const Color(
                    0xFFE2F7EA,
                  ),
                  borderRadius:
                  BorderRadius.circular(
                    28,
                  ),
                ),
                child: const Icon(
                  Icons.verified_user_outlined,
                  size: 48,
                  color:
                  Color(0xFF0F9D58),
                ),
              ),

              const SizedBox(height: 22),

              const Text(
                'Almost Done!',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight:
                  FontWeight.w900,
                ),
              ),

              const SizedBox(height: 10),

              Text(
                'Welcome ${widget.googleName.isNotEmpty ? widget.googleName : 'Passenger'}.\n'
                    'Just add your phone number.',
                textAlign:
                TextAlign.center,
                style: const TextStyle(
                  color:
                  Colors.black54,
                  height: 1.5,
                ),
              ),

              const SizedBox(height: 30),

              TextField(
                controller:
                phoneController,
                keyboardType:
                TextInputType.phone,
                decoration:
                InputDecoration(
                  labelText:
                  'Phone Number',
                  hintText:
                  '+92 300 1234567',
                  prefixIcon:
                  const Icon(
                    Icons.phone_outlined,
                  ),
                  filled: true,
                  fillColor:
                  Colors.grey.shade100,
                  border:
                  OutlineInputBorder(
                    borderRadius:
                    BorderRadius.circular(
                      16,
                    ),
                    borderSide:
                    BorderSide.none,
                  ),
                ),
              ),

              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                height: 55,
                child:
                ElevatedButton(
                  onPressed:
                  loading
                      ? null
                      : _completeRegistration,
                  style:
                  ElevatedButton
                      .styleFrom(
                    backgroundColor:
                    const Color(
                      0xFF0F9D58,
                    ),
                    foregroundColor:
                    Colors.white,
                    shape:
                    RoundedRectangleBorder(
                      borderRadius:
                      BorderRadius
                          .circular(
                        16,
                      ),
                    ),
                  ),
                  child: loading
                      ? const CircularProgressIndicator(
                    color:
                    Colors.white,
                  )
                      : const Text(
                    'Continue to Ride',
                    style:
                    TextStyle(
                      fontSize:
                      17,
                      fontWeight:
                      FontWeight
                          .bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    phoneController.dispose();
    super.dispose();
  }
}

/* ============================================================
   DRIVER REGISTRATION
============================================================ */

class DriverRegistrationScreen extends StatefulWidget {
  final String vehicle;
  const DriverRegistrationScreen({super.key, required this.vehicle});

  @override
  State<DriverRegistrationScreen> createState() => _DriverRegistrationScreenState();
}

class _DriverRegistrationScreenState extends State<DriverRegistrationScreen> {
  final formKey = GlobalKey<FormState>();
  final name = TextEditingController();
  final phone = TextEditingController();
  final address = TextEditingController();
  final license = TextEditingController();
  final cnic = TextEditingController();
  final vehicleNumber = TextEditingController();
  final model = TextEditingController();
  final color = TextEditingController();
  bool saving = false;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    name.text = user?.displayName ?? '';
    phone.text = user?.phoneNumber ?? '';
    _loadDriverAccountDetails();
  }

  Future<void> _loadDriverAccountDetails() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final data = doc.data();
      if (!mounted || data == null) return;
      if (name.text.trim().isEmpty) name.text = data['name']?.toString() ?? '';
      if (phone.text.trim().isEmpty) phone.text = data['phone']?.toString() ?? '';
    } catch (e) {
      debugPrint('Driver account details load error: $e');
    }
  }

  Future<void> submit() async {
    if (!formKey.currentState!.validate()) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    setState(() => saving = true);
    try {
      await user.updateDisplayName(name.text.trim());
      final driverData = <String, dynamic>{
        'uid': user.uid,
        'name': name.text.trim(),
        'email': user.email ?? '',
        'phone': phone.text.trim(),
        'address': address.text.trim(),
        'licenseNumber': license.text.trim(),
        'cnicNumber': cnic.text.trim(),
        'vehicleType': widget.vehicle,
        'vehicleNumber': vehicleNumber.text.trim(),
        'vehicleModel': model.text.trim(),
        'vehicleColor': color.text.trim(),
        'role': 'driver',
        'isOnline': false,
        'registrationComplete': true,
        'verificationRequired': false,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      await FirebaseFirestore.instance.collection('drivers').doc(user.uid).set(
        driverData,
        SetOptions(merge: true),
      );
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'uid': user.uid,
        'name': name.text.trim(),
        'email': user.email ?? '',
        'phone': phone.text.trim(),
        'role': 'driver',
        'accountType': 'driver',
        'driverRegistrationComplete': true,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => HomeScreen(initialRole: 'Driver', initialVehicle: widget.vehicle)),
            (route) => false,
      );
    } catch (e) {
      debugPrint('Driver profile Firestore save error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Driver details save nahi huay: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Widget field(TextEditingController c, String label, IconData icon, {TextInputType? type, int lines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: c, keyboardType: type, maxLines: lines,
        style: const TextStyle(color: Colors.white),
        validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white60),
          prefixIcon: Icon(icon, color: const Color(0xFFB7FF18)),
          filled: true, fillColor: const Color(0xFF0A181D),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Colors.white12)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFB7FF18), width: 1.5)),
          errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Colors.redAccent)),
          focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Colors.redAccent, width: 1.5)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF061116),
      appBar: AppBar(backgroundColor: Colors.transparent, foregroundColor: Colors.white, elevation: 0, title: const Text('Driver Registration', style: TextStyle(fontWeight: FontWeight.w900))),
      body: SafeArea(child: Form(key: formKey, child: ListView(padding: const EdgeInsets.fromLTRB(18, 8, 18, 30), children: [
        Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF0C3D2B), Color(0xFF071B20)]), borderRadius: BorderRadius.circular(24), border: Border.all(color: const Color(0x669CFF16))), child: Row(children: [
          Container(width: 60, height: 60, decoration: BoxDecoration(color: const Color(0xFFB7FF18), borderRadius: BorderRadius.circular(18)), child: const Icon(Icons.badge_rounded, color: Colors.black, size: 32)),
          const SizedBox(width: 14), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Complete your profile', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)), const SizedBox(height: 5), Text('Vehicle: ${widget.vehicle}', style: const TextStyle(color: Colors.white70))]))
        ])),
        const SizedBox(height: 22),
        const Text('Personal Information', style: TextStyle(color: Color(0xFFB7FF18), fontSize: 19, fontWeight: FontWeight.w900)),
        const SizedBox(height: 12),
        field(name, 'Full Name', Icons.person_outline),
        field(phone, 'Phone Number', Icons.phone_outlined, type: TextInputType.phone),
        field(address, 'Complete Address', Icons.location_on_outlined, lines: 2),
        const SizedBox(height: 6),
        const Text('Driving Documents', style: TextStyle(color: Color(0xFFB7FF18), fontSize: 19, fontWeight: FontWeight.w900)),
        const SizedBox(height: 12),
        field(license, 'Driver License Number', Icons.credit_card_outlined),
        field(cnic, 'CNIC Number', Icons.badge_outlined, type: TextInputType.number),
        const SizedBox(height: 6),
        const Text('Vehicle Information', style: TextStyle(color: Color(0xFFB7FF18), fontSize: 19, fontWeight: FontWeight.w900)),
        const SizedBox(height: 12),
        field(vehicleNumber, 'Vehicle Number', Icons.confirmation_number_outlined),
        field(model, 'Vehicle Model', Icons.directions_car_filled_outlined),
        field(color, 'Vehicle Color', Icons.palette_outlined),
        const SizedBox(height: 8),
        SizedBox(height: 58, child: ElevatedButton(onPressed: saving ? null : submit, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFB7FF18), foregroundColor: Colors.black, disabledBackgroundColor: Colors.white12, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))), child: saving ? const CircularProgressIndicator(color: Colors.black) : const Text('Complete Driver Registration', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16))))
      ]))),
    );
  }

  @override
  void dispose() { name.dispose(); phone.dispose(); address.dispose(); license.dispose(); cnic.dispose(); vehicleNumber.dispose(); model.dispose(); color.dispose(); super.dispose(); }
}

/* ============================================================
   SETTINGS
============================================================ */

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override State<SettingsScreen> createState() => _SettingsScreenState();
}
class _SettingsScreenState extends State<SettingsScreen> {
  bool notifications = true;
  bool location = true;
  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return Scaffold(backgroundColor: const Color(0xFF061116), appBar: AppBar(backgroundColor: Colors.transparent, foregroundColor: Colors.white, elevation: 0, title: const Text('Settings', style: TextStyle(fontWeight: FontWeight.w900))), body: ListView(padding: const EdgeInsets.all(18), children: [
      Container(padding: const EdgeInsets.all(18), decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF0C3D2B), Color(0xFF071B20)]), borderRadius: BorderRadius.circular(22), border: Border.all(color: const Color(0x559CFF16))), child: Row(children: [const CircleAvatar(radius: 29, backgroundColor: Color(0xFFB7FF18), child: Icon(Icons.person, color: Colors.black, size: 31)), const SizedBox(width: 13), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(user?.displayName ?? 'Ride User', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)), const SizedBox(height: 4), Text(user?.email ?? user?.phoneNumber ?? '', style: const TextStyle(color: Colors.white60), overflow: TextOverflow.ellipsis)]))])),
      const SizedBox(height: 20), const Text('PREFERENCES', style: TextStyle(color: Color(0xFFB7FF18), fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1.4)), const SizedBox(height: 8),
      _tile(Icons.notifications_none_rounded, 'Notifications', 'Ride updates and alerts', Switch(value: notifications, activeColor: const Color(0xFFB7FF18), onChanged: (v) => setState(() => notifications = v))),
      _tile(Icons.location_on_outlined, 'Location', 'Use location for nearby rides', Switch(value: location, activeColor: const Color(0xFFB7FF18), onChanged: (v) => setState(() => location = v))),
      const SizedBox(height: 8), const Text('ACCOUNT', style: TextStyle(color: Color(0xFFB7FF18), fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1.4)), const SizedBox(height: 8),
      _tile(Icons.person_outline_rounded, 'Profile', 'Your account information', null, onTap: () => showDialog(context: context, builder: (_) => AlertDialog(title: const Text('Profile'), content: Text('Name: ${user?.displayName ?? 'Not set'}\nEmail: ${user?.email ?? 'Not set'}\nPhone: ${user?.phoneNumber ?? 'Not set'}'), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))]))),
      _tile(Icons.lock_outline_rounded, 'Privacy & Security', 'Account security', null, onTap: () => showDialog(context: context, builder: (_) => AlertDialog(title: const Text('Privacy & Security'), content: const Text('Your account is protected by Firebase Authentication.'), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))]))),
    ]));
  }
  Widget _tile(IconData icon, String title, String sub, Widget? trailing, {VoidCallback? onTap}) => Container(margin: const EdgeInsets.only(bottom: 9), decoration: BoxDecoration(color: const Color(0xFF0A181D), borderRadius: BorderRadius.circular(18), border: Border.all(color: Colors.white10)), child: ListTile(onTap: onTap, leading: Container(width: 45, height: 45, decoration: BoxDecoration(color: const Color(0xFF102A25), borderRadius: BorderRadius.circular(14)), child: Icon(icon, color: const Color(0xFFB7FF18))), title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)), subtitle: Text(sub, style: const TextStyle(color: Colors.white54)), trailing: trailing ?? const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white30, size: 16)));
}

/* ============================================================
   RIDE HISTORY
============================================================ */

class RideHistoryScreen extends StatelessWidget {
  const RideHistoryScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return Scaffold(backgroundColor: const Color(0xFF061116), appBar: AppBar(backgroundColor: Colors.transparent, foregroundColor: Colors.white, elevation: 0, title: const Text('Ride History', style: TextStyle(fontWeight: FontWeight.w900))), body: user == null ? const Center(child: Text('Please login first.', style: TextStyle(color: Colors.white))) : StreamBuilder<QuerySnapshot>(stream: FirebaseFirestore.instance.collection('rides').where('passengerId', isEqualTo: user.uid).snapshots(), builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: Color(0xFFB7FF18)));
      final docs = snapshot.data?.docs ?? [];
      if (docs.isEmpty) return const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.history_rounded, size: 60, color: Color(0xFFB7FF18)), SizedBox(height: 12), Text('No rides yet', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)), SizedBox(height: 5), Text('Your rides will appear here.', style: TextStyle(color: Colors.white54))]));
      final sorted = [...docs]; sorted.sort((a,b) { final ad=(a.data() as Map<String,dynamic>)['createdAt']; final bd=(b.data() as Map<String,dynamic>)['createdAt']; final at=ad is Timestamp?ad.toDate():DateTime(2000); final bt=bd is Timestamp?bd.toDate():DateTime(2000); return bt.compareTo(at); });
      return ListView.builder(padding: const EdgeInsets.fromLTRB(16, 8, 16, 24), itemCount: sorted.length, itemBuilder: (_, i) { final d=sorted[i].data() as Map<String,dynamic>; final type=d['rideType']?.toString()??'Car'; final status=d['status']?.toString()??'unknown'; final fare=d['fare']?.toString()??'0'; final to=d['destination']?.toString()??'Destination'; final icon=type=='Bike'?Icons.two_wheeler_rounded:type=='Rickshaw'?Icons.electric_rickshaw_rounded:Icons.directions_car_rounded; return Container(margin: const EdgeInsets.only(bottom: 11), padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: const Color(0xFF0A181D), borderRadius: BorderRadius.circular(19), border: Border.all(color: Colors.white10)), child: Row(children: [Container(width: 50,height:50,decoration:BoxDecoration(color:const Color(0xFF102A25),borderRadius:BorderRadius.circular(15)),child:Icon(icon,color:const Color(0xFFB7FF18))),const SizedBox(width:12),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(to,maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(color:Colors.white,fontWeight:FontWeight.w900,fontSize:16)),const SizedBox(height:4),Text('$type • Rs. $fare',style:const TextStyle(color:Colors.white60)),const SizedBox(height:3),Text(status.toUpperCase(),style:const TextStyle(color:Color(0xFFB7FF18),fontSize:11,fontWeight:FontWeight.w900))]))])); });
    }));
  }
}

/* ============================================================
   PASSENGER RATING
============================================================ */

class RatingScreen extends StatefulWidget {
  const RatingScreen({super.key});
  @override State<RatingScreen> createState() => _RatingScreenState();
}
class _RatingScreenState extends State<RatingScreen> {
  int rating = 0;
  final comment = TextEditingController();
  bool saving = false;
  Future<void> submit() async {
    final user=FirebaseAuth.instance.currentUser;
    if(user==null)return;
    if(rating==0){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Please select a rating.')));return;}
    setState(()=>saving=true);
    try { await FirebaseFirestore.instance.collection('ratings').add({'passengerId':user.uid,'passengerName':user.displayName??'Passenger','rating':rating,'comment':comment.text.trim(),'createdAt':FieldValue.serverTimestamp()}); if(mounted){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Thank you! Your rating has been saved.'))); setState(()=>rating=0); comment.clear();} } catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Rating save nahi ho saki.')));} finally {if(mounted)setState(()=>saving=false);}
  }
  @override Widget build(BuildContext context)=>Scaffold(backgroundColor:const Color(0xFF061116),appBar:AppBar(backgroundColor:Colors.transparent,foregroundColor:Colors.white,elevation:0,title:const Text('Rate Your Ride',style:TextStyle(fontWeight:FontWeight.w900))),body:ListView(padding:const EdgeInsets.all(20),children:[Container(padding:const EdgeInsets.all(24),decoration:BoxDecoration(gradient:const LinearGradient(colors:[Color(0xFF0C3D2B),Color(0xFF071B20)]),borderRadius:BorderRadius.circular(25),border:Border.all(color:const Color(0x559CFF16))),child:const Column(children:[Icon(Icons.star_rounded,color:Color(0xFFB7FF18),size:58),SizedBox(height:10),Text('How was your ride?',style:TextStyle(color:Colors.white,fontSize:24,fontWeight:FontWeight.w900)),SizedBox(height:6),Text('Your feedback helps us improve.',style:TextStyle(color:Colors.white60))])),const SizedBox(height:20),Row(mainAxisAlignment:MainAxisAlignment.center,children:List.generate(5,(i){final n=i+1;return IconButton(onPressed:()=>setState(()=>rating=n),iconSize:42,icon:Icon(n<=rating?Icons.star_rounded:Icons.star_border_rounded,color:const Color(0xFFB7FF18)));})),const SizedBox(height:8),TextField(controller:comment,maxLines:4,style:const TextStyle(color:Colors.white),decoration:InputDecoration(hintText:'Write your feedback (optional)',hintStyle:const TextStyle(color:Colors.white38),filled:true,fillColor:const Color(0xFF0A181D),border:OutlineInputBorder(borderRadius:BorderRadius.all(Radius.circular(18)),borderSide:BorderSide(color:Colors.white12)),enabledBorder:OutlineInputBorder(borderRadius:BorderRadius.all(Radius.circular(18)),borderSide:BorderSide(color:Colors.white12)),focusedBorder:OutlineInputBorder(borderRadius:BorderRadius.all(Radius.circular(18)),borderSide:BorderSide(color:Color(0xFFB7FF18),width:1.5)))),const SizedBox(height:18),SizedBox(height:56,child:ElevatedButton(onPressed:saving?null:submit,style:ElevatedButton.styleFrom(backgroundColor:const Color(0xFFB7FF18),foregroundColor:Colors.black,shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(18))),child:saving?const CircularProgressIndicator(color:Colors.black):const Text('Submit Rating',style:TextStyle(fontWeight:FontWeight.w900,fontSize:16))))]));
  @override void dispose(){comment.dispose();super.dispose();}
}

/* ============================================================
   HOME SCREEN
   EXISTING RIDE APP FUNCTIONALITY
============================================================ */

/* ============================================================
   SEPARATE DRIVER LOGIN
============================================================ */

class DriverLoginScreen extends StatefulWidget {
  const DriverLoginScreen({super.key});
  @override
  State<DriverLoginScreen> createState() => _DriverLoginScreenState();
}

class _DriverLoginScreenState extends State<DriverLoginScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  bool loading = false;
  bool hidePassword = true;

  Future<void> _login() async {
    final email = emailController.text.trim();
    final password = passwordController.text;
    if (email.isEmpty || password.isEmpty) {
      _show('Email aur password enter karein.');
      return;
    }
    setState(() => loading = true);
    try {
      final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email, password: password,
      );
      final user = credential.user;
      if (user == null) throw Exception('User account nahi mila.');
      final driverDoc = await FirebaseFirestore.instance.collection('drivers').doc(user.uid).get();
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final driverRole = driverDoc.exists || userDoc.data()?['role'] == 'driver' || userDoc.data()?['accountType'] == 'driver';
      if (!driverRole) {
        await FirebaseAuth.instance.signOut();
        if (mounted) _show('Yeh driver account nahi hai. Passenger Login use karein.');
      }
      // On successful driver login, AuthGate listens to FirebaseAuth and opens
      // the existing driver flow based on the saved role; no duplicate dashboard is created.
    } on FirebaseAuthException catch (e) {
      if (mounted) _show(_error(e));
    } catch (e) {
      debugPrint('Driver login error: $e');
      if (mounted) _show('Login complete nahi hua. Internet aur Firebase settings check karein.');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  String _error(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email': return 'Email address valid nahi hai.';
      case 'user-not-found': return 'Is email par account nahi mila.';
      case 'wrong-password':
      case 'invalid-credential': return 'Email ya password ghalat hai.';
      case 'network-request-failed': return 'Internet connection check karein.';
      default: return e.message ?? 'Driver login fail ho gaya.';
    }
  }

  void _show(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(behavior: SnackBarBehavior.floating, content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    const lime = Color(0xFFB7FF18);
    const bg = Color(0xFF061116);
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(backgroundColor: bg, foregroundColor: Colors.white, elevation: 0, title: const Text('Driver Login', style: TextStyle(fontWeight: FontWeight.w900))),
      body: Container(
        decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF0C241B), bg, Color(0xFF020607)])),
        child: SafeArea(child: LayoutBuilder(builder: (context, constraints) {
          final compact = constraints.maxHeight < 650;
          return Center(child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: 22, vertical: compact ? 6 : 18),
            child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 440), child: Container(
              padding: EdgeInsets.all(compact ? 18 : 24),
              decoration: BoxDecoration(color: const Color(0xE609171B), borderRadius: BorderRadius.circular(26), border: Border.all(color: const Color(0x669CFF16)), boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 22, offset: Offset(0, 8))]),
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Center(child: Container(width: 68, height: 68, decoration: BoxDecoration(color: lime, borderRadius: BorderRadius.circular(22)), child: const Icon(Icons.local_taxi_rounded, size: 38, color: bg))),
                const SizedBox(height: 15),
                const Text('Welcome, Driver', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900)),
                const SizedBox(height: 6),
                const Text('Sign in to continue driving with SAWARI.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white60, height: 1.4)),
                SizedBox(height: compact ? 18 : 26),
                TextField(controller: emailController, keyboardType: TextInputType.emailAddress, autofillHints: const [AutofillHints.email], style: const TextStyle(color: Colors.white), decoration: _dec('Email Address', Icons.email_outlined)),
                const SizedBox(height: 13),
                TextField(controller: passwordController, obscureText: hidePassword, autofillHints: const [AutofillHints.password], style: const TextStyle(color: Colors.white), decoration: _dec('Password', Icons.lock_outline_rounded).copyWith(suffixIcon: IconButton(onPressed: () => setState(() => hidePassword = !hidePassword), icon: Icon(hidePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: Colors.white60)))),
                SizedBox(height: compact ? 16 : 22),
                SizedBox(height: 52, child: ElevatedButton.icon(onPressed: loading ? null : _login, icon: loading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: bg)) : const Icon(Icons.arrow_forward_rounded), label: Text(loading ? 'Please wait...' : 'Login as Driver', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)), style: ElevatedButton.styleFrom(backgroundColor: lime, foregroundColor: bg, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))))),
                const SizedBox(height: 12),
                TextButton(onPressed: loading ? null : () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DriverAccountRegistrationScreen())), style: TextButton.styleFrom(foregroundColor: lime), child: const Text('New driver? Create an account')),
                TextButton(onPressed: loading ? null : () => Navigator.pop(context), style: TextButton.styleFrom(foregroundColor: Colors.white70), child: const Text('Back to main login')),
              ]),
            )),
          ));
        })),
      ),
    );
  }

  InputDecoration _dec(String label, IconData icon) => InputDecoration(
    labelText: label, labelStyle: const TextStyle(color: Colors.white60), prefixIcon: Icon(icon, color: const Color(0xFFB7FF18)),
    filled: true, fillColor: const Color(0xFF0A181D), contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Colors.white12)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Colors.white12)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFB7FF18), width: 1.5)),
  );

  @override
  void dispose() { emailController.dispose(); passwordController.dispose(); super.dispose(); }
}

/* ============================================================
   DRIVER ACCOUNT SIGNUP
============================================================ */

class DriverAccountRegistrationScreen extends StatefulWidget {
  const DriverAccountRegistrationScreen({super.key});

  @override
  State<DriverAccountRegistrationScreen> createState() =>
      _DriverAccountRegistrationScreenState();
}

class _DriverAccountRegistrationScreenState
    extends State<DriverAccountRegistrationScreen> {
  final formKey = GlobalKey<FormState>();
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final phoneController = TextEditingController();
  final passwordController = TextEditingController();
  bool loading = false;
  bool hidePassword = true;

  Future<void> _createDriverAccount() async {
    if (!(formKey.currentState?.validate() ?? false)) return;

    final name = nameController.text.trim();
    final email = emailController.text.trim();
    final phone = phoneController.text.trim();
    final password = passwordController.text;

    setState(() => loading = true);
    try {
      final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = credential.user;
      if (user == null) throw Exception('Driver account could not be created.');

      await user.updateDisplayName(name);
      final now = FieldValue.serverTimestamp();
      // Save a driver record immediately, so AuthGate can identify this account
      // as a driver even before the vehicle/profile onboarding is completed.
      await FirebaseFirestore.instance.collection('drivers').doc(user.uid).set({
        'uid': user.uid,
        'name': name,
        'email': email,
        'phone': phone,
        'role': 'driver',
        'isOnline': false,
        'registrationComplete': false,
        'verificationRequired': false,
        'createdAt': now,
        'updatedAt': now,
      }, SetOptions(merge: true));

      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'uid': user.uid,
        'name': name,
        'email': email,
        'phone': phone,
        'role': 'driver',
        'accountType': 'driver',
        'driverRegistrationComplete': false,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const DriverVehicleScreen()),
            (route) => false,
      );
    } on FirebaseAuthException catch (e) {
      if (mounted) _showMessage(_authError(e));
    } catch (e) {
      debugPrint('Driver account creation error: $e');
      if (mounted) {
        _showMessage('Account create nahi ho saka. Internet aur Firebase settings check karein.');
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  String _authError(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'Email address valid nahi hai.';
      case 'email-already-in-use':
        return 'Is email par pehle se account bana hua hai. Login karein.';
      case 'weak-password':
        return 'Password kam az kam 6 characters ka hona chahiye.';
      case 'network-request-failed':
        return 'Internet connection check karein.';
      default:
        return e.message ?? 'Driver account create nahi ho saka.';
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  InputDecoration _decoration(String label, IconData icon) => InputDecoration(
    labelText: label,
    prefixIcon: Icon(icon, color: const Color(0xFFB7FF18)),
    filled: true,
    fillColor: const Color(0xFF0A181D),
    labelStyle: const TextStyle(color: Colors.white60),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: Colors.white12),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: Color(0xFFB7FF18), width: 1.5),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: Colors.redAccent),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: Colors.redAccent),
    ),
  );

  @override
  Widget build(BuildContext context) {
    const lime = Color(0xFFB7FF18);
    return Scaffold(
      backgroundColor: const Color(0xFF061116),
      appBar: AppBar(backgroundColor: const Color(0xFF061116), foregroundColor: Colors.white, elevation: 0, title: const Text('Driver Signup', style: TextStyle(fontWeight: FontWeight.w900))),
      body: Container(
        decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF0C241B), Color(0xFF061116), Color(0xFF020607)])),
        child: SafeArea(
          child: Form(
            key: formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
              children: [
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF0C3D2B), Color(0xFF071B20)]), borderRadius: BorderRadius.circular(25), border: Border.all(color: const Color(0x669CFF16))),
                  child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(Icons.local_taxi_rounded, color: lime, size: 44), SizedBox(height: 14), Text('Drive with SAWARI', style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900)), SizedBox(height: 7), Text('Create your driver login, then add your vehicle and profile details.', style: TextStyle(color: Colors.white70, height: 1.45))]),
                ),
                const SizedBox(height: 22),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(color: const Color(0xE609171B), borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.white12)),
                  child: Column(children: [
                    TextFormField(controller: nameController, textCapitalization: TextCapitalization.words, style: const TextStyle(color: Colors.white), decoration: _decoration('Full Name', Icons.person_outline_rounded), validator: (v) => v == null || v.trim().isEmpty ? 'Full name required hai.' : null),
                    const SizedBox(height: 14),
                    TextFormField(controller: emailController, keyboardType: TextInputType.emailAddress, autofillHints: const [AutofillHints.email], style: const TextStyle(color: Colors.white), decoration: _decoration('Email Address', Icons.email_outlined), validator: (v) { final value = v?.trim() ?? ''; if (value.isEmpty || !value.contains('@') || !value.contains('.')) return 'Valid email enter karein.'; return null; }),
                    const SizedBox(height: 14),
                    TextFormField(controller: phoneController, keyboardType: TextInputType.phone, style: const TextStyle(color: Colors.white), decoration: _decoration('Phone Number', Icons.phone_outlined), validator: (v) => v == null || v.trim().isEmpty ? 'Phone number required hai.' : null),
                    const SizedBox(height: 14),
                    TextFormField(controller: passwordController, obscureText: hidePassword, style: const TextStyle(color: Colors.white), decoration: _decoration('Password', Icons.lock_outline_rounded).copyWith(suffixIcon: IconButton(onPressed: () => setState(() => hidePassword = !hidePassword), icon: Icon(hidePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: Colors.white54))), validator: (v) => v == null || v.length < 6 ? 'Password kam az kam 6 characters ka hona chahiye.' : null),
                    const SizedBox(height: 22),
                    SizedBox(width: double.infinity, height: 56, child: ElevatedButton(onPressed: loading ? null : _createDriverAccount, style: ElevatedButton.styleFrom(backgroundColor: lime, foregroundColor: const Color(0xFF061116), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17))), child: loading ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Color(0xFF061116))) : const Text('Create Driver Account', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)))),
                    const SizedBox(height: 12),
                    const Text('Email/password account will be created without phone, CNIC or license verification for now.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white54, fontSize: 12, height: 1.4)),
                  ]),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    passwordController.dispose();
    super.dispose();
  }
}

/* ============================================================
   DRIVER LANDING / ONBOARDING
============================================================ */

class DriverLandingScreen extends StatelessWidget {
  const DriverLandingScreen({super.key});

  Future<void> _start(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const DriverLoadingScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF061116),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.memory(
            base64Decode(_driverLandingBg),
            fit: BoxFit.cover,
          ),
          Container(color: const Color(0xAA02090D)),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(22, 18, 22, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _glassIcon(Icons.menu_rounded),
                  const SizedBox(height: 28),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xDD006B43), Color(0xCC073A2A)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(25),
                      border: Border.all(color: const Color(0xFF9CFF16)),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x5500FF66),
                          blurRadius: 28,
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Get income with us',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 27,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _benefit(Icons.access_time_rounded, 'Flexible hours'),
                        const SizedBox(height: 11),
                        _benefit(
                          Icons.account_balance_wallet_outlined,
                          'Your prices',
                        ),
                        const SizedBox(height: 11),
                        _benefit(Icons.percent_rounded, 'Low service payments'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  InkWell(
                    borderRadius: BorderRadius.circular(24),
                    onTap: () => _start(context),
                    child: Container(
                      width: double.infinity,
                      height: 116,
                      padding: const EdgeInsets.symmetric(horizontal: 15),
                      decoration: BoxDecoration(
                        color: const Color(0xCC07151B),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: const Color(0xFF9CFF16),
                          width: 1.5,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x4400FF44),
                            blurRadius: 24,
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 102,
                            height: 88,
                            child: Image.memory(
                              base64Decode(_driverCarImg),
                              fit: BoxFit.contain,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Driver',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                SizedBox(height: 5),
                                Text(
                                  'Drive • Earn • Grow',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.arrow_forward_ios_rounded,
                            color: Color(0xFFB5FF22),
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    height: 58,
                    child: ElevatedButton(
                      onPressed: () => _start(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFB7FF18),
                        foregroundColor: Colors.black,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(19),
                        ),
                      ),
                      child: const Text(
                        'I already have an account',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                  Center(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        'Go to passenger mode',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _glassIcon(IconData icon) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: Colors.black45,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white24),
      ),
      child: Icon(icon, color: Colors.white, size: 28),
    );
  }

  Widget _benefit(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: Colors.white, size: 22),
        const SizedBox(width: 11),
        Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class DriverLoadingScreen extends StatefulWidget {
  const DriverLoadingScreen({super.key});

  @override
  State<DriverLoadingScreen> createState() => _DriverLoadingScreenState();
}

class _DriverLoadingScreenState extends State<DriverLoadingScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();

    Future.delayed(const Duration(milliseconds: 1200), () {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 350),
          pageBuilder: (_, animation, secondaryAnimation) =>
          const DriverVehicleScreen(),
          transitionsBuilder: (_, animation, secondaryAnimation, child) =>
              FadeTransition(opacity: animation, child: child),
        ),
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF040D12),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.memory(
            base64Decode(_driverLoadingBg),
            fit: BoxFit.cover,
          ),
          Container(color: const Color(0x99030A0E)),
          SafeArea(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedBuilder(
                    animation: _controller,
                    builder: (context, child) {
                      return Container(
                        width: 156,
                        height: 156,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFFB7FF18),
                            width: 5,
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x8800FF44),
                              blurRadius: 34,
                            ),
                          ],
                        ),
                        child: Center(
                          child: Container(
                            width: 126,
                            height: 126,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(0xDD06151A),
                            ),
                            child: const Icon(
                              Icons.person_pin_circle_rounded,
                              size: 78,
                              color: Color(0xFFB7FF18),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 30),
                  const Text(
                    'Ride App',
                    style: TextStyle(
                      color: Color(0xFFB7FF18),
                      fontSize: 43,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Preparing your driver experience',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 26),
                  const SizedBox(
                    width: 32,
                    height: 32,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      color: Color(0xFFB7FF18),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class DriverVehicleScreen extends StatefulWidget {
  const DriverVehicleScreen({super.key});

  @override
  State<DriverVehicleScreen> createState() => _DriverVehicleScreenState();
}

class _DriverVehicleScreenState extends State<DriverVehicleScreen> {
  String? selected;

  String _imageFor(String vehicle) {
    if (vehicle == 'Car') return _driverCarImg;
    if (vehicle == 'Rickshaw') return _driverRickshawImg;
    return _driverBikeImg;
  }

  String _sub(String vehicle) {
    if (vehicle == 'Car') return 'Comfortable & Premium';
    if (vehicle == 'Rickshaw') return 'Fast & Affordable';
    return 'Quick & Flexible';
  }

  Future<void> _continue() async {
    final vehicle = selected;
    if (vehicle == null) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DriverRegistrationScreen(vehicle: vehicle),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF061116),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Choose Your Vehicle',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(left: 4),
                child: Text(
                  'Select the vehicle you want to drive',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              _vehicleCard('Car'),
              const SizedBox(height: 15),
              _vehicleCard('Rickshaw'),
              const SizedBox(height: 15),
              _vehicleCard('Bike'),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 58,
                child: ElevatedButton(
                  onPressed: selected == null ? null : _continue,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFB7FF18),
                    disabledBackgroundColor: Colors.white12,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: Text(
                    selected == null
                        ? 'Select a vehicle'
                        : 'Continue as $selected',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),

            ],
          ),
        ),
      ),
    );
  }

  Widget _vehicleCard(String vehicle) {
    final isSelected = selected == vehicle;

    return InkWell(
      borderRadius: BorderRadius.circular(23),
      onTap: () => setState(() => selected = vehicle),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 124,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isSelected
                ? const [Color(0xFF0E5B35), Color(0xFF08251E)]
                : const [Color(0xFF0A1A21), Color(0xFF071219)],
          ),
          borderRadius: BorderRadius.circular(23),
          border: Border.all(
            color: isSelected
                ? const Color(0xFFB7FF18)
                : Colors.white12,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? const [
            BoxShadow(
              color: Color(0x6600FF55),
              blurRadius: 22,
            ),
          ]
              : const [],
        ),
        child: Row(
          children: [
            SizedBox(
              width: 145,
              height: 110,
              child: Image.memory(
                base64Decode(_imageFor(vehicle)),
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    vehicle,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _sub(vehicle),
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 9),
                  if (isSelected)
                    const Row(
                      children: [
                        Icon(
                          Icons.check_circle_rounded,
                          color: Color(0xFFB7FF18),
                          size: 20,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'Selected',
                          style: TextStyle(
                            color: Color(0xFFB7FF18),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              color: Colors.white70,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}

const String _driverLandingBg = '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';
const String _driverLoadingBg = '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';
const String _driverCarImg = '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';
const String _driverRickshawImg = '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';
const String _driverBikeImg = 'iVBORw0KGgoAAAANSUhEUgAAAggAAAEECAYAAABN1syFAAANj0lEQVR4nO3dO3bc1hIFUPAtD8EzEANFijUSDdIjUaxIATUDzYEO+LDcavQHnwugqu7ekZdNkwD6VuGggO4eBgAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABo6uXsDQDy+PH29j7n5768vuotkJwiBh6aGwruERYgJ4UL3LQ1GFwTFCAXBQv8oXUwuCYoQA7/O3sDgDj2DgdH/Q1gO0keOO2kbZoAcZkgQOfOvKI3TYC4BAToWIQTdIRtAKYEBOhUpBNzpG0BPggIAMCEgAAdinjFHnGboGcCAnQm8ok48rZBbwQEAGBCQICOZLhCz7CN0AMBAQCYEBCgE5muzDNtK1QlIAAAEwICADAhIEAHMo7sM24zVCIgAAATAgIAMCEgAAATAgIAMCEgAAATAgIAMCEgAAATAgJl/fP+t/fRA6wkIFDSGA6EBIB1BATKuQ4FQsIwfHl9fTl7G5bKuM1QiYBAKffCgJAAsIyAQBnPQoCQADCfgEAJc0/+PYeETCP7TNsKVQkIpLf0pN9zSACYS0AgtbUn+15DQoYr8wzbCD0QEEjt28vv1SeTXkMCwBwCAukJCfP9eHsLvb+mBxCHgEAJQsJzwgGwhIBAGULCfdHDARCPgEApQsLUWeHg56evs3/W9ADiUZSUtOVkvyVkRHNGOLgOBp9/fX/488IBxGSCQEkmCceHg5+fvi6aGgyDcACRKU5K63WScGQ4mBMKrqcIggHEZ4JAaT1OEtaGgy+vry9LTtxrJgbj31n8PwGHU6h0oYdJwpapwa2T9pzftyQgZDmOwAcTBLpQfZLQOhyM/97VPvRL8dOVipOEPcLBkr9ligA1KVa6UykkHBkO7llyPKMdP+A+txjoTpXbDRHCwTAsO56Rjh/wmIBAl7KHhCjhAKhLo6BrGW83bHkbY+ttueRWA9RigkDXsk0SooYDoB4Bge5lCQnRw4FnEaAWAQGG+CEhejgA6tE84EK0ZxIyPozoWQSowQQBLkSaJGQMB0u51QBxCQhwJUJIyBwOTAWgBgEBbjgzJGQOB2uYIkBMAgLccUZIqBIOTBEgPwEBHjgyJFQJByNve4TcBAR44oiQsOVtjBHDAZCfgAAz7BkSKn/GgSkC5CUgwEx7hITK4QDITUCABVqGhF7CgSkC5CQgwEJbQ8KPt7f3XsIBkJeAACtsCQk/P31d9f9lDgemCJCPgAArHRkSMocDICcBATY4IiRUCQemCJCLgAAbrQ0Jn399f/ozVcIBkI+AAA0sDQm9hgNTBMijXAOCM805qT0LBxWDwaWlJ37f6wDnMEGAAz0LBz8/fS1/5eyEDzkICNDI1hP75UOL1UPCEo4FnENAgAbmnsTuvXPh1r//5/3v96onR1MEiE9AgI2WnsSvw8CztzsKCXWPAUQmIMAGa09cYyiY+1kITpDA0Yz5YKUzTtoVR/NLjmPF/YeoTBBghbOu6Cs/lwDEIiDAQhFO0BG2oRXPIkBMAgIsEOkEFWlbgHoEBJipxQn528vvl5b30auEBFMEiEdAgBlahYNb/7yV5xKAPXgiGJ5oHQ72+P1z/k4G3tEAcZggwAN7h4M5/30JkwSgFQkc7jgiHLT+e2v/diSmCBCDCQLccHQ4WPPzz/QwTehhH+EsAgJcOSMcXP5/vd9yMBWAGAQEuHBmOGj9O0YZQ8IS1fcPziIgwP9FCQd7/K5sb4U0RYDzCQgwxAsHe/3OqiEh035BFgIC3YsaDi5/t1sOwNEEBLoWPRzs9XeyhARTBDiPgEC3MoWDPf5etucSgGN5EIguZQwH13r6iGYfngTHM0GgOxXCQettMEkArgkIdKVKOBj1EhI8iwDHExDoRrVwMPJcArCHcM0O9lA1HFyr/lyCZxHgOCYIlNdLOBiGfm45APtL0fRgrZ7CwaXKXx1tigDHMEGgrF7DwTD0/RHNl7JuN0QgIFBSz+FgVPUjmrO/LpCFgEA5wsGfKoaEJTJuM0QgIFCKcHBbtbdCVnyNIBoBgTKEg8eqPZfgw5NgXwICJQgH81R9LgFoT0AgPeFguSohwRQB9iMgkJpwsF615xKAtrpsjNQgHLST/SOafXgStGeCQErCQVtVbjkA7QgIpCMc7CNzSPAsArSnSTLLj7e31U31y+trqBOPcPBY1u9xyHCbIUodwRwWHBNbmthca5qdcHCsjM8lRAoJUesI5rK4GIbhmGZ2z5wmJxycI1tIODsgRK8jWMKC6tiZzeyeW01OODhXtlsOR4eELHUES1lEHYrY0K6NDU44iCFTSJizrVWDwTVBgS0sno5kaGiXfn76uvl3CAdtZbnlcG87ewkG1wQF1rBoOpCxoQkHcWUICdfb2GswuCYosITFUljWhiYcxJfhlsM/73+/Cwa3CQrMYZEUlbWpCQd5ZAgJW2WtozmEBJ6xQIrJ3NCEg5wy3HJYKnMdLSUocI+PWi4kc1MTDvLK/BHNt2SuozV621/m01CLyFzkwkENFW45ZK6jrUwSuGZBJHdkQ1vTQJ5tX4tw8PnX92EYNLgoMt5yyF5HLakjRhZCYns3jT0axeU2twwHI80thkwhIXsd7UEdMQwCQlp7NYijGkOLE8h1OBhpbjFkCAnZ62gYauwDMVkACbVuCEc3gj3DwUhziyHycwnZ6+iWivvEebz4ybRsAGcU/xHhYKS5xRFtmpC9jp6pvn8cw9scE8le9EeGg2Ho+4n0aCK9FTJ7Hc3RcrvUUb/+OnsDONZZDe3ocEA8315+v7SaJIy/56y3t0YNBpfGbXSCZy0ThCRaFHmP4UBzjKX1CX3p2spcR2u12F511KdUC71XW4vzzIbWIhx8e/n9kvkYcNvRzyVYQ44By5ggBJe5oFuFg2HYvh+ugOI58rmEzHXUkjpiCQGhsCrhYFSlSfOf1iFhj+9yqLbuqu0P+xEQAtuS1quFg9GW/XL1E9PezyVkraM9qSPmKLn4K8ja1PYMB5eyHh8ea/1cgnXymOPDIyYIxfQQDoZBc6oqyucl9LK+etlP1rE4Alqb6nsJB5cyHiuea/0swZK3yfa4NtQRt5ggsNlZ4YC6vr38fmm5Jlp8cyj0RkAIJluSPzscrN1vD1rlcHRI6PWKWB1xi4BQQK/hYNRrU+/FUSGh93XU+/4zJSAEkimNRwkHW2Q63r1rHRLccmhHHdUlICSX9VsZW4cDVz/17flcgvXzwXHgkoAQxJoUflYxb23Se00O1hwPVz/5tFo/4zsbnBT/pI4YCQissrZJn31bgRq2riNfHQ7PCQhJRbjqWdqkjwgHEY4Lx/CA634cF4ZBQAgh83hubpOOPDnIfPx7t+a5BNODfaijegQENnvWoCOHA2qYu8aEA5hPQEgo4vjvXoM+IxxEPD7s79nJ//q/WyePOT4ICCerNJa7DgOZJgeVXoceja+fCcG51FEtAgJNjaEgUzigls+/vk+CguAAywkIyWQY+0UIBxmOE/saQ8GtcGB9zOM49e2vszeAvrX+Wt8//Fr247tuC80sCaAmB7CeCQIAMCEgnMgDPbG42sxJHcXi9ahDQEjE/cBlfGMft6ijZRyvfgkIAMCEgAAATAgIAMCEgAAATAgIAMCEgAAATPgkRU6198cy/3gbFr0nO8LHRANEYIIAAEwICADAhIAAAEwICADAhIAAAEwICIn4lrRlHC9usS6Wcbz6JSCcyLekxeL1yMnrFovXow4BAQCYEBAAgAkBIRn3A+dxnHjE+pjHceqbgAAATAgIJ/NATwxeh9y8fjF4HWoREBIy9nvM8WEO6+QxxwcBAQCYEBACMJY7l+Nfg9fxXI5/PQJCUsZ/tzkuLGG93Oa4MAwCAgBwg4AQxJrxnJT/pzXHw1i0FnW0nTpiJCAkp7l9cBzYwvr54DhwSUAIRAo/luNdk9f1WI53XQJCAb2n/t73nzZ6X0e97z9TAkIwa9N4r8W9dr9d9dSmjpZRR9wiIAAAEwJCQK5+5nHVwyPqaB51xD0CQjG9NLde9pNz9LK+etlP1hEQgtqSzqsX/Zb9c9XTF3V0nzriGQEhMM1tSlNjKXU0pY6YQ0AorFpzq7Y/5FBt3VXbH/YjIAS3Na1XaQZb98NVT9/U0Qd1xBJe7CRaNKiMxd3rfrOPXtdTr/vNNiYISbQozmxXQZoaramjddRRn/46ewM41tgsIhd8tgZMf9QRPTBBSKRlM4raPFpuV+TmzXnU0TLqqF9e+IRaN6UIDaDiPhFbxTVXcZ84jxc/qb2uXI5sCBX2gdwqrMEK+0BMFkBie48392gQGbeZ2jKuyYzbTD4WQXJH3gNd0zSibx8MQ/x1Gn37qMlCKCLqw1JH0NBoRR3Bf7yLoYhei7vX/WYfva6nXvebxwSEQnor8t72l2P0tq5621/mszCKqjwq1dA4ijqiZyYIRVUt/qr7RUxV11vV/aIti6QDFa6CNDTOpo7ojcXSkYwNTkMjGnVELyyaDmVocBoa0akjqrN4OhaxwWloZKOOqMoiYhiGc5ucZkYV6ohKLCgmjmhymhnVqSOys7iYZUuz08TggzoCAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAgKj+BRxg5npB3+AKAAAAAElFTkSuQmCC';

class PassengerRideNeedScreen extends StatefulWidget {
  const PassengerRideNeedScreen({super.key});
  @override State<PassengerRideNeedScreen> createState() => _PassengerRideNeedScreenState();
}

class _PassengerRideNeedScreenState extends State<PassengerRideNeedScreen> {
  String selected = 'Private Ride';
  final options = const [
    ('Private Ride', Icons.directions_car_filled_rounded, 'Your own comfortable ride'),
    ('Shared Ride (1 seat)', Icons.people_alt_rounded, 'Share the trip and save more'),
    ('Parcel Delivery', Icons.inventory_2_rounded, 'Send a parcel safely'),
  ];
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF06110D),
    appBar: AppBar(backgroundColor: Colors.transparent, foregroundColor: Colors.white, elevation: 0, leading: IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.arrow_back_rounded)), title: const Text('What ride do you need?', style: TextStyle(fontWeight: FontWeight.w900))),
    body: SafeArea(child: Padding(padding: const EdgeInsets.fromLTRB(18, 12, 18, 22), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Choose the service that fits your trip.', style: TextStyle(color: Colors.white60, fontSize: 14)), const SizedBox(height: 24),
      ...options.map((o) => Padding(padding: const EdgeInsets.only(bottom: 14), child: _option(o.$1, o.$2, o.$3))), const Spacer(),
      SizedBox(width: double.infinity, height: 56, child: ElevatedButton.icon(onPressed: () => Navigator.pop(context, selected), icon: const Icon(Icons.arrow_forward_rounded), label: const Text('Next', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFB7FF18), foregroundColor: const Color(0xFF06110D), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)))))
    ]))),
  );
  Widget _option(String title, IconData icon, String subtitle) { final on = selected == title; return GestureDetector(onTap: () => setState(() => selected = title), child: AnimatedContainer(duration: const Duration(milliseconds: 180), padding: const EdgeInsets.all(16), decoration: BoxDecoration(gradient: on ? const LinearGradient(colors: [Color(0xFFB7FF18), Color(0xFF5EFF9A)]) : const LinearGradient(colors: [Color(0xFF10221C), Color(0xFF091712)]), borderRadius: BorderRadius.circular(21), border: Border.all(color: on ? const Color(0xFFB7FF18) : const Color(0x335EFF9A), width: on ? 2 : 1), boxShadow: on ? const [BoxShadow(color: Color(0x445EFF9A), blurRadius: 20)] : const []), child: Row(children: [Container(width: 52, height: 52, decoration: BoxDecoration(color: on ? const Color(0x3306100B) : const Color(0x1FB7FF18), borderRadius: BorderRadius.circular(16)), child: Icon(icon, color: on ? const Color(0xFF06110D) : const Color(0xFFB7FF18), size: 28)), const SizedBox(width: 14), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: TextStyle(color: on ? const Color(0xFF06110D) : Colors.white, fontSize: 17, fontWeight: FontWeight.w900)), const SizedBox(height: 4), Text(subtitle, style: TextStyle(color: on ? const Color(0x9906110D) : Colors.white60, fontSize: 12))])), Icon(on ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded, color: on ? const Color(0xFF06110D) : Colors.white38)]))); }
}

class PassengerFareScreen extends StatefulWidget {
  final String pickup, destination, rideType;
  const PassengerFareScreen({super.key, required this.pickup, required this.destination, required this.rideType});
  @override State<PassengerFareScreen> createState() => _PassengerFareScreenState();
}
class _PassengerFareScreenState extends State<PassengerFareScreen> {
  final controller = TextEditingController();
  @override void dispose() { controller.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF06110D),
    appBar: AppBar(backgroundColor: Colors.transparent, foregroundColor: Colors.white, elevation: 0, leading: IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.arrow_back_rounded)), title: const Text('Set Your Fare', style: TextStyle(fontWeight: FontWeight.w900))),
    body: SafeArea(child: Padding(padding: const EdgeInsets.fromLTRB(18, 12, 18, 22), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(width: double.infinity, padding: const EdgeInsets.all(17), decoration: BoxDecoration(color: const Color(0xFF10221C), borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0x335EFF9A))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(widget.pickup, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)), const Padding(padding: EdgeInsets.symmetric(vertical: 6), child: Icon(Icons.more_vert_rounded, color: Color(0xFFB7FF18), size: 18)), Text(widget.destination, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)), const SizedBox(height: 12), Text(widget.rideType, style: const TextStyle(color: Color(0xFFB7FF18), fontWeight: FontWeight.w800))])),
      const SizedBox(height: 24), const Text('Your offer', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)), const SizedBox(height: 7), const Text('Set the fare you are comfortable offering to drivers.', style: TextStyle(color: Colors.white60, fontSize: 13)), const SizedBox(height: 14),
      TextField(controller: controller, keyboardType: const TextInputType.numberWithOptions(decimal: true), style: const TextStyle(color: Colors.white, fontSize: 25, fontWeight: FontWeight.w900), decoration: InputDecoration(prefixText: 'Rs. ', prefixStyle: const TextStyle(color: Color(0xFFB7FF18), fontSize: 23, fontWeight: FontWeight.w900), hintText: '0', hintStyle: const TextStyle(color: Colors.white24, fontSize: 25), filled: true, fillColor: const Color(0xFF10221C), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: Color(0x335EFF9A))), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: Color(0xFFB7FF18), width: 1.5)))),
      const Spacer(), SizedBox(width: double.infinity, height: 58, child: ElevatedButton.icon(onPressed: () { final fare = double.tryParse(controller.text.trim()); if (fare == null || fare <= 0) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Valid fare enter karo.'))); return; } Navigator.pop(context, controller.text.trim()); }, icon: const Icon(Icons.search_rounded), label: const Text('Find Ride', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFB7FF18), foregroundColor: const Color(0xFF06110D), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)))))
    ]))),
  );
}

class HomeScreen extends StatefulWidget {
  final String initialRole;
  final String? initialVehicle;
  final bool demoDriverMode;

  const HomeScreen({
    super.key,
    this.initialRole = 'Passenger',
    this.initialVehicle,
    this.demoDriverMode = false,
  });

  @override
  State<HomeScreen> createState() =>
      _HomeScreenState();
}

class _HomeScreenState
    extends State<HomeScreen> {
  // Paste your Google Places/Routes web-service API key here on your own computer.
  // Do not share this key publicly. For production, call these APIs through a backend.
  static const String _googleMapsWebServiceApiKey = 'AIzaSyCIxzBVjq9KscXdWSiLVV9Zt0O4aJtKhns';

  Timer? _placesDebounce;
  bool _placesLoading = false;
  bool _pickupFieldActive = false;
  bool _destinationFieldActive = false;
  List<Map<String, String>> _placeSuggestions = [];
  LatLng? _selectedPickupLocation;
  LatLng? _selectedDestinationLocation;
  String? selectedVehicle;
  final FirebaseAuth auth =
      FirebaseAuth.instance;

  bool isMapInteracting = false;

  final FirebaseFirestore firestore =
      FirebaseFirestore.instance;

  // Realtime Database for live ride requests. Existing Firestore flows remain
  // in place for ride history and passenger status screens.
  final rtdb.FirebaseDatabase realtimeDatabase = rtdb.FirebaseDatabase.instanceFor(
    app: Firebase.app(),
    databaseURL: 'https://ride-app-61076-default-rtdb.firebaseio.com',
  );
  StreamSubscription<rtdb.DatabaseEvent>? _rideRequestsSubscription;

  GoogleMapController? mapController;

  static const LatLng defaultLocation =
  LatLng(31.5204, 74.3587);

  LatLng currentLocation =
      defaultLocation;

  final Set<Marker> markers = {};
  final Set<Polyline> polylines = {};

  final pickupController =
  TextEditingController();

  final destinationController =
  TextEditingController();

  final fareController =
  TextEditingController();

  bool locationLoading = false;
  bool driverOnline = false;
  bool rideNotificationShown = false;
  bool routeLoading = false;
  bool demoRideAccepted = false;
  bool demoRideCompleted = false;
  bool passengerSearchExpanded = false;

  String selectedRole = 'Passenger';
  String selectedRide = 'Car';

  String? activeRideId;

  User? get currentUser =>
      auth.currentUser;

  @override
  void initState() {
    super.initState();

    selectedRole = widget.initialRole;
    selectedVehicle = widget.initialVehicle;

    if (widget.demoDriverMode) {
      driverOnline = false;
    }

    _getCurrentLocation();
    _checkDriverStatus();
    _listenForRideRequests();
  }

  /* ============================================================
     LOCATION
  ============================================================ */

  Future<void> _getCurrentLocation() async {
    if (mounted) {
      setState(() {
        locationLoading = true;
      });
    }

    try {
      final serviceEnabled =
      await Geolocator
          .isLocationServiceEnabled();

      if (!serviceEnabled) {
        _showMessage(
          'Please turn on Location/GPS.',
        );
        return;
      }

      LocationPermission permission =
      await Geolocator.checkPermission();

      if (permission ==
          LocationPermission.denied) {
        permission =
        await Geolocator.requestPermission();
      }

      if (permission ==
          LocationPermission.denied ||
          permission ==
              LocationPermission.deniedForever) {
        _showMessage(
          'Location permission is required.',
        );
        return;
      }

      final position =
      await Geolocator
          .getCurrentPosition();

      currentLocation = LatLng(
        position.latitude,
        position.longitude,
      );

      if (mounted) {
        setState(() {
          // Use Google's default blue location dot instead of a custom red marker.
          // Removing this ID also cleans up any marker left by an older state.
          markers.removeWhere(
                (marker) => marker.markerId.value == 'my_location',
          );
        });
      }

      if (mapController != null) {
        await mapController!
            .animateCamera(
          CameraUpdate
              .newLatLngZoom(
            currentLocation,
            14,
          ),
        );
      }
    } catch (e) {
      debugPrint(
        'Location error: $e',
      );

      _showMessage(
        'Unable to get current location.',
      );
    } finally {
      if (mounted) {
        setState(() {
          locationLoading = false;
        });
      }
    }
  }

  Future<void> _acceptDemoRide() async {
    if (!widget.demoDriverMode) return;
    setState(() => demoRideAccepted = true);
    _showMessage('Demo ride accepted. Route is ready.');
  }

  void _completeDemoRide() {
    if (!widget.demoDriverMode) return;
    setState(() => demoRideCompleted = true);
    _showMessage('Demo ride completed successfully.');
  }

  /* ============================================================
     DRIVER STATUS
  ============================================================ */

  Future<void> _checkDriverStatus() async {
    final user = currentUser;
    if (user == null) return;

    try {
      final snapshot = await realtimeDatabase.ref('drivers/${user.uid}').get();
      if (snapshot.exists && snapshot.value is Map) {
        final data = Map<String, dynamic>.from(snapshot.value as Map);
        if (mounted) setState(() => driverOnline = data['isOnline'] == true);
        return;
      }

      // Backward-compatible fallback for drivers already saved in Firestore.
      final doc = await firestore.collection('drivers').doc(user.uid).get();
      if (doc.exists && mounted) {
        setState(() => driverOnline = doc.data()?['isOnline'] == true);
      }
    } catch (e) {
      debugPrint('Driver status check error: $e');
    }
  }

  Future<void> _toggleDriverOnline() async {
    final user = currentUser;
    if (user == null) {
      _showMessage('Please login first.');
      return;
    }

    try {
      final newStatus = !driverOnline;
      final driverData = <String, dynamic>{
        'uid': user.uid,
        'isOnline': newStatus,
        'updatedAt': rtdb.ServerValue.timestamp,
      };
      await realtimeDatabase.ref('drivers/${user.uid}').update(driverData);
      // Keep Firestore in sync for existing screens/features.
      await firestore.collection('drivers').doc(user.uid).set({
        'uid': user.uid,
        'isOnline': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;
      setState(() => driverOnline = newStatus);
      if (newStatus && selectedRole == 'Driver') {
        _listenForRideRequests();
      }
      _showMessage(newStatus
          ? 'Driver Online hai. Ride requests receive hongi.'
          : 'Driver Offline hai.');
    } catch (e) {
      debugPrint('Driver status update error: $e');
      _showMessage('Driver status update nahi ho saka. Firebase Rules check karein.');
    }
  }

  /* ============================================================
     SWITCH ROLE
  ============================================================ */

  void _selectRole() {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding:
            const EdgeInsets.all(20),
            child: Column(
              mainAxisSize:
              MainAxisSize.min,
              children: [
                const Text(
                  'Select Side',
                  style: TextStyle(
                    fontSize: 23,
                    fontWeight:
                    FontWeight.bold,
                  ),
                ),
                const SizedBox(
                  height: 20,
                ),
                ListTile(
                  leading:
                  const CircleAvatar(
                    child: Icon(
                      Icons.person,
                    ),
                  ),
                  title:
                  const Text(
                    'Passenger Side',
                    style: TextStyle(
                      fontWeight:
                      FontWeight.bold,
                    ),
                  ),
                  subtitle:
                  const Text(
                    'Ride request bhejein',
                  ),
                  trailing:
                  selectedRole ==
                      'Passenger'
                      ? const Icon(
                    Icons
                        .check_circle,
                    color:
                    Colors.green,
                  )
                      : null,
                  onTap: () {
                    setState(() {
                      selectedRole =
                      'Passenger';
                    });

                    Navigator.pop(
                      sheetContext,
                    );
                  },
                ),
                const SizedBox(
                  height: 8,
                ),
                ListTile(
                  leading:
                  const CircleAvatar(
                    child: Icon(
                      Icons
                          .directions_car,
                    ),
                  ),
                  title:
                  const Text(
                    'Driver Side',
                    style: TextStyle(
                      fontWeight:
                      FontWeight.bold,
                    ),
                  ),
                  subtitle:
                  const Text(
                    'Ride requests accept karein',
                  ),
                  trailing:
                  selectedRole ==
                      'Driver'
                      ? const Icon(
                    Icons
                        .check_circle,
                    color:
                    Colors.green,
                  )
                      : null,
                  onTap: () async {
                    Navigator.pop(sheetContext);
                    await _openDriverMode();
                  },
                ),
                const SizedBox(
                  height: 20,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /* ============================================================
     DRIVER ONBOARDING
  ============================================================ */

  Future<void> _openDriverMode() async {
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const DriverLandingScreen()),
    );
  }

  Future<void> _saveDriverVehicle(String vehicle) async {
    final user = currentUser;
    if (user == null) return;

    try {
      await firestore.collection('drivers').doc(user.uid).set(
        {
          'uid': user.uid,
          'name': user.displayName ?? 'Driver',
          'email': user.email ?? '',
          'vehicleType': vehicle,
          'isOnline': false,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      setState(() {
        selectedRole = 'Driver';
        selectedVehicle = vehicle;
        driverOnline = false;
      });

      _showMessage('$vehicle selected. Driver mode ready.');
    } catch (e) {
      debugPrint('Driver vehicle save error: $e');
      _showMessage('Vehicle save nahi ho saka.');
    }
  }

  Future<void> _showDriverVehicleSelection() async {
    if (!mounted) return;

    final vehicle = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Choose Your Vehicle',
                  style: TextStyle(
                    fontSize: 27,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  'Select the vehicle you will use for rides.',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 20),
                _vehicleChoice(
                  sheetContext,
                  title: 'Car',
                  subtitle: 'Comfortable rides',
                  icon: Icons.directions_car_rounded,
                ),
                _vehicleChoice(
                  sheetContext,
                  title: 'Rickshaw',
                  subtitle: 'Easy city rides',
                  icon: Icons.electric_rickshaw_rounded,
                ),
                _vehicleChoice(
                  sheetContext,
                  title: 'Bike',
                  subtitle: 'Fast & economical',
                  icon: Icons.two_wheeler_rounded,
                ),
              ],
            ),
          ),
        );
      },
    );

    if (vehicle != null) {
      await _saveDriverVehicle(vehicle);
    }
  }

  Widget _vehicleChoice(
      BuildContext sheetContext, {
        required String title,
        required String subtitle,
        required IconData icon,
      }) {
    final selected = selectedVehicle == title;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: selected
            ? const Color(0xFFE8F7EE)
            : const Color(0xFFF5F7F6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: selected
              ? const Color(0xFF0F9D58)
              : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: ListTile(
        minVerticalPadding: 12,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 4,
        ),
        leading: Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(
            icon,
            size: 30,
            color: const Color(0xFF0F9D58),
          ),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 3),
          child: Text(subtitle),
        ),
        trailing: Icon(
          selected
              ? Icons.check_circle_rounded
              : Icons.arrow_forward_ios_rounded,
          size: selected ? 25 : 17,
          color: selected
              ? const Color(0xFF0F9D58)
              : Colors.grey,
        ),
        onTap: () => Navigator.pop(sheetContext, title),
      ),
    );
  }

  /* ============================================================
     RIDE REQUEST LISTENER
  ============================================================ */

  void _listenForRideRequests() {
    _rideRequestsSubscription?.cancel();
    _rideRequestsSubscription = realtimeDatabase
        .ref('rideRequests')
        .onValue
        .listen((event) {
      if (!mounted || selectedRole != 'Driver' || !driverOnline) return;
      final value = event.snapshot.value;
      if (value is! Map) return;

      for (final entry in value.entries) {
        if (entry.value is! Map) continue;
        final rideData = Map<String, dynamic>.from(entry.value as Map);
        if (rideData['status'] != 'searching') continue;
        if (rideData['rejectedBy'] is Map &&
            (rideData['rejectedBy'] as Map).containsKey(currentUser?.uid)) continue;
        // Ride requests are shown in the driver's live list panel instead of
        // opening a blocking popup for every incoming request.
        return;
      }
    }, onError: (Object error) {
      debugPrint('Realtime ride listener error: $error');
    });
  }

  /* ============================================================
     DRIVER NOTIFICATION
  ============================================================ */

  void _showRideNotification(String rideId, Map<String, dynamic> data) {
    final pickup = data['pickup'] ?? 'Pickup';
    final destination = data['destination'] ?? 'Destination';
    final fare = data['fare'] ?? 0;
    final rideType = data['rideType'] ?? 'Ride';
    final passengerName = data['passengerName'] ?? 'Passenger';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Row(children: [
          Icon(Icons.notifications_active, color: Colors.green),
          SizedBox(width: 10),
          Expanded(child: Text('New Ride Request')),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Passenger: $passengerName'),
            const SizedBox(height: 6),
            Text('$pickup → $destination', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text('Ride type: $rideType'),
            Text('Passenger offer: Rs. $fare'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              rideNotificationShown = false;
              final uid = currentUser?.uid;
              if (uid != null) {
                await realtimeDatabase.ref('rideRequests/$rideId/rejectedBy/$uid').set(true);
              }
            },
            child: const Text('Reject'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              rideNotificationShown = false;
              _showOfferFareDialog(rideId, fare);
            },
            child: const Text('Offer Fare'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              rideNotificationShown = false;
              _acceptRide(rideId);
            },
            child: const Text('Accept'),
          ),
        ],
      ),
    );
  }

  Future<void> _showOfferFareDialog(String rideId, dynamic passengerFare) async {
    final controller = TextEditingController(text: passengerFare.toString());
    final offeredFare = await showDialog<double>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Offer Your Fare'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Your fare (PKR)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final value = double.tryParse(controller.text.trim());
              if (value != null && value > 0) Navigator.pop(dialogContext, value);
            },
            child: const Text('Send Offer'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (offeredFare == null || currentUser == null) return;

    try {
      final user = currentUser!;
      final offer = <String, dynamic>{
        'driverId': user.uid,
        'driverName': user.displayName ?? 'Driver',
        'fare': offeredFare,
        'status': 'pending',
        'createdAt': rtdb.ServerValue.timestamp,
      };
      await realtimeDatabase.ref('rideRequests/$rideId/offers/${user.uid}').set(offer);
      await firestore.collection('rides').doc(rideId).set({
        'driverOffers': {user.uid: {
          'driverId': user.uid,
          'driverName': user.displayName ?? 'Driver',
          'fare': offeredFare,
          'status': 'pending',
        }},
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      _showMessage('Fare offer passenger ko send kar di gayi.');
    } catch (e) {
      debugPrint('Offer fare error: $e');
      _showMessage('Fare offer send nahi ho saki. Firebase Rules check karein.');
    }
  }

  /* ============================================================
     CREATE RIDE
  ============================================================ */

  Future<void> _createRideRequest() async {
    final user = currentUser;
    if (user == null) {
      _showMessage('Please login first.');
      return;
    }

    final pickup = pickupController.text.trim();
    final destination = destinationController.text.trim();
    final fareText = fareController.text.trim();
    if (pickup.isEmpty || destination.isEmpty) {
      _showMessage('Enter pickup and destination.');
      return;
    }
    final fare = double.tryParse(fareText);
    if (fare == null || fare <= 0) {
      _showMessage('Enter a valid fare.');
      return;
    }

    try {
      // Keep the existing Firestore ride document so history and passenger
      // status screens continue to work, and mirror the same ride to RTDB.
      final rideRef = firestore.collection('rides').doc();
      final rideData = <String, dynamic>{
        'passengerId': user.uid,
        'passengerName': user.displayName ?? 'Passenger',
        'passengerEmail': user.email ?? '',
        'pickup': pickup,
        'destination': destination,
        'pickupLat': (_selectedPickupLocation ?? currentLocation).latitude,
        'pickupLng': (_selectedPickupLocation ?? currentLocation).longitude,
        'destinationLat': _selectedDestinationLocation?.latitude,
        'destinationLng': _selectedDestinationLocation?.longitude,
        'rideType': selectedRide,
        'fare': fare,
        'currency': 'PKR',
        'status': 'searching',
        'driverId': null,
        'driverName': null,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      await rideRef.set(rideData);
      // Publish only the fields drivers need to decide whether to accept.
      // Passenger email and other private fields stay in Firestore.
      await realtimeDatabase.ref('rideRequests/${rideRef.id}').set({
        'rideId': rideRef.id,
        'passengerId': user.uid,
        'passengerName': user.displayName ?? 'Passenger',
        'pickup': pickup,
        'destination': destination,
        'pickupLat': (_selectedPickupLocation ?? currentLocation).latitude,
        'pickupLng': (_selectedPickupLocation ?? currentLocation).longitude,
        'destinationLat': _selectedDestinationLocation?.latitude,
        'destinationLng': _selectedDestinationLocation?.longitude,
        'rideType': selectedRide,
        'fare': fare,
        'currency': 'PKR',
        'status': 'searching',
        'driverId': null,
        'driverName': null,
        'createdAt': rtdb.ServerValue.timestamp,
        'updatedAt': rtdb.ServerValue.timestamp,
        'rejectedBy': <String, bool>{},
        'offers': <String, dynamic>{},
      });

      if (!mounted) return;
      setState(() => activeRideId = rideRef.id);
      _showMessage('Ride request send ho gayi.');
      _showPassengerStatus(rideRef.id);
    } catch (e) {
      debugPrint('Create ride error: $e');
      _showMessage('Ride request send nahi ho saki. Firebase Rules check karein.');
    }
  }

  /* ============================================================
     ACCEPT RIDE
  ============================================================ */

  Future<void> _acceptRide(String rideId) async {
    final user = currentUser;
    if (user == null) {
      _showMessage('Driver login required.');
      return;
    }

    try {
      final rideRef = realtimeDatabase.ref('rideRequests/$rideId');
      final result = await rideRef.runTransaction((currentData) {
        if (currentData is! Map) return rtdb.Transaction.abort();
        final data = Map<String, dynamic>.from(currentData);
        if (data['status'] != 'searching') return rtdb.Transaction.abort();
        data['status'] = 'accepted';
        data['driverId'] = user.uid;
        data['driverName'] = user.displayName ?? 'Driver';
        data['driverPhone'] = user.phoneNumber ?? '';
        data['acceptedAt'] = rtdb.ServerValue.timestamp;
        data['updatedAt'] = rtdb.ServerValue.timestamp;
        return rtdb.Transaction.success(data);
      });

      if (!result.committed) {
        _showMessage('Yeh ride kisi aur driver ne accept kar li hai.');
        return;
      }

      await firestore.collection('rides').doc(rideId).update({
        'status': 'accepted',
        'driverId': user.uid,
        'driverName': user.displayName ?? 'Driver',
        'driverPhone': user.phoneNumber ?? '',
        'acceptedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      final data = result.snapshot.value;
      if (data is Map) {
        final rideData = Map<String, dynamic>.from(data);
        final pickupLat = (rideData['pickupLat'] as num?)?.toDouble();
        final pickupLng = (rideData['pickupLng'] as num?)?.toDouble();
        if (pickupLat != null && pickupLng != null) {
          _showRideOnMap(LatLng(pickupLat, pickupLng));
        }
      }
      _showMessage('Ride accepted successfully.');
    } catch (e) {
      debugPrint('Accept ride error: $e');
      _showMessage('Unable to accept ride. Firebase Rules check karein.');
    }
  }

  /* ============================================================
     SHOW RIDE ON MAP
  ============================================================ */

  void _showRideOnMap(
      LatLng pickup,
      ) {
    setState(() {
      markers
        ..removeWhere(
              (m) =>
          m.markerId.value ==
              'ride_pickup',
        )
        ..add(
          Marker(
            markerId:
            const MarkerId(
              'ride_pickup',
            ),
            position: pickup,
            infoWindow:
            const InfoWindow(
              title:
              'Passenger Pickup',
            ),
          ),
        );

      polylines.clear();

      polylines.add(
        Polyline(
          polylineId:
          const PolylineId(
            'ride_route',
          ),
          points: [
            currentLocation,
            pickup,
          ],
          width: 6,
        ),
      );
    });

    if (mapController != null) {
      mapController!.animateCamera(
        CameraUpdate
            .newLatLngBounds(
          LatLngBounds(
            southwest: LatLng(
              currentLocation
                  .latitude <
                  pickup.latitude
                  ? currentLocation
                  .latitude
                  : pickup.latitude,
              currentLocation
                  .longitude <
                  pickup.longitude
                  ? currentLocation
                  .longitude
                  : pickup.longitude,
            ),
            northeast: LatLng(
              currentLocation
                  .latitude >
                  pickup.latitude
                  ? currentLocation
                  .latitude
                  : pickup.latitude,
              currentLocation
                  .longitude >
                  pickup.longitude
                  ? currentLocation
                  .longitude
                  : pickup.longitude,
            ),
          ),
          70,
        ),
      );
    }
  }

  /* ============================================================
     PASSENGER STATUS
  ============================================================ */

  void _showPassengerStatus(
      String rideId,
      ) {
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return StreamBuilder<
            DocumentSnapshot>(
          stream: firestore
              .collection('rides')
              .doc(rideId)
              .snapshots(),
          builder: (
              context,
              snapshot,
              ) {
            if (!snapshot.hasData) {
              return const Padding(
                padding:
                EdgeInsets.all(30),
                child: Center(
                  child:
                  CircularProgressIndicator(),
                ),
              );
            }

            final data =
            snapshot.data!
                .data()
            as Map<String, dynamic>?;

            if (data == null) {
              return const Padding(
                padding:
                EdgeInsets.all(30),
                child: Text(
                  'Ride not found.',
                ),
              );
            }

            final status =
                data['status'] ??
                    'searching';

            final driverName =
                data['driverName'] ??
                    '';

            return SafeArea(
              child: Padding(
                padding:
                const EdgeInsets
                    .fromLTRB(
                  24,
                  10,
                  24,
                  30,
                ),
                child: Column(
                  mainAxisSize:
                  MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons
                          .local_taxi,
                      size: 55,
                    ),
                    const SizedBox(
                      height: 15,
                    ),
                    Text(
                      _statusTitle(
                        status,
                      ),
                      style:
                      const TextStyle(
                        fontSize: 24,
                        fontWeight:
                        FontWeight
                            .bold,
                      ),
                    ),
                    const SizedBox(
                      height: 8,
                    ),
                    Text(
                      _statusMessage(
                        status,
                      ),
                      textAlign:
                      TextAlign.center,
                    ),
                    if (driverName
                        .toString()
                        .isNotEmpty) ...[
                      const SizedBox(
                        height: 18,
                      ),
                      Card(
                        child:
                        ListTile(
                          leading:
                          const CircleAvatar(
                            child:
                            Icon(
                              Icons
                                  .person,
                            ),
                          ),
                          title:
                          Text(
                            driverName
                                .toString(),
                            style:
                            const TextStyle(
                              fontWeight:
                              FontWeight
                                  .bold,
                            ),
                          ),
                          subtitle:
                          const Text(
                            'Your Driver',
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(
                      height: 20,
                    ),
                    if (status ==
                        'searching')
                      SizedBox(
                        width:
                        double.infinity,
                        height: 52,
                        child:
                        OutlinedButton(
                          onPressed:
                              () {
                            _cancelRide(
                              rideId,
                            );

                            Navigator
                                .pop(
                              sheetContext,
                            );
                          },
                          child:
                          const Text(
                            'Cancel Ride',
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _statusTitle(
      String status,
      ) {
    switch (status) {
      case 'accepted':
        return 'Driver Accepted!';
      case 'driver_arriving':
        return 'Driver is arriving';
      case 'driver_started':
        return 'Ride Started';
      case 'completed':
        return 'Ride Completed';
      case 'cancelled':
        return 'Ride Cancelled';
      default:
        return 'Finding a driver...';
    }
  }

  String _statusMessage(
      String status,
      ) {
    switch (status) {
      case 'accepted':
        return 'Your driver has accepted the ride.';
      case 'driver_arriving':
        return 'Your driver is coming to pickup location.';
      case 'driver_started':
        return 'Your ride is now in progress.';
      case 'completed':
        return 'Thank you for riding with us.';
      case 'cancelled':
        return 'This ride request has been cancelled.';
      default:
        return 'We are looking for nearby drivers.';
    }
  }

  /* ============================================================
     CANCEL
  ============================================================ */

  Future<void> _cancelRide(
      String rideId,
      ) async {
    try {
      await firestore
          .collection('rides')
          .doc(rideId)
          .update({
        'status': 'cancelled',
        'cancelledBy':
        'passenger',
        'updatedAt':
        FieldValue
            .serverTimestamp(),
      });
    } catch (e) {
      debugPrint('$e');
    }
  }

  /* ============================================================
     RIDE TYPE
  ============================================================ */

  void _selectRideType() {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      backgroundColor:
      Colors.white,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding:
            const EdgeInsets.all(
              20,
            ),
            child: Column(
              mainAxisSize:
              MainAxisSize.min,
              crossAxisAlignment:
              CrossAxisAlignment
                  .start,
              children: [
                const Text(
                  'Choose Ride Type',
                  style: TextStyle(
                    fontSize: 23,
                    fontWeight:
                    FontWeight.bold,
                  ),
                ),
                const SizedBox(
                  height: 18,
                ),
                _rideType(
                  'Car',
                  Icons
                      .directions_car,
                ),
                _rideType(
                  'Rickshaw',
                  Icons
                      .electric_rickshaw,
                ),
                _rideType(
                  'Bike',
                  Icons
                      .two_wheeler,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _rideType(
      String title,
      IconData icon,
      ) {
    return Card(
      margin:
      const EdgeInsets.only(
        bottom: 10,
      ),
      elevation: 0,
      color:
      Colors.grey.shade100,
      child: ListTile(
        contentPadding:
        const EdgeInsets
            .symmetric(
          horizontal: 16,
          vertical: 5,
        ),
        leading:
        CircleAvatar(
          backgroundColor:
          const Color(
            0xFFE2F7EA,
          ),
          child: Icon(
            icon,
            color:
            const Color(
              0xFF0F9D58,
            ),
          ),
        ),
        title: Text(
          title,
          style:
          const TextStyle(
            fontWeight:
            FontWeight.bold,
          ),
        ),
        subtitle:
        const Text(
          'Comfortable & reliable',
        ),
        trailing:
        selectedRide ==
            title
            ? const Icon(
          Icons
              .check_circle,
          color:
          Colors.green,
        )
            : null,
        onTap: () {
          setState(() {
            selectedRide =
                title;
          });

          Navigator.pop(
            context,
          );
        },
      ),
    );
  }

  /* ============================================================
     FIND RIDE
  ============================================================ */

  void _findRide() {
    final pickup =
    pickupController.text.trim();

    final destination =
    destinationController
        .text
        .trim();

    final fare =
    fareController.text.trim();

    if (pickup.isEmpty ||
        destination.isEmpty) {
      _showMessage(
        'Pickup aur destination enter karo.',
      );
      return;
    }

    if (fare.isEmpty) {
      _showMessage(
        'Apna fare enter karo.',
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor:
      Colors.white,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding:
            const EdgeInsets.all(
              20,
            ),
            child: Column(
              mainAxisSize:
              MainAxisSize.min,
              crossAxisAlignment:
              CrossAxisAlignment
                  .start,
              children: [
                const Text(
                  'Choose Your Ride',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight:
                    FontWeight.bold,
                  ),
                ),
                const SizedBox(
                  height: 8,
                ),
                Text(
                  '$pickup → $destination',
                  style:
                  const TextStyle(
                    color:
                    Colors.black54,
                  ),
                ),
                const SizedBox(
                  height: 18,
                ),
                _rideOption(
                  'Car',
                  Icons
                      .directions_car,
                  fare,
                ),
                _rideOption(
                  'Rickshaw',
                  Icons
                      .electric_rickshaw,
                  fare,
                ),
                _rideOption(
                  'Bike',
                  Icons
                      .two_wheeler,
                  fare,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _rideOption(
      String title,
      IconData icon,
      String fare,
      ) {
    final isSelected =
        selectedRide == title;

    return Card(
      margin:
      const EdgeInsets.only(
        bottom: 10,
      ),
      elevation:
      isSelected ? 3 : 0,
      color: isSelected
          ? const Color(
        0xFFEAF9F0,
      )
          : Colors.grey.shade100,
      child: ListTile(
        contentPadding:
        const EdgeInsets
            .symmetric(
          horizontal: 16,
          vertical: 6,
        ),
        leading:
        CircleAvatar(
          radius: 27,
          backgroundColor:
          Colors.white,
          child: Icon(
            icon,
            size: 28,
            color:
            const Color(
              0xFF0F9D58,
            ),
          ),
        ),
        title: Text(
          title,
          style:
          const TextStyle(
            fontWeight:
            FontWeight.bold,
            fontSize: 17,
          ),
        ),
        subtitle:
        const Text(
          'Nearby drivers',
        ),
        trailing:
        Column(
          mainAxisAlignment:
          MainAxisAlignment
              .center,
          crossAxisAlignment:
          CrossAxisAlignment
              .end,
          children: [
            Text(
              'Rs. $fare',
              style:
              const TextStyle(
                fontWeight:
                FontWeight.bold,
                fontSize: 16,
              ),
            ),
            if (isSelected)
              const Text(
                'Selected',
                style:
                TextStyle(
                  color:
                  Colors.green,
                  fontSize: 12,
                  fontWeight:
                  FontWeight.bold,
                ),
              ),
          ],
        ),
        onTap: () {
          Navigator.pop(
            context,
          );

          setState(() {
            selectedRide =
                title;
          });

          _createRideRequest();
        },
      ),
    );
  }

  /* ============================================================
     MESSAGE
  ============================================================ */

  void _showMessage(
      String message,
      ) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        behavior:
        SnackBarBehavior.floating,
        content:
        Text(message),
      ),
    );
  }

  /* ============================================================
     BUILD
  ============================================================ */

  @override
  Widget build(
      BuildContext context,
      ) {
    final isDriver =
        selectedRole ==
            'Driver';

    return Scaffold(
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: const CameraPosition(
              target: defaultLocation,
              zoom: 13,
            ),
            // Keep Google's default blue dot visible in startup and route mode.
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            compassEnabled: false,
            markers: markers,
            polylines: polylines,

            onCameraMoveStarted: () {
              if (!isMapInteracting) {
                setState(() => isMapInteracting = true);
              }
            },

            onCameraIdle: () {
              if (isMapInteracting) {
                setState(() => isMapInteracting = false);
              }
            },

            onTap: (_) {
              setState(() => isMapInteracting = true);

              Future.delayed(const Duration(milliseconds: 250), () {
                if (!mounted) return;
                setState(() => isMapInteracting = false);
              });
            },

            onMapCreated: (controller) {
              mapController = controller;
            },
          ),

          SafeArea(
            child: Column(
              children: [
                // TOP SECTION: white bar with menu, online/offline switch, settings
                AnimatedSlide(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOutCubic,
                  offset: isMapInteracting ? const Offset(0, -1.5) : Offset.zero,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 250),
                    opacity: isMapInteracting ? 0.0 : 1.0,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 12, offset: const Offset(0, 3))]),
                        child: Row(children: [
                          Container(decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)), child: IconButton(onPressed: _showMenu, icon: const Icon(Icons.menu_rounded, color: Colors.black87))),
                          const Spacer(),
                          if (isDriver) GestureDetector(
                            onTap: _toggleDriverOnline,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 220), width: 112, height: 38, padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(color: driverOnline ? const Color(0xFF0F9D58) : const Color(0xFFE53935), borderRadius: BorderRadius.circular(24)),
                              child: Stack(children: [
                                Align(alignment: driverOnline ? Alignment.centerRight : Alignment.centerLeft, child: Container(width: 30, height: 30, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle))),
                                Center(child: Text(driverOnline ? 'Online' : 'Offline', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13))),
                              ]),
                            ),
                          ),
                          const Spacer(),
                          Container(decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)), child: IconButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())), icon: const Icon(Icons.settings_rounded, color: Colors.black87))),
                        ]),
                      ),
                    ),
                  ),
                ),

                const Spacer(),

                // DRIVER ONLINE SECTION
                AnimatedSlide(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOutCubic,
                  offset: isMapInteracting
                      ? const Offset(0, 1.5)
                      : Offset.zero,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 250),
                    opacity: isMapInteracting ? 0.0 : 1.0,
                    child: Column(
                      children: [
                        const SizedBox(
                          height: 10,
                        ),

                        Align(
                          alignment:
                          Alignment.centerRight,
                          child: Padding(
                            padding:
                            const EdgeInsets
                                .only(
                              right: 16,
                              bottom: 12,
                            ),
                            child:
                            FloatingActionButton
                                .small(
                              backgroundColor:
                              Colors.white,
                              onPressed:
                              _getCurrentLocation,
                              child:
                              locationLoading
                                  ? const SizedBox(
                                width:
                                20,
                                height:
                                20,
                                child:
                                CircularProgressIndicator(
                                  strokeWidth:
                                  2,
                                ),
                              )
                                  : const Icon(
                                Icons
                                    .my_location,
                              ),
                            ),
                          ),
                        ),

                        if (!isDriver)
                          _passengerRidePanel(),

                        if (isDriver)
                          _driverRidePanel(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _passengerRidePanel() {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        color: const Color(0xF5081412),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: const Color(0x335EFF9A)),
        boxShadow: const [
          BoxShadow(color: Colors.black54, blurRadius: 24, offset: Offset(0, -8)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Center(
            child: Text(
              'Type of Ride',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _passengerTypeButton('City to City', Icons.route_rounded)),
              const SizedBox(width: 8),
              Expanded(child: _passengerTypeButton('Ride', Icons.directions_car_filled_rounded)),
              const SizedBox(width: 8),
              Expanded(child: _passengerTypeButton('Freight', Icons.local_shipping_rounded)),
            ],
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: _openPassengerRoutePopup,
            child: Container(
              height: 58,
              padding: const EdgeInsets.symmetric(horizontal: 15),
              decoration: BoxDecoration(
                color: const Color(0xFF10221C),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0x445EFF9A)),
                boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 14, offset: Offset(0, 6))],
              ),
              child: Row(children: [
                Container(width: 38, height: 38, decoration: BoxDecoration(color: const Color(0x1FB7FF18), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.search_rounded, color: Color(0xFFB7FF18), size: 23)),
                const SizedBox(width: 12),
                const Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Where are you going?', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800)),
                  SizedBox(height: 2), Text('Choose pickup & destination', style: TextStyle(color: Colors.white54, fontSize: 11)),
                ])),
                const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white54, size: 16),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openPassengerRoutePopup() async {
    _placeSuggestions = [];
    _pickupFieldActive = false;
    _destinationFieldActive = false;
    await showModalBottomSheet<void>(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => SafeArea(child: Container(
          margin: const EdgeInsets.only(top: 70),
          padding: EdgeInsets.fromLTRB(18, 10, 18, MediaQuery.of(sheetContext).viewInsets.bottom + 20),
          decoration: const BoxDecoration(color: Color(0xFF07120F), borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
          child: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            IconButton(onPressed: () => Navigator.pop(sheetContext), icon: const Icon(Icons.arrow_back_rounded, color: Colors.white)),
            const Text('Plan your route', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900)),
            const SizedBox(height: 6), const Text('Choose your pickup and destination.', style: TextStyle(color: Colors.white60, fontSize: 13)),
            const SizedBox(height: 20),
            _routePopupField(pickupController, 'From', 'Pickup location', Icons.my_location_rounded, isPickup: true, setSheetState: setSheetState),
            if (_pickupFieldActive) _buildPlaceSuggestions(setSheetState),
            const SizedBox(height: 12),
            _routePopupField(destinationController, 'To', 'Destination', Icons.location_on_rounded, isPickup: false, setSheetState: setSheetState),
            if (_destinationFieldActive) _buildPlaceSuggestions(setSheetState),
            const SizedBox(height: 18),
            SizedBox(width: double.infinity, height: 56, child: ElevatedButton.icon(
              onPressed: routeLoading ? null : () async {
                if (pickupController.text.trim().isEmpty || destinationController.text.trim().isEmpty) {
                  _showMessage('From aur To dono enter karo.');
                  return;
                }
                if (_selectedPickupLocation == null || _selectedDestinationLocation == null) {
                  _showMessage('Dono fields ke liye Google suggestions mein se location select karo.');
                  return;
                }
                setSheetState(() => routeLoading = true);
                final success = await _fetchRouteAndDraw();
                if (!mounted) return;
                if (!success) {
                  setSheetState(() => routeLoading = false);
                  return;
                }
                if (sheetContext.mounted) Navigator.pop(sheetContext);
                _openPassengerRideNeedPage();
              },
              icon: routeLoading
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF06110D)))
                  : const Icon(Icons.arrow_forward_rounded),
              label: Text(routeLoading ? 'Finding route...' : 'Next', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFB7FF18), foregroundColor: const Color(0xFF06110D), elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))),
            )),
          ])),
        )),
      ),
    );
  }

  Widget _routePopupField(
      TextEditingController controller,
      String label,
      String hint,
      IconData icon, {
        required bool isPickup,
        required StateSetter setSheetState,
      }) {
    return TextField(
      controller: controller,
      textInputAction: TextInputAction.next,
      onTap: () {
        setSheetState(() {
          _pickupFieldActive = isPickup;
          _destinationFieldActive = !isPickup;
          _placeSuggestions = [];
        });
      },
      onChanged: (value) {
        if (isPickup) {
          _selectedPickupLocation = null;
        } else {
          _selectedDestinationLocation = null;
        }
        setSheetState(() {
          _pickupFieldActive = isPickup;
          _destinationFieldActive = !isPickup;
        });
        _schedulePlaceSearch(value, isPickup, setSheetState);
      },
      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: const TextStyle(color: Color(0xFFB7FF18), fontWeight: FontWeight.w700),
        hintStyle: const TextStyle(color: Colors.white38),
        prefixIcon: Icon(icon, color: const Color(0xFFB7FF18)),
        filled: true,
        fillColor: const Color(0xFF10221C),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: Color(0x335EFF9A))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: Color(0xFFB7FF18), width: 1.5)),
      ),
    );
  }

  void _schedulePlaceSearch(String input, bool isPickup, StateSetter setSheetState) {
    _placesDebounce?.cancel();
    if (input.trim().length < 3) {
      setSheetState(() {
        _placeSuggestions = [];
        _placesLoading = false;
      });
      return;
    }
    _placesDebounce = Timer(const Duration(milliseconds: 350), () {
      _fetchPlaceSuggestions(input.trim(), isPickup, setSheetState);
    });
  }

  Future<void> _fetchPlaceSuggestions(String input, bool isPickup, StateSetter setSheetState) async {
    if (_googleMapsWebServiceApiKey == 'PASTE_YOUR_API_KEY_HERE') {
      _showMessage('main.dart mein Google Places/Routes API key set karo.');
      return;
    }
    setSheetState(() => _placesLoading = true);
    try {
      final response = await http.post(
        Uri.parse('https://places.googleapis.com/v1/places:autocomplete'),
        headers: {
          'Content-Type': 'application/json',
          'X-Goog-Api-Key': _googleMapsWebServiceApiKey,
          'X-Goog-FieldMask': 'suggestions.placePrediction.placeId,suggestions.placePrediction.text.text',
        },
        body: jsonEncode({'input': input, 'includedRegionCodes': ['pk'], 'languageCode': 'en'}),
      );
      if (response.statusCode != 200) {
        debugPrint('Places API error ${response.statusCode}: ${response.body}');
        if (mounted) _showMessage('Places search fail hui. API key, billing aur API restrictions check karo.');
        setSheetState(() => _placesLoading = false);
        return;
      }
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final suggestions = (decoded['suggestions'] as List? ?? []).map<Map<String, String>?>((item) {
        final prediction = item['placePrediction'];
        if (prediction is! Map) return null;
        final id = prediction['placeId']?.toString();
        final description = (prediction['text'] as Map?)?['text']?.toString();
        if (id == null || description == null) return null;
        return {'placeId': id, 'description': description};
      }).whereType<Map<String, String>>().toList();
      setSheetState(() {
        _placeSuggestions = suggestions;
        _placesLoading = false;
        _pickupFieldActive = isPickup;
        _destinationFieldActive = !isPickup;
      });
    } catch (error) {
      debugPrint('Places search exception: $error');
      setSheetState(() => _placesLoading = false);
      if (mounted) _showMessage('Places search ke liye internet connection check karo.');
    }
  }

  Widget _buildPlaceSuggestions(StateSetter setSheetState) {
    if (_placesLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFB7FF18)))),
      );
    }
    if (_placeSuggestions.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(top: 6),
      decoration: BoxDecoration(color: const Color(0xFF10221C), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0x335EFF9A))),
      child: Column(
        children: _placeSuggestions.map((place) => ListTile(
          dense: true,
          leading: const Icon(Icons.location_on_outlined, color: Color(0xFFB7FF18)),
          title: Text(place['description'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 13)),
          onTap: () async {
            final isPickup = _pickupFieldActive;
            final controller = isPickup ? pickupController : destinationController;
            controller.text = place['description'] ?? '';
            FocusManager.instance.primaryFocus?.unfocus();
            setSheetState(() {
              _placeSuggestions = [];
              _pickupFieldActive = false;
              _destinationFieldActive = false;
              _placesLoading = true;
            });
            final location = await _fetchPlaceLocation(place['placeId'] ?? '');
            if (!mounted) return;
            setSheetState(() => _placesLoading = false);
            if (location == null) {
              _showMessage('Selected location ke coordinates nahi milay. Dobara select karo.');
              return;
            }
            setState(() {
              if (isPickup) {
                _selectedPickupLocation = location;
              } else {
                _selectedDestinationLocation = location;
              }
            });
          },
        )).toList(),
      ),
    );
  }

  Future<LatLng?> _fetchPlaceLocation(String placeId) async {
    if (placeId.isEmpty) return null;
    try {
      final uri = Uri.parse('https://places.googleapis.com/v1/places/$placeId').replace(queryParameters: {'fields': 'location'});
      final response = await http.get(uri, headers: {
        'X-Goog-Api-Key': _googleMapsWebServiceApiKey,
        'X-Goog-FieldMask': 'location',
      });
      if (response.statusCode != 200) {
        debugPrint('Place details error ${response.statusCode}: ${response.body}');
        return null;
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final location = data['location'] as Map<String, dynamic>?;
      final lat = (location?['latitude'] as num?)?.toDouble();
      final lng = (location?['longitude'] as num?)?.toDouble();
      if (lat == null || lng == null) return null;
      return LatLng(lat, lng);
    } catch (error) {
      debugPrint('Place details exception: $error');
      return null;
    }
  }

  Future<bool> _fetchRouteAndDraw() async {
    final origin = _selectedPickupLocation;
    final destination = _selectedDestinationLocation;
    if (origin == null || destination == null) return false;
    if (_googleMapsWebServiceApiKey == 'PASTE_YOUR_API_KEY_HERE') {
      _showMessage('main.dart mein Google Places/Routes API key set karo.');
      return false;
    }
    try {
      final response = await http.post(
        Uri.parse('https://routes.googleapis.com/directions/v2:computeRoutes'),
        headers: {
          'Content-Type': 'application/json',
          'X-Goog-Api-Key': _googleMapsWebServiceApiKey,
          'X-Goog-FieldMask': 'routes.distanceMeters,routes.duration,routes.polyline.encodedPolyline',
        },
        body: jsonEncode({
          'origin': {'location': {'latLng': {'latitude': origin.latitude, 'longitude': origin.longitude}}},
          'destination': {'location': {'latLng': {'latitude': destination.latitude, 'longitude': destination.longitude}}},
          'travelMode': 'DRIVE',
          'routingPreference': 'TRAFFIC_AWARE',
          'computeAlternativeRoutes': false,
          'languageCode': 'en',
          'units': 'METRIC',
        }),
      );
      if (response.statusCode != 200) {
        debugPrint('Routes API error ${response.statusCode}: ${response.body}');
        _showMessage('Route nahi mila. Routes API, billing aur API key restrictions check karo.');
        return false;
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final routes = data['routes'] as List? ?? [];
      if (routes.isEmpty) {
        _showMessage('In locations ke darmiyan driving route nahi mila.');
        return false;
      }
      final route = routes.first as Map<String, dynamic>;
      final encoded = ((route['polyline'] as Map?)?['encodedPolyline'])?.toString();
      if (encoded == null || encoded.isEmpty) {
        _showMessage('Google route response mein map line nahi mili.');
        return false;
      }
      final points = _decodeGooglePolyline(encoded);
      if (points.isEmpty) return false;
      setState(() {
        // Route mode must contain only the pickup and destination custom markers.
        // Google's default blue location dot is separate from this markers set.
        markers.clear();
        markers.add(Marker(markerId: const MarkerId('sawari_pickup'), position: origin, infoWindow: InfoWindow(title: 'Pickup', snippet: pickupController.text)));
        markers.add(Marker(markerId: const MarkerId('sawari_destination'), position: destination, infoWindow: InfoWindow(title: 'Destination', snippet: destinationController.text)));
        polylines.removeWhere((line) => line.polylineId.value == 'sawari_route');
        polylines.add(Polyline(polylineId: const PolylineId('sawari_route'), points: points, color: const Color(0xFFB7FF18), width: 6, geodesic: true));
      });
      if (points.length >= 2 && mapController != null) {
        var minLat = points.first.latitude, maxLat = points.first.latitude;
        var minLng = points.first.longitude, maxLng = points.first.longitude;
        for (final point in points.skip(1)) {
          if (point.latitude < minLat) minLat = point.latitude;
          if (point.latitude > maxLat) maxLat = point.latitude;
          if (point.longitude < minLng) minLng = point.longitude;
          if (point.longitude > maxLng) maxLng = point.longitude;
        }
        await mapController!.animateCamera(CameraUpdate.newLatLngBounds(
          LatLngBounds(southwest: LatLng(minLat, minLng), northeast: LatLng(maxLat, maxLng)), 70,
        ));
      }
      final distanceMeters = (route['distanceMeters'] as num?)?.toDouble();
      final duration = route['duration']?.toString() ?? '';
      final seconds = int.tryParse(duration.replaceAll('s', ''));
      final distanceText = distanceMeters == null ? '' : distanceMeters >= 1000 ? '${(distanceMeters / 1000).toStringAsFixed(1)} km' : '${distanceMeters.round()} m';
      final timeText = seconds == null ? '' : seconds >= 3600 ? '${seconds ~/ 3600} hr ${(seconds % 3600) ~/ 60} min' : '${(seconds / 60).ceil()} min';
      _showMessage('Route ready${distanceText.isNotEmpty ? ' • $distanceText' : ''}${timeText.isNotEmpty ? ' • $timeText' : ''}');
      return true;
    } catch (error) {
      debugPrint('Route request exception: $error');
      _showMessage('Route request fail hui. Internet aur API settings check karo.');
      return false;
    }
  }

  List<LatLng> _decodeGooglePolyline(String encoded) {
    final points = <LatLng>[];
    var index = 0;
    var latitude = 0;
    var longitude = 0;
    while (index < encoded.length) {
      var result = 0;
      var shift = 0;
      int value;
      do {
        value = encoded.codeUnitAt(index++) - 63;
        result |= (value & 0x1f) << shift;
        shift += 5;
      } while (value >= 0x20 && index < encoded.length);
      latitude += (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      result = 0;
      shift = 0;
      do {
        value = encoded.codeUnitAt(index++) - 63;
        result |= (value & 0x1f) << shift;
        shift += 5;
      } while (value >= 0x20 && index < encoded.length);
      longitude += (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      points.add(LatLng(latitude / 1e5, longitude / 1e5));
    }
    return points;
  }

  Future<void> _openPassengerRideNeedPage() async {
    final result = await Navigator.push<String>(context, MaterialPageRoute(builder: (_) => const PassengerRideNeedScreen()));
    if (result == null || !mounted) return;
    setState(() => selectedRide = result);
    await _openPassengerFarePage();
  }

  Future<void> _openPassengerFarePage() async {
    final fare = await Navigator.push<String>(context, MaterialPageRoute(builder: (_) => PassengerFareScreen(pickup: pickupController.text.trim(), destination: destinationController.text.trim(), rideType: selectedRide)));
    if (fare == null || !mounted) return;
    fareController.text = fare;
    await _createRideRequest();
  }

  Widget _passengerTypeButton(String title, IconData icon) {
    final selected = selectedRide == title;
    return GestureDetector(
      onTap: () => setState(() => selectedRide = title),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 76,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          gradient: selected
              ? const LinearGradient(colors: [Color(0xFFB7FF18), Color(0xFF5EFF9A)])
              : const LinearGradient(colors: [Color(0xFF13261F), Color(0xFF0C1714)]),
          borderRadius: BorderRadius.circular(17),
          border: Border.all(color: selected ? const Color(0xFFB7FF18) : const Color(0x335EFF9A), width: selected ? 2 : 1),
          boxShadow: selected ? const [BoxShadow(color: Color(0x555EFF9A), blurRadius: 16)] : const [],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: selected ? const Color(0xFF07100C) : const Color(0xFFB7FF18), size: 25),
            const SizedBox(height: 6),
            Text(title, textAlign: TextAlign.center, style: TextStyle(color: selected ? const Color(0xFF07100C) : Colors.white, fontSize: 11, fontWeight: FontWeight.w900)),
          ],
        ),
      ),
    );
  }

  Widget _passengerLocationField(TextEditingController controller, String hint, IconData icon) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white54),
        prefixIcon: Icon(icon, color: const Color(0xFFB7FF18)),
        filled: true,
        fillColor: const Color(0xFF10221C),
        contentPadding: const EdgeInsets.symmetric(vertical: 16),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0x335EFF9A))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFB7FF18), width: 1.5)),
      ),
    );
  }

  Widget _modernRideButton({
    required String title,
    required IconData icon,
  }) {
    final selected =
        selectedRide == title;

    return GestureDetector(
      onTap: () {
        setState(() {
          selectedRide =
              title;
        });
      },
      child: AnimatedContainer(
        duration:
        const Duration(
          milliseconds: 200,
        ),
        padding:
        const EdgeInsets
            .symmetric(
          vertical: 11,
        ),
        decoration:
        BoxDecoration(
          color: selected
              ? const Color(
            0xFFE2F7EA,
          )
              : Colors.grey.shade100,
          borderRadius:
          BorderRadius.circular(
            14,
          ),
          border: Border.all(
            color: selected
                ? const Color(
              0xFF0F9D58,
            )
                : Colors
                .transparent,
            width: 1.5,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 25,
              color: selected
                  ? const Color(
                0xFF0F9D58,
              )
                  : Colors.black54,
            ),
            const SizedBox(
              height: 5,
            ),
            Text(
              title,
              style:
              TextStyle(
                fontSize: 12,
                fontWeight:
                FontWeight.bold,
                color: selected
                    ? const Color(
                  0xFF0F9D58,
                )
                    : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /* ============================================================
     DRIVER PANEL
  ============================================================ */

  Widget _driverRidePanel() {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(
        minHeight: 260,
        maxHeight: 350,
      ),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(30),
        ),
        boxShadow: [
          BoxShadow(
            blurRadius: 22,
            color: Colors.black26,
          ),
        ],
      ),
      child: widget.demoDriverMode
          ? _demoDriverPanelContent()
          : StreamBuilder<QuerySnapshot>(
        stream: firestore
            .collection('rides')
            .where('status', isEqualTo: 'searching')
            .snapshots(),
        builder: (context, snapshot) {
          return _realDriverPanelContent(snapshot);
        },
      ),
    );
  }

  Widget _realDriverPanelContent(AsyncSnapshot<QuerySnapshot> snapshot) {
    final rideDocs = (snapshot.data?.docs ?? []).where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return data['status'] == 'searching' &&
          (data['passengerId'] ?? '').toString().isNotEmpty;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: const Color(0xFFE8F7EE),
                borderRadius: BorderRadius.circular(13),
              ),
              child: const Icon(
                Icons.directions_car_rounded,
                color: Color(0xFF0F9D58),
                size: 24,
              ),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'New Ride Requests',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
              ),
            ),
            if (driverOnline)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F7EE),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Text(
                  '${rideDocs.length} available',
                  style: const TextStyle(
                    color: Color(0xFF0F9D58),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        if (!driverOnline)
          const Expanded(
            child: Center(
              child: Text(
                'Go Online to receive passenger requests.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
            ),
          )
        else if (snapshot.connectionState == ConnectionState.waiting)
          const Expanded(child: Center(child: CircularProgressIndicator()))
        else if (snapshot.hasError)
            const Expanded(child: Center(child: Text('Error loading ride requests.')))
          else if (rideDocs.isEmpty)
              const Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.search_rounded, size: 34, color: Colors.black45),
                      SizedBox(height: 5),
                      Text(
                        'No ride requests yet',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.only(bottom: 8),
                  itemCount: rideDocs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) => _driverRequestCard(rideDocs[index]),
                ),
              ),
      ],
    );
  }

  Widget _demoDriverPanelContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFFE8F7EE),
                borderRadius: BorderRadius.circular(15),
              ),
              child: const Icon(Icons.directions_car_rounded, color: Color(0xFF0F9D58), size: 27),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Driver Demo Mode', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
                  Text(selectedVehicle ?? 'Car', style: TextStyle(color: Colors.grey.shade600)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: const Color(0xFFE8F7EE), borderRadius: BorderRadius.circular(20)),
              child: const Text('DEMO', style: TextStyle(color: Color(0xFF0F9D58), fontSize: 11, fontWeight: FontWeight.w900)),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: driverOnline ? const Color(0xFFE8F7EE) : const Color(0xFFF5F5F5),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Row(
            children: [
              Icon(Icons.circle, size: 11, color: driverOnline ? const Color(0xFF0F9D58) : Colors.grey),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  driverOnline ? 'You are Online • Demo requests active' : 'You are Offline • Go online for demo request',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              Switch(value: driverOnline, onChanged: (_) => _toggleDriverOnline()),
            ],
          ),
        ),
        const SizedBox(height: 14),
        if (!driverOnline)
          const Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.power_settings_new_rounded, size: 42, color: Color(0xFF0F9D58)),
                  SizedBox(height: 7),
                  Text('Go Online to test a demo ride request', textAlign: TextAlign.center, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          )
        else if (demoRideCompleted)
          const Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.verified_rounded, size: 48, color: Color(0xFF0F9D58)),
                  SizedBox(height: 8),
                  Text('Demo ride completed', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
                  SizedBox(height: 4),
                  Text('You can test another ride anytime.', style: TextStyle(color: Colors.black54)),
                ],
              ),
            ),
          )
        else if (demoRideAccepted)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('On Trip • Demo Route', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 8),
                  const Text('Pickup: Liberty Market', style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  const Text('Drop-off: Gulberg Main Boulevard', style: TextStyle(color: Colors.black54)),
                  const SizedBox(height: 8),
                  const Text('12.4 km • Rs. 450', style: TextStyle(color: Color(0xFF0F9D58), fontWeight: FontWeight.w900)),
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: _completeDemoRide,
                      icon: const Icon(Icons.flag_rounded),
                      label: const Text('Complete Demo Ride', style: TextStyle(fontWeight: FontWeight.w900)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F9D58),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('New Ride Request', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 7),
                  const Text('Liberty Market → Gulberg Main Boulevard', style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 5),
                  const Text('12.4 km • Offer: Rs. 450', style: TextStyle(color: Colors.black54)),
                  const Spacer(),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _showMessage('Demo request declined.'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.redAccent,
                            side: const BorderSide(color: Colors.redAccent),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                          ),
                          child: const Text('Decline', style: TextStyle(fontWeight: FontWeight.w900)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _acceptDemoRide,
                          icon: const Icon(Icons.check_rounded),
                          label: const Text('Accept', style: TextStyle(fontWeight: FontWeight.w900)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0F9D58),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
      ],
    );
  }

  Future<void> _sendRideFareOffer(String rideId, double offeredFare) async {
    final user = currentUser;
    if (user == null) {
      _showMessage('Driver login required.');
      return;
    }
    try {
      final offer = <String, dynamic>{
        'driverId': user.uid,
        'driverName': user.displayName ?? 'Driver',
        'fare': offeredFare,
        'status': 'pending',
        'createdAt': rtdb.ServerValue.timestamp,
      };
      await realtimeDatabase.ref('rideRequests/$rideId/offers/${user.uid}').set(offer);
      await firestore.collection('rides').doc(rideId).set({
        'driverOffers': {user.uid: {
          'driverId': user.uid,
          'driverName': user.displayName ?? 'Driver',
          'fare': offeredFare,
          'status': 'pending',
        }},
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      if (mounted) _showMessage('Fare offer passenger ko send kar di gayi.');
    } catch (e) {
      debugPrint('Offer fare error: $e');
      if (mounted) _showMessage('Fare offer send nahi ho saki. Firebase Rules check karein.');
    }
  }

  Future<void> _showRideRequestSheet(QueryDocumentSnapshot ride) async {
    final data = ride.data() as Map<String, dynamic>;
    final pickup = (data['pickup'] ?? 'Pickup location').toString();
    final destination = (data['destination'] ?? 'Destination').toString();
    final passengerName = (data['passengerName'] ?? 'Passenger').toString();
    final fareValue = data['fare'] ?? data['offer'] ?? 0;
    final fare = (fareValue is num ? fareValue.toDouble() : double.tryParse('$fareValue')) ?? 0.0;
    final pickupLat = (data['pickupLat'] as num?)?.toDouble();
    final pickupLng = (data['pickupLng'] as num?)?.toDouble();
    final destinationLat = (data['destinationLat'] as num?)?.toDouble();
    final destinationLng = (data['destinationLng'] as num?)?.toDouble();
    final pickupPoint = pickupLat != null && pickupLng != null ? LatLng(pickupLat, pickupLng) : null;
    final destinationPoint = destinationLat != null && destinationLng != null ? LatLng(destinationLat, destinationLng) : null;
    final rating = (data['passengerRating'] ?? data['rating'] ?? '').toString();
    final tripCount = (data['passengerTrips'] ?? data['completedTrips'] ?? '').toString();
    final rideType = (data['rideType'] ?? 'Ride').toString();
    final distanceMeters = pickupPoint == null ? null : Geolocator.distanceBetween(
      currentLocation.latitude, currentLocation.longitude,
      pickupPoint.latitude, pickupPoint.longitude,
    );
    final distanceLabel = distanceMeters == null ? '' : distanceMeters >= 1000
        ? '~ ${(distanceMeters / 1000).toStringAsFixed(1)} km'
        : '~ ${distanceMeters.round()} m';
    final suggestions = <double>{
      (fare * 1.10).roundToDouble(),
      (fare * 1.20).roundToDouble(),
      (fare * 1.30).roundToDouble(),
    }.toList()..sort();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Container(
          height: MediaQuery.of(sheetContext).size.height * 0.88,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 8),
                child: Row(children: [
                  const Expanded(child: Text('Ride request', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800))),
                  Container(width: 42, height: 4, decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(5))),
                ]),
              ),
              SizedBox(
                height: 230,
                child: GoogleMap(
                  initialCameraPosition: CameraPosition(target: pickupPoint ?? currentLocation, zoom: 12.5),
                  myLocationEnabled: false,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                  compassEnabled: false,
                  markers: {
                    Marker(markerId: const MarkerId('sheet_driver'), position: currentLocation,
                        infoWindow: const InfoWindow(title: 'Driver location'),
                        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure)),
                    if (pickupPoint != null) Marker(markerId: const MarkerId('sheet_pickup'), position: pickupPoint,
                        infoWindow: InfoWindow(title: 'A • Pickup', snippet: pickup),
                        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure)),
                    if (destinationPoint != null) Marker(markerId: const MarkerId('sheet_destination'), position: destinationPoint,
                        infoWindow: InfoWindow(title: 'B • Destination', snippet: destination),
                        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen)),
                  },
                  polylines: {
                    if (pickupPoint != null && destinationPoint != null)
                      Polyline(polylineId: const PolylineId('sheet_route'), points: [pickupPoint, destinationPoint], color: const Color(0xFF0F9D58), width: 5),
                    if (pickupPoint != null)
                      Polyline(polylineId: const PolylineId('sheet_driver_to_pickup'), points: [currentLocation, pickupPoint], color: const Color(0xFF1769E0), width: 3),
                  },
                  onMapCreated: (controller) {
                    final points = <LatLng>[currentLocation, if (pickupPoint != null) pickupPoint, if (destinationPoint != null) destinationPoint];
                    if (points.length > 1) {
                      var minLat = points.first.latitude, maxLat = points.first.latitude;
                      var minLng = points.first.longitude, maxLng = points.first.longitude;
                      for (final point in points.skip(1)) {
                        if (point.latitude < minLat) minLat = point.latitude;
                        if (point.latitude > maxLat) maxLat = point.latitude;
                        if (point.longitude < minLng) minLng = point.longitude;
                        if (point.longitude > maxLng) maxLng = point.longitude;
                      }
                      if (minLat != maxLat || minLng != maxLng) {
                        controller.animateCamera(CameraUpdate.newLatLngBounds(
                            LatLngBounds(southwest: LatLng(minLat, minLng), northeast: LatLng(maxLat, maxLng)), 35));
                      }
                    }
                  },
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    if (distanceLabel.isNotEmpty)
                      Text(distanceLabel, style: const TextStyle(fontSize: 13, color: Color(0xFF687780), fontWeight: FontWeight.w500)),
                    Text('PKR ${fare.toStringAsFixed(fare == fare.roundToDouble() ? 0 : 2)}', style: const TextStyle(fontSize: 27, fontWeight: FontWeight.w800, color: Color(0xFF111820))),
                    const SizedBox(height: 3),
                    Row(children: [
                      const Icon(Icons.person_rounded, size: 19, color: Color(0xFF687780)),
                      const SizedBox(width: 7),
                      Expanded(child: Text(passengerName, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700))),
                      Text(rideType, style: const TextStyle(fontSize: 12, color: Colors.black54)),
                    ]),
                    if (rating.isNotEmpty || tripCount.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Row(children: [
                        if (rating.isNotEmpty) const Icon(Icons.star_rounded, color: Color(0xFFFFB52E), size: 15),
                        if (rating.isNotEmpty) Text(rating, style: const TextStyle(fontSize: 12, color: Colors.black54)),
                        if (tripCount.isNotEmpty) Text('  ($tripCount trips)', style: const TextStyle(fontSize: 12, color: Colors.black54)),
                      ]),
                    ],
                    const SizedBox(height: 10),
                    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const CircleAvatar(radius: 10, backgroundColor: Color(0xFF1769E0), child: Text('A', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold))),
                      const SizedBox(width: 8), Expanded(child: Text(pickup, style: const TextStyle(fontSize: 14, height: 1.25))),
                    ]),
                    const SizedBox(height: 8),
                    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const CircleAvatar(radius: 10, backgroundColor: Color(0xFF0F9D58), child: Text('B', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold))),
                      const SizedBox(width: 8), Expanded(child: Text(destination, style: const TextStyle(fontSize: 14, height: 1.25))),
                    ]),
                    const SizedBox(height: 10),
                    SizedBox(width: double.infinity, height: 48, child: ElevatedButton(
                      onPressed: () async {
                        Navigator.of(sheetContext).pop();
                        await _acceptRide(ride.id);
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF66D51D), foregroundColor: const Color(0xFF14300A), elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      child: Text('Accept for PKR ${fare.toStringAsFixed(fare == fare.roundToDouble() ? 0 : 2)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                    )),
                    const SizedBox(height: 12),
                    const Center(child: Text('Offer your fare', style: TextStyle(fontSize: 14, color: Color(0xFF687780), fontWeight: FontWeight.w600))),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 52,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: suggestions.length + 1,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          if (index == suggestions.length) {
                            return Material(color: const Color(0xFFF2F5F6), borderRadius: BorderRadius.circular(12), child: IconButton(
                              tooltip: 'Enter your own fare', icon: const Icon(Icons.edit_rounded),
                              onPressed: () { Navigator.of(sheetContext).pop(); _showOfferFareDialog(ride.id, fareValue); },
                            ));
                          }
                          final suggestion = suggestions[index];
                          return OutlinedButton(
                            onPressed: () async {
                              Navigator.of(sheetContext).pop();
                              await _sendRideFareOffer(ride.id, suggestion);
                            },
                            style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF27343B), side: const BorderSide(color: Color(0xFFE0E5E8)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                            child: Text('PKR ${suggestion.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w700)),
                          );
                        },
                      ),
                    ),
                  ]),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: SizedBox(width: double.infinity, height: 42, child: TextButton(
                  onPressed: () => Navigator.of(sheetContext).pop(),
                  child: const Text('Close', style: TextStyle(fontSize: 15, color: Color(0xFF687780))),
                )),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _driverRequestCard(QueryDocumentSnapshot ride) {
    final data = ride.data() as Map<String, dynamic>;
    final pickup = (data['pickup'] ?? 'Pickup location').toString();
    final destination = (data['destination'] ?? 'Destination').toString();
    final passengerName = (data['passengerName'] ?? 'Passenger').toString();
    final fare = data['fare'] ?? data['offer'] ?? 0;
    // Estimate driver-to-pickup distance for each incoming ride.
    // Prefer the live driver's current location and the ride's pickup coordinates.
    final pickupLat = (data['pickupLat'] as num?)?.toDouble();
    final pickupLng = (data['pickupLng'] as num?)?.toDouble();
    String distance = '';
    if (pickupLat != null && pickupLng != null) {
      final meters = Geolocator.distanceBetween(
        currentLocation.latitude,
        currentLocation.longitude,
        pickupLat,
        pickupLng,
      );
      distance = meters >= 1000
          ? '${(meters / 1000).toStringAsFixed(1)} km'
          : '${meters.round()} m';
    } else {
      final rawDistance = data['distanceText'] ?? data['distance'];
      if (rawDistance is num) {
        distance = rawDistance >= 1000
            ? '${(rawDistance / 1000).toStringAsFixed(1)} km'
            : '${rawDistance.round()} m';
      } else {
        distance = (rawDistance ?? '').toString().trim();
      }
      distance = distance.replaceFirst(RegExp(r'^~\\s*'), '').trim();
    }
    final rating = (data['passengerRating'] ?? data['rating'] ?? '').toString();
    final tripCount = (data['passengerTrips'] ?? data['completedTrips'] ?? '').toString();
    final timeAgo = (data['timeAgo'] ?? '').toString();

    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: () => _showRideRequestSheet(ride),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(10, 12, 7, 12),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: Color(0xFFE5E8EB), width: 1)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 54,
                padding: const EdgeInsets.only(top: 2),
                child: Column(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8EDF1),
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFFD8E0E5)),
                      ),
                      child: const Icon(Icons.person_rounded, color: Color(0xFF788791), size: 31),
                    ),
                    const SizedBox(height: 5),
                    if (rating.isNotEmpty)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.star_rounded, color: Color(0xFFFFB52E), size: 13),
                          Flexible(
                            child: Text(rating, maxLines: 1, overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700)),
                          ),
                        ],
                      ),
                    if (tripCount.isNotEmpty)
                      Text('($tripCount)', maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 10, color: Colors.black54)),
                    if (timeAgo.isNotEmpty)
                      Text(timeAgo, maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 10, color: Colors.black54)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (distance.isNotEmpty)
                      Text('~ $distance', maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13, color: Color(0xFF687780), fontWeight: FontWeight.w500)),
                    Text(
                      'PKR $fare',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 23, height: 1.25, color: Color(0xFF111820), fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 3),
                    Text(passengerName,
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13, color: Color(0xFF687780), fontWeight: FontWeight.w600)),
                    const SizedBox(height: 5),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.trip_origin, size: 12, color: Color(0xFF657780)),
                        const SizedBox(width: 5),
                        Expanded(child: Text(pickup, maxLines: 2, overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13, height: 1.25, color: Color(0xFF27343B)))),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.location_on_outlined, size: 14, color: Color(0xFF657780)),
                        const SizedBox(width: 4),
                        Expanded(child: Text(destination, maxLines: 2, overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13, height: 1.25, color: Color(0xFF27343B)))),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => _showMessage('Ride details'),
                icon: const Icon(Icons.more_vert_rounded, color: Color(0xFF687780), size: 22),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 25, minHeight: 30),
                tooltip: 'More options',
              ),
            ],
          ),
        ),
      ),
    );
  }

  /* ============================================================
     MENU
  ============================================================ */

  void _showMenu() {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Menu',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        final user = currentUser;
        final isPassenger = selectedRole == 'Passenger';

        return Align(
          alignment: Alignment.centerLeft,
          child: Material(
            color: const Color(0xFF071219),
            child: SafeArea(
              child: SizedBox(
                width: MediaQuery.of(context).size.width * 0.82,
                height: MediaQuery.of(context).size.height,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 18),
                  child: Column(
                    children: [
                      ListTile(
                        leading: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: const Color(0xFFB7FF18),
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: const Icon(Icons.person_rounded, color: Colors.black),
                        ),
                        title: Text(
                          user?.displayName ?? 'Ride User',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
                        ),
                        subtitle: Text(
                          user?.email ?? user?.phoneNumber ?? '',
                          style: const TextStyle(color: Colors.white54),
                        ),
                      ),
                      const Divider(color: Colors.white12),
                      Expanded(
                        child: SingleChildScrollView(
                          child: Column(
                            children: [
                              _menuTile(
                                dialogContext,
                                Icons.history_rounded,
                                'Ride History',
                                'View your previous rides',
                                    () {
                                  Navigator.pop(dialogContext);
                                  Navigator.push(context, MaterialPageRoute(builder: (_) => const RideHistoryScreen()));
                                },
                              ),
                              if (isPassenger)
                                _menuTile(
                                  dialogContext,
                                  Icons.star_rounded,
                                  'Rate Your Ride',
                                  'Share your experience',
                                      () {
                                    Navigator.pop(dialogContext);
                                    Navigator.push(context, MaterialPageRoute(builder: (_) => const RatingScreen()));
                                  },
                                ),
                              _menuTile(
                                dialogContext,
                                Icons.settings_rounded,
                                'Settings',
                                'Account and app preferences',
                                    () {
                                  Navigator.pop(dialogContext);
                                  Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
                                },
                              ),
                              _menuTile(
                                dialogContext,
                                Icons.logout_rounded,
                                'Logout',
                                'Sign out of this account',
                                    () async {
                                  Navigator.pop(dialogContext);
                                  await auth.signOut();
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(dialogContext);
                            if (isPassenger) {
                              _openDriverMode();
                            } else {
                              setState(() {
                                selectedRole = 'Passenger';
                                selectedVehicle = null;
                                driverOnline = false;
                              });
                            }
                          },
                          icon: Icon(isPassenger ? Icons.directions_car_rounded : Icons.person_rounded),
                          label: Text(isPassenger ? 'Switch to Driver Mode' : 'Switch to Passenger Mode'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFB7FF18),
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            textStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final slideAnimation = Tween<Offset>(
          begin: const Offset(-1, 0),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));
        return SlideTransition(position: slideAnimation, child: child);
      },
    );
  }

  Widget _menuTile(BuildContext sheetContext, IconData icon, String title, String subtitle, VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(color: const Color(0xFF0B1A20), borderRadius: BorderRadius.circular(17), border: Border.all(color: Colors.white10)),
      child: ListTile(
        onTap: onTap,
        leading: Container(width: 45, height: 45, decoration: BoxDecoration(color: const Color(0xFF102A25), borderRadius: BorderRadius.circular(14)), child: Icon(icon, color: const Color(0xFFB7FF18))),
        title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
        subtitle: Text(subtitle, style: const TextStyle(color: Colors.white54)),
        trailing: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white30, size: 16),
      ),
    );
  }

  @override
  void dispose() {
    _placesDebounce?.cancel();
    _rideRequestsSubscription?.cancel();
    pickupController.dispose();
    destinationController.dispose();
    fareController.dispose();
    super.dispose();
  }
}
