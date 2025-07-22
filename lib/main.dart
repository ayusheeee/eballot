import 'package:flutter/material.dart';
import 'dart:io';
// import 'dart:typed_data'; // Removed unnecessary import
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

class ProfileData {
  static String userName = '';
  static String userLocation = '';
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  ThemeMode _themeMode = ThemeMode.light;

  void _toggleTheme() {
    setState(() {
      _themeMode =
          _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'E-Ballot',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
        brightness: Brightness.dark,
      ),
      themeMode: _themeMode,
      home: AuthScreen(
        onToggleTheme: _toggleTheme,
        isDarkMode: _themeMode == ThemeMode.dark,
      ),
    );
  }
}

class AuthScreen extends StatefulWidget {
  final VoidCallback? onToggleTheme;
  final bool isDarkMode;
  const AuthScreen({super.key, this.onToggleTheme, this.isDarkMode = false});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _aadharController = TextEditingController();
  XFile? _pickedImage;
  bool _isLogin = true;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  // Memoized values to prevent unnecessary rebuilds
  late final ColorScheme _colorScheme;
  late final bool _isWeb = kIsWeb;

  // Debounce timer for form validation
  Timer? _debounceTimer;

  // Cached gradient decoration
  BoxDecoration? _cachedGradientDecoration;

  @override
  void initState() {
    super.initState();
    // Initialize color scheme once
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _colorScheme = Theme.of(context).colorScheme;
        });
      }
    });
  }

  void _showSnackBar(String message, {Color? color}) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message), backgroundColor: color));
  }

  // Validation methods
  bool _validateEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  bool _validatePassword(String password) {
    return password.length >= 6;
  }

  bool _validateAge(String ageText) {
    final age = int.tryParse(ageText);
    return age != null && age >= 18;
  }

  bool _validateName(String name) {
    return name.trim().length >= 2;
  }

  // Optimized submit method with better error handling
  Future<void> _submit() async {
    if (_isLoading) return; // Prevent multiple submissions

    setState(() => _isLoading = true);

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();
    final name = _nameController.text.trim();
    final ageText = _ageController.text.trim();

    try {
      if (_isLogin) {
        await _performLogin(email, password);
      } else {
        await _performRegistration(
          email,
          password,
          confirmPassword,
          name,
          ageText,
        );
      }
    } on FirebaseAuthException catch (e) {
      _showSnackBar(e.message ?? 'Authentication error', color: Colors.red);
    } catch (e) {
      _showSnackBar('Error: $e', color: Colors.red);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // Separated login logic for better maintainability
  Future<void> _performLogin(String email, String password) async {
    if (email.isEmpty || password.isEmpty) {
      _showSnackBar('Please fill all fields', color: Colors.red);
      return;
    }

    if (!_validateEmail(email)) {
      _showSnackBar('Please enter a valid email address', color: Colors.red);
      return;
    }

    final userCred = await FirebaseAuth.instance.signInWithEmailAndPassword(
      email: email,
      password: password,
    );

    // Fetch user data and sync ProfileData
    try {
      final doc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(userCred.user!.uid)
              .get();
      final data = doc.data();
      if (data != null) {
        ProfileData.userName = data['name'] ?? '';
        ProfileData.userLocation = data['location'] ?? '';
      }
    } catch (e) {
      // Continue even if profile data fetch fails
      print('Failed to fetch profile data: $e');
    }

    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder:
              (context) => MainNavigation(
                onToggleTheme: widget.onToggleTheme,
                isDarkMode: widget.isDarkMode,
              ),
        ),
      );
    }
  }

  // Separated registration logic for better maintainability
  Future<void> _performRegistration(
    String email,
    String password,
    String confirmPassword,
    String name,
    String ageText,
  ) async {
    final location = _locationController.text.trim();

    // Validate all fields
    if (email.isEmpty ||
        password.isEmpty ||
        confirmPassword.isEmpty ||
        name.isEmpty ||
        ageText.isEmpty ||
        location.isEmpty ||
        _pickedImage == null) {
      _showSnackBar(
        'Please fill all fields and select a profile image',
        color: Colors.red,
      );
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    if (!_validateEmail(email)) {
      _showSnackBar('Please enter a valid email address', color: Colors.red);
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    if (!_validateName(name)) {
      _showSnackBar(
        'Name must be at least 2 characters long',
        color: Colors.red,
      );
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    if (!_validatePassword(password)) {
      _showSnackBar(
        'Password must be at least 6 characters long',
        color: Colors.red,
      );
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    if (password != confirmPassword) {
      _showSnackBar('Passwords do not match', color: Colors.red);
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    if (!_validateAge(ageText)) {
      _showSnackBar(
        'You must be at least 18 years old to register.',
        color: Colors.red,
      );
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    final age = int.parse(ageText);

    try {
      print('Starting registration...');
      final userCred = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);
      final uid = userCred.user!.uid;
      print('User created: $uid');
      // Upload profile image
      final storageRef = FirebaseStorage.instance.ref().child(
        'profile_images/$uid.jpg',
      );
      if (kIsWeb) {
        print('Uploading image using putData (web)...');
        await storageRef.putData(await _pickedImage!.readAsBytes());
      } else {
        print('Uploading image using putFile (mobile)...');
        await storageRef.putFile(File(_pickedImage!.path));
      }
      final imageUrl = await storageRef.getDownloadURL();
      print('Image uploaded, url: $imageUrl');
      // Generate voter ID
      final voterId = _generateVoterId();
      final aadhar = _aadharController.text.trim();
      if (aadhar.isEmpty ||
          aadhar.length != 12 ||
          !RegExp(r'^\d{12}\$').hasMatch(aadhar)) {
        _showSnackBar(
          'Please enter a valid 12-digit AADHAR number',
          color: Colors.red,
        );
        if (mounted) setState(() => _isLoading = false);
        return;
      }
      // Store all details in Firestore
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'email': email,
        'name': name,
        'age': age,
        'location': location,
        'imageUrl': imageUrl,
        'voterId': voterId,
        'aadharNumber': aadhar,
        'createdAt': FieldValue.serverTimestamp(),
      });
      print('User data written to Firestore.');
      // Fetch the user data just written
      final doc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final data = doc.data();
      if (data != null) {
        ProfileData.userName = data['name'] ?? '';
        ProfileData.userLocation = data['location'] ?? '';
        _nameController.text = data['name'] ?? '';
        _ageController.text = data['age']?.toString() ?? '';
        _locationController.text = data['location'] ?? '';
      }
      if (mounted) {
        setState(() => _isLoading = false);
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder:
                (context) => MainNavigation(
                  onToggleTheme: widget.onToggleTheme,
                  isDarkMode: widget.isDarkMode,
                ),
          ),
        );
      }
    } catch (e, stack) {
      print('Registration error: $e');
      print(stack);
      _showSnackBar('Registration failed: $e', color: Colors.red);
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Optimized password reset dialog with better memory management
  Future<void> _showForgotPasswordDialog() async {
    final TextEditingController emailController = TextEditingController();
    bool isSubmitting = false;

    return showDialog(
      context: context,
      barrierDismissible:
          false, // Prevent accidental dismissal during submission
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Reset Password'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Enter your email address to receive a password reset link.',
                    style: TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    enabled: !isSubmitting,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed:
                      isSubmitting ? null : () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed:
                      isSubmitting
                          ? null
                          : () async {
                            final email = emailController.text.trim();
                            if (email.isEmpty) {
                              _showSnackBar(
                                'Please enter your email address',
                                color: Colors.red,
                              );
                              return;
                            }

                            setDialogState(() => isSubmitting = true);

                            try {
                              await FirebaseAuth.instance
                                  .sendPasswordResetEmail(email: email);
                              if (context.mounted) {
                                Navigator.of(context).pop();
                                _showSnackBar(
                                  'Password reset email sent! Check your inbox.',
                                  color: Colors.green,
                                );
                              }
                            } on FirebaseAuthException catch (e) {
                              _showSnackBar(
                                e.message ?? 'Failed to send reset email',
                                color: Colors.red,
                              );
                            } catch (e) {
                              _showSnackBar('Error: $e', color: Colors.red);
                            } finally {
                              if (context.mounted) {
                                setDialogState(() => isSubmitting = false);
                              }
                            }
                          },
                  child:
                      isSubmitting
                          ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                          : const Text('Send Reset Link'),
                ),
              ],
            );
          },
        );
      },
    ).then((_) {
      emailController.dispose(); // Clean up controller
    });
  }

  // Memoized gradient decoration
  BoxDecoration _getGradientDecoration() {
    return _cachedGradientDecoration ??= BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [_colorScheme.surface, _colorScheme.surface.withOpacity(0.8)],
      ),
    );
  }

  // Optimized toggle method
  void _toggleLoginMode() {
    setState(() => _isLogin = !_isLogin);
  }

  // Optimized password visibility toggle
  void _togglePasswordVisibility() {
    setState(() => _obscurePassword = !_obscurePassword);
  }

  // Optimized confirm password visibility toggle
  void _toggleConfirmPasswordVisibility() {
    setState(() => _obscureConfirmPassword = !_obscureConfirmPassword);
  }

  // Image picker for registration
  Future<void> _pickProfileImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _pickedImage = image;
      });
    }
  }

  // Generate random 8-character voter ID
  String _generateVoterId() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rand = DateTime.now().millisecondsSinceEpoch;
    final buffer = StringBuffer();
    for (int i = 0; i < 8; i++) {
      buffer.write(chars[(rand + i * 31) % chars.length]);
    }
    return buffer.toString();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _nameController.dispose();
    _ageController.dispose();
    _locationController.dispose();
    _aadharController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Use cached color scheme to avoid Theme.of(context) calls
    final colorScheme = _colorScheme;

    return Scaffold(
      body: Container(
        decoration: _getGradientDecoration(),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Theme toggle button - optimized for web
                  if (!_isWeb) _buildThemeToggle(colorScheme),
                  const SizedBox(height: 40),

                  // Welcome title - const where possible
                  _buildWelcomeTitle(colorScheme),
                  const SizedBox(height: 8),
                  _buildSubtitle(colorScheme),
                  const SizedBox(height: 48),

                  // Main card - optimized with const widgets
                  _buildMainCard(colorScheme),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Extracted theme toggle widget
  Widget _buildThemeToggle(ColorScheme colorScheme) {
    return Align(
      alignment: Alignment.topRight,
      child: IconButton(
        icon: Icon(
          widget.isDarkMode ? Icons.light_mode : Icons.dark_mode,
          color: colorScheme.primary,
        ),
        tooltip:
            widget.isDarkMode ? 'Switch to Light Mode' : 'Switch to Dark Mode',
        onPressed: widget.onToggleTheme,
      ),
    );
  }

  // Extracted welcome title widget
  Widget _buildWelcomeTitle(ColorScheme colorScheme) {
    return Text(
      'Welcome to eBallot',
      style: TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.bold,
        color: colorScheme.primary,
        letterSpacing: -0.5,
      ),
    );
  }

  // Extracted subtitle widget
  Widget _buildSubtitle(ColorScheme colorScheme) {
    return Text(
      _isLogin ? 'Sign in to your account' : 'Create your account',
      style: TextStyle(
        fontSize: 16,
        color: colorScheme.onSurface.withOpacity(0.7),
      ),
    );
  }

  // Extracted main card widget
  Widget _buildMainCard(ColorScheme colorScheme) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 400),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!_isLogin) ...[
            Center(
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 44,
                    backgroundImage:
                        _pickedImage != null
                            ? (kIsWeb
                                ? NetworkImage(_pickedImage!.path)
                                : FileImage(File(_pickedImage!.path))
                                    as ImageProvider)
                            : null,
                    child:
                        _pickedImage == null
                            ? const Icon(Icons.account_circle, size: 64)
                            : null,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: InkWell(
                      onTap: _pickProfileImage,
                      child: CircleAvatar(
                        radius: 18,
                        backgroundColor: colorScheme.primary,
                        child: Icon(
                          Icons.edit,
                          color: colorScheme.onPrimary,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Please upload your picture as it appears on your AADHAR card.',
              style: TextStyle(fontSize: 13, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            _buildAadharField(colorScheme),
            const SizedBox(height: 20),
            _buildNameField(colorScheme),
            const SizedBox(height: 20),
          ],
          _buildEmailField(colorScheme),
          const SizedBox(height: 20),
          _buildPasswordField(colorScheme),
          if (!_isLogin) ...[
            const SizedBox(height: 20),
            _buildConfirmPasswordField(colorScheme),
          ],
          if (_isLogin) _buildForgotPasswordButton(colorScheme),
          if (!_isLogin) ...[
            const SizedBox(height: 20),
            _buildAgeField(colorScheme),
            const SizedBox(height: 20),
            _buildLocationField(colorScheme),
          ],
          const SizedBox(height: 32),
          _buildSubmitButton(colorScheme),
          const SizedBox(height: 24),
          _buildToggleButton(colorScheme),
        ],
      ),
    );
  }

  // Extracted name field widget
  Widget _buildNameField(ColorScheme colorScheme) {
    return TextFormField(
      controller: _nameController,
      keyboardType: TextInputType.name,
      textCapitalization: TextCapitalization.words,
      decoration: InputDecoration(
        labelText: 'Full Name',
        prefixIcon: Icon(Icons.person_outline, color: colorScheme.primary),
        border: _getInputBorder(colorScheme),
        enabledBorder: _getInputBorder(colorScheme),
        focusedBorder: _getFocusedInputBorder(colorScheme),
        filled: true,
        fillColor: colorScheme.surface,
      ),
    );
  }

  // Extracted email field widget
  Widget _buildEmailField(ColorScheme colorScheme) {
    return TextFormField(
      controller: _emailController,
      keyboardType: TextInputType.emailAddress,
      decoration: InputDecoration(
        labelText: 'Email',
        prefixIcon: Icon(Icons.email_outlined, color: colorScheme.primary),
        border: _getInputBorder(colorScheme),
        enabledBorder: _getInputBorder(colorScheme),
        focusedBorder: _getFocusedInputBorder(colorScheme),
        filled: true,
        fillColor: colorScheme.surface,
      ),
    );
  }

  // Extracted password field widget
  Widget _buildPasswordField(ColorScheme colorScheme) {
    return TextFormField(
      controller: _passwordController,
      obscureText: _obscurePassword,
      decoration: InputDecoration(
        labelText: _isLogin ? 'Password' : 'Password (min. 6 characters)',
        prefixIcon: Icon(Icons.lock_outlined, color: colorScheme.primary),
        suffixIcon: IconButton(
          icon: Icon(
            _obscurePassword ? Icons.visibility : Icons.visibility_off,
            color: colorScheme.onSurface.withOpacity(0.6),
          ),
          onPressed: _togglePasswordVisibility,
        ),
        border: _getInputBorder(colorScheme),
        enabledBorder: _getInputBorder(colorScheme),
        focusedBorder: _getFocusedInputBorder(colorScheme),
        filled: true,
        fillColor: colorScheme.surface,
      ),
    );
  }

  // Extracted confirm password field widget
  Widget _buildConfirmPasswordField(ColorScheme colorScheme) {
    return TextFormField(
      controller: _confirmPasswordController,
      obscureText: _obscureConfirmPassword,
      decoration: InputDecoration(
        labelText: 'Confirm Password',
        prefixIcon: Icon(Icons.lock_outlined, color: colorScheme.primary),
        suffixIcon: IconButton(
          icon: Icon(
            _obscureConfirmPassword ? Icons.visibility : Icons.visibility_off,
            color: colorScheme.onSurface.withOpacity(0.6),
          ),
          onPressed: _toggleConfirmPasswordVisibility,
        ),
        border: _getInputBorder(colorScheme),
        enabledBorder: _getInputBorder(colorScheme),
        focusedBorder: _getFocusedInputBorder(colorScheme),
        filled: true,
        fillColor: colorScheme.surface,
      ),
    );
  }

  // Extracted forgot password button widget
  Widget _buildForgotPasswordButton(ColorScheme colorScheme) {
    return Align(
      alignment: Alignment.centerRight,
      child: TextButton(
        onPressed: _showForgotPasswordDialog,
        style: TextButton.styleFrom(foregroundColor: colorScheme.primary),
        child: const Text(
          'Forgot Password?',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }

  // Extracted age field widget
  Widget _buildAgeField(ColorScheme colorScheme) {
    return TextFormField(
      controller: _ageController,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: 'Age (must be 18 or above)',
        prefixIcon: Icon(
          Icons.calendar_today_outlined,
          color: colorScheme.primary,
        ),
        border: _getInputBorder(colorScheme),
        enabledBorder: _getInputBorder(colorScheme),
        focusedBorder: _getFocusedInputBorder(colorScheme),
        filled: true,
        fillColor: colorScheme.surface,
      ),
    );
  }

  // Extracted location field widget
  Widget _buildLocationField(ColorScheme colorScheme) {
    return TextFormField(
      controller: _locationController,
      keyboardType: TextInputType.text,
      decoration: InputDecoration(
        labelText: 'Location',
        prefixIcon: Icon(
          Icons.location_on_outlined,
          color: colorScheme.primary,
        ),
        border: _getInputBorder(colorScheme),
        enabledBorder: _getInputBorder(colorScheme),
        focusedBorder: _getFocusedInputBorder(colorScheme),
        filled: true,
        fillColor: colorScheme.surface,
      ),
    );
  }

  // Extracted submit button widget
  Widget _buildSubmitButton(ColorScheme colorScheme) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : ElevatedButton(
                onPressed: _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                  elevation: 8,
                  shadowColor: colorScheme.primary.withOpacity(0.3),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  _isLogin ? 'Sign In' : 'Create Account',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
    );
  }

  // Extracted toggle button widget
  Widget _buildToggleButton(ColorScheme colorScheme) {
    return Center(
      child: TextButton(
        onPressed: _toggleLoginMode,
        style: TextButton.styleFrom(foregroundColor: colorScheme.primary),
        child: Text(
          _isLogin
              ? 'Don\'t have an account? Sign up'
              : 'Already have an account? Sign in',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }

  // Memoized input border styles
  OutlineInputBorder _getInputBorder(ColorScheme colorScheme) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: colorScheme.outline.withOpacity(0.3)),
    );
  }

  OutlineInputBorder _getFocusedInputBorder(ColorScheme colorScheme) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: colorScheme.primary, width: 2),
    );
  }

  // Add the AADHAR field builder:
  Widget _buildAadharField(ColorScheme colorScheme) {
    return TextFormField(
      controller: _aadharController,
      keyboardType: TextInputType.number,
      maxLength: 12,
      decoration: InputDecoration(
        labelText: 'AADHAR Number',
        prefixIcon: Icon(Icons.credit_card, color: colorScheme.primary),
        border: _getInputBorder(colorScheme),
        enabledBorder: _getInputBorder(colorScheme),
        focusedBorder: _getFocusedInputBorder(colorScheme),
        filled: true,
        fillColor: colorScheme.surface,
        counterText: '',
      ),
    );
  }
}

class MainNavigation extends StatefulWidget {
  final VoidCallback? onToggleTheme;
  final bool isDarkMode;
  const MainNavigation({
    super.key,
    this.onToggleTheme,
    this.isDarkMode = false,
  });

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _selectedIndex = 0;

  static const List<String> _validVoterIds = ['VOTE123', 'VOTE456'];

  final TextEditingController _voterIdController = TextEditingController();
  String? _voteMessage;
  Color? _voteMessageColor;

  List<Widget> _buildPages() {
    return [
      HomePage(),
      CandidateFirestoreSearchPage(),
      VotePage(
        onVerify: _onVerify,
        voterIdController: _voterIdController,
        voteMessage: _voteMessage,
        voteMessageColor: _voteMessageColor,
      ),
      SocialPage(),
      ProfilePage(onToggleTheme: widget.onToggleTheme),
    ];
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void _onVerify() {
    final id = _voterIdController.text.trim();
    setState(() {
      if (_validVoterIds.contains(id)) {
        _voteMessage = 'Verified!';
        _voteMessageColor = Colors.green;
      } else {
        _voteMessage = 'Invalid Voter ID';
        _voteMessageColor = Colors.red;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          ['Home', 'Search', 'Vote', 'Social', 'Profile'][_selectedIndex],
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF8E24AA), // Soft purple
                Color(0xFF1976D2), // Deep blue
              ],
            ),
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(widget.isDarkMode ? Icons.light_mode : Icons.dark_mode),
            tooltip:
                widget.isDarkMode
                    ? 'Switch to Light Mode'
                    : 'Switch to Dark Mode',
            onPressed: widget.onToggleTheme,
          ),
        ],
      ),
      body: _buildPages()[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Search'),
          BottomNavigationBarItem(icon: Icon(Icons.how_to_vote), label: 'Vote'),
          BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Social'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Theme.of(context).colorScheme.primary,
        onTap: _onItemTapped,
      ),
    );
  }
}

// Home Page
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  final List<Map<String, String>> electionUpdates = const [
    {
      'title': 'Presidential Election 2024',
      'description':
          'Voting starts on Nov 5th. Make sure to check your registration status.',
      'date': 'Nov 1, 2025',
    },
    {
      'title': 'Local Council Results',
      'description':
          'Results for the local council elections are now available online.',
      'date': 'Oct 30, 2025',
    },
    {
      'title': 'New Voting Guidelines',
      'description': 'Read about the updated guidelines for absentee ballots.',
      'date': 'Oct 28, 2025',
    },
    {
      'title': 'Debate Schedule Announced',
      'description':
          'The official debate schedule for candidates has been released.',
      'date': 'Oct 20, 2025',
    },
    {
      'title': 'Voter Education Drive',
      'description':
          'Join our voter education sessions happening throughout October.',
      'date': 'Oct 15, 2025',
    },
  ];

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  List<double> _opacities = [];
  bool _showBanner = true;

  // Poll of the Day state
  final String _pollQuestion = 'Should voting be mandatory?';
  final List<String> _pollOptions = ['Yes', 'No', 'Not Sure'];
  String? _selectedPollOption;
  bool _hasVoted = false;

  // In _HomePageState, add state for hovered card and hovered action button
  int? _hoveredCardIndex;
  int? _hoveredActionIndex;

  final Map<String, List<Map<String, String>>> districtUpdates = {
    'Springfield': [
      {
        'title': 'Springfield Water Supply Notice',
        'description':
            'Water supply will be interrupted on Nov 6th for maintenance.',
        'date': 'Nov 3, 2025',
      },
      {
        'title': 'Local Park Renovation',
        'description': 'Renovation of Central Park starts next week.',
        'date': 'Nov 2, 2025',
      },
    ],
    'Shelbyville': [
      {
        'title': 'Shelbyville Road Closures',
        'description': 'Main Street closed for parade on Nov 7th.',
        'date': 'Nov 4, 2025',
      },
    ],
  };

  List<Map<String, String>> get _filteredUpdates {
    if (_searchQuery.isEmpty) return electionUpdates;
    return electionUpdates.where((update) {
      final title = update['title']?.toLowerCase() ?? '';
      final desc = update['description']?.toLowerCase() ?? '';
      final query = _searchQuery.toLowerCase();
      return title.contains(query) || desc.contains(query);
    }).toList();
  }

  DateTime _now = DateTime.now();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _opacities = List.filled(electionUpdates.length, 0.0);
    _fadeInCards();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
      });
    });
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      setState(() {
        _now = DateTime.now();
      });
    });
  }

  void _fadeInCards() async {
    for (int i = 0; i < electionUpdates.length; i++) {
      await Future.delayed(const Duration(milliseconds: 150));
      if (mounted) {
        setState(() {
          _opacities[i] = 1.0;
        });
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  String get formattedDateTime {
    return DateFormat('EEEE, MMMM d, y — hh:mm a').format(_now);
  }

  void _showQuickActionDialog(
    String title,
    String message, {
    List<Map<String, String>>? faqs,
  }) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(title),
            content:
                faqs == null
                    ? Text(message)
                    : SizedBox(
                      width: double.maxFinite,
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: faqs.length,
                        separatorBuilder:
                            (context, i) => const Divider(height: 24),
                        itemBuilder:
                            (context, i) => Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  faqs[i]['q']!,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(faqs[i]['a']!),
                              ],
                            ),
                      ),
                    ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Stack(
      children: [
        // Gradient background with decorative shapes
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [colorScheme.surface, colorScheme.surface],
            ),
          ),
        ),
        // Decorative circles
        Positioned(
          top: -40,
          left: -40,
          child: Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colorScheme.primary.withOpacity(0.08),
            ),
          ),
        ),
        Positioned(
          bottom: 60,
          right: -30,
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colorScheme.secondary.withOpacity(0.07),
            ),
          ),
        ),
        // Main content
        SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (ProfileData.userName.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 16.0, bottom: 8.0),
                    child: Text(
                      'Welcome, ${ProfileData.userName}',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.primary,
                      ),
                    ),
                  ),
                if (_showBanner)
                  MaterialBanner(
                    backgroundColor: colorScheme.secondary.withOpacity(0.1),
                    content: Text(
                      '🛑 Voting Deadline Tomorrow – Nov 4th',
                      style: TextStyle(
                        color: colorScheme.error,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _showBanner = false;
                          });
                        },
                        child: Text(
                          'DISMISS',
                          style: TextStyle(color: colorScheme.error),
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 32),
                Center(
                  child: Text(
                    'Latest Election Updates',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Center(
                  child: Text(
                    formattedDateTime,
                    style: TextStyle(
                      fontSize: 15,
                      color: colorScheme.onSurface.withOpacity(0.7),
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      labelText: 'Search updates...',
                      prefixIcon: Icon(
                        Icons.search,
                        color: colorScheme.primary,
                      ),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      const SizedBox(width: 16),
                      ...[0, 1, 2].map((i) {
                        final isHovered = _hoveredActionIndex == i;
                        final buttonData =
                            [
                              {
                                'label': 'Check Registration',
                                'icon': Icons.how_to_reg,
                                'onPressed': () {
                                  _showQuickActionDialog(
                                    'Check Registration',
                                    'Here you can check your voter registration status. (Feature coming soon)',
                                  );
                                },
                              },
                              {
                                'label': 'Election FAQs',
                                'icon': Icons.help_outline,
                                'onPressed': () {
                                  _showQuickActionDialog(
                                    'Election FAQs',
                                    '',
                                    faqs: [
                                      {
                                        'q': 'What is E-Ballot?',
                                        'a':
                                            'E-Ballot is a secure online voting platform for modern elections.',
                                      },
                                      {
                                        'q': 'How do I register to vote?',
                                        'a':
                                            'You can register through the official government portal or check your status in the app.',
                                      },
                                      {
                                        'q': 'Is online voting secure?',
                                        'a':
                                            'Yes, E-Ballot uses encryption and multi-factor authentication to ensure security.',
                                      },
                                      {
                                        'q': 'Can I vote from any location?',
                                        'a':
                                            'Yes, as long as you have internet access and are a registered voter.',
                                      },
                                      {
                                        'q': 'How do I verify my identity?',
                                        'a':
                                            'You will need to provide your Voter ID and complete a face verification step.',
                                      },
                                      {
                                        'q':
                                            'Can I change my vote after submitting?',
                                        'a':
                                            'No, once submitted, your vote is final and cannot be changed.',
                                      },
                                      {
                                        'q':
                                            'How do I know my vote was counted?',
                                        'a':
                                            'You will receive a confirmation after voting, and you can check the status in the app.',
                                      },
                                      {
                                        'q': 'Is my vote anonymous?',
                                        'a':
                                            'Yes, all votes are anonymized and cannot be traced back to individuals.',
                                      },
                                      {
                                        'q': 'What if I forget my Voter ID?',
                                        'a':
                                            'You can recover your Voter ID through the official portal or contact support.',
                                      },
                                      {
                                        'q':
                                            'Can I vote using my mobile device?',
                                        'a':
                                            'Yes, E-Ballot is accessible on smartphones, tablets, and computers.',
                                      },
                                      {
                                        'q':
                                            'What should I do if I face technical issues?',
                                        'a':
                                            'Contact support through the app or email support@eballot.com.',
                                      },
                                      {
                                        'q':
                                            'Are there any fees for online voting?',
                                        'a':
                                            'No, using E-Ballot is completely free for all eligible voters.',
                                      },
                                      {
                                        'q':
                                            'How do I access live election results?',
                                        'a':
                                            'Tap the "Live Results" quick action on the Home Page.',
                                      },
                                      {
                                        'q':
                                            'Can I participate in polls or surveys?',
                                        'a':
                                            'Yes, check the Home Page for Poll of the Day and other surveys.',
                                      },
                                      {
                                        'q': 'Is my personal data safe?',
                                        'a':
                                            'Yes, E-Ballot complies with all data protection regulations and never shares your data.',
                                      },
                                    ],
                                  );
                                },
                              },
                              {
                                'label': 'Live Results',
                                'icon': Icons.bar_chart,
                                'onPressed': () {
                                  _showQuickActionDialog(
                                    'Live Results',
                                    'View live election results here. (Feature coming soon)',
                                  );
                                },
                              },
                            ][i];
                        final Matrix4 buttonTransformMatrix =
                            isHovered
                                ? (Matrix4.identity()..scale(1.04))
                                : Matrix4.identity();
                        return Padding(
                          padding: EdgeInsets.only(right: i < 2 ? 12 : 0),
                          child: MouseRegion(
                            onEnter:
                                (_) => setState(() => _hoveredActionIndex = i),
                            onExit:
                                (_) =>
                                    setState(() => _hoveredActionIndex = null),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              curve: Curves.easeOut,
                              transform: buttonTransformMatrix,
                              child: ElevatedButton.icon(
                                onPressed:
                                    buttonData['onPressed'] as void Function(),
                                icon: Icon(
                                  buttonData['icon'] as IconData,
                                  color: colorScheme.onPrimary,
                                ),
                                label: Text(
                                  buttonData['label'] as String,
                                  style: TextStyle(
                                    color: colorScheme.onPrimary,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 10,
                                  ),
                                  backgroundColor:
                                      isHovered
                                          ? colorScheme.primary.withOpacity(
                                            0.92,
                                          )
                                          : colorScheme.primary,
                                  elevation: isHovered ? 6 : 2,
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                      const SizedBox(width: 16),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Election updates cards
                ..._filteredUpdates.asMap().entries.map((entry) {
                  final index = entry.key;
                  final update = entry.value;
                  final originalIndex = electionUpdates.indexOf(update);
                  final isHovered = _hoveredCardIndex == index;
                  final Matrix4 cardTransformMatrix =
                      isHovered
                          ? (Matrix4.identity()..scale(1.02))
                          : Matrix4.identity();
                  return Column(
                    children: [
                      MouseRegion(
                        onEnter:
                            (_) => setState(() => _hoveredCardIndex = index),
                        onExit: (_) => setState(() => _hoveredCardIndex = null),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          curve: Curves.easeOut,
                          transform: cardTransformMatrix,
                          decoration: BoxDecoration(
                            boxShadow:
                                isHovered
                                    ? [
                                      BoxShadow(
                                        color: colorScheme.shadow.withOpacity(
                                          0.08,
                                        ),
                                        blurRadius: 16,
                                        offset: const Offset(0, 6),
                                      ),
                                    ]
                                    : [],
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            splashColor: colorScheme.primary.withOpacity(0.08),
                            highlightColor: colorScheme.primary.withOpacity(
                              0.04,
                            ),
                            onTap: () {
                              showModalBottomSheet(
                                context: context,
                                shape: const RoundedRectangleBorder(
                                  borderRadius: BorderRadius.vertical(
                                    top: Radius.circular(24),
                                  ),
                                ),
                                builder: (context) {
                                  return Padding(
                                    padding: const EdgeInsets.all(24.0),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          update['title'] ?? '',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 22,
                                            color: colorScheme.primary,
                                          ),
                                        ),
                                        if (update['date'] != null)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              top: 6.0,
                                              bottom: 12.0,
                                            ),
                                            child: Text(
                                              update['date']!,
                                              style: TextStyle(
                                                fontSize: 15,
                                                color: colorScheme.onSurface
                                                    .withOpacity(0.7),
                                                fontWeight: FontWeight.w400,
                                              ),
                                            ),
                                          ),
                                        Text(
                                          update['description'] ?? '',
                                          style: TextStyle(
                                            fontSize: 16,
                                            color: colorScheme.onSurface,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              );
                            },
                            child: Card(
                              color: colorScheme.surface,
                              elevation: 4,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              margin: EdgeInsets.zero,
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: ListTile(
                                  title: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        update['title'] ?? '',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 18,
                                          color: colorScheme.primary,
                                        ),
                                      ),
                                      if (update['date'] != null)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            top: 2.0,
                                            bottom: 2.0,
                                          ),
                                          child: Text(
                                            update['date']!,
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: colorScheme.onSurface
                                                  .withOpacity(0.7),
                                              fontWeight: FontWeight.w400,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  subtitle: Text(
                                    update['description'] ?? '',
                                    style: TextStyle(
                                      color: colorScheme.onSurface,
                                    ),
                                  ),
                                  leading: _getCardIcon(
                                    update,
                                    colorScheme: colorScheme,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 36),
                    ],
                  );
                }),
                // District-specific updates section
                if (ProfileData.userLocation.isNotEmpty &&
                    districtUpdates[ProfileData.userLocation] != null) ...[
                  const SizedBox(height: 24),
                  Text(
                    'Updates for ${ProfileData.userLocation}',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...districtUpdates[ProfileData.userLocation]!.map(
                    (update) => Column(
                      children: [
                        Card(
                          color: colorScheme.surface,
                          elevation: 3,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: ListTile(
                            title: Text(
                              update['title'] ?? '',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: colorScheme.primary,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (update['date'] != null)
                                  Padding(
                                    padding: const EdgeInsets.only(
                                      top: 2.0,
                                      bottom: 2.0,
                                    ),
                                    child: Text(
                                      update['date']!,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: colorScheme.onSurface
                                            .withOpacity(0.7),
                                        fontWeight: FontWeight.w400,
                                      ),
                                    ),
                                  ),
                                Text(
                                  update['description'] ?? '',
                                  style: TextStyle(
                                    color: colorScheme.onSurface,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ],
                // Poll of the Day card
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 12.0,
                  ),
                  child: Card(
                    color: colorScheme.surface,
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child:
                          _hasVoted
                              ? Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Poll of the Day',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                      color: colorScheme.primary,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _pollQuestion,
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: colorScheme.onSurface,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Thank you for voting!',
                                    style: TextStyle(
                                      color: colorScheme.secondary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              )
                              : Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Poll of the Day',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                      color: colorScheme.primary,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _pollQuestion,
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: colorScheme.onSurface,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  ..._pollOptions.map(
                                    (option) => RadioListTile<String>(
                                      title: Text(
                                        option,
                                        style: TextStyle(
                                          color: colorScheme.onSurface,
                                        ),
                                      ),
                                      value: option,
                                      groupValue: _selectedPollOption,
                                      onChanged: (value) {
                                        setState(() {
                                          _selectedPollOption = value;
                                        });
                                      },
                                      activeColor: colorScheme.primary,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton(
                                      onPressed:
                                          _selectedPollOption == null
                                              ? null
                                              : () {
                                                setState(() {
                                                  _hasVoted = true;
                                                });
                                              },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: colorScheme.primary,
                                        foregroundColor: colorScheme.onPrimary,
                                      ),
                                      child: const Text('Vote'),
                                    ),
                                  ),
                                ],
                              ),
                    ),
                  ),
                ),
                // Footer
                Padding(
                  padding: const EdgeInsets.only(top: 32.0, bottom: 8.0),
                  child: Center(
                    child: Column(
                      children: [
                        Text(
                          'Version 1.0.0',
                          style: TextStyle(
                            color: colorScheme.onSurface.withOpacity(0.6),
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 4),
                        InkWell(
                          onTap: () async {
                            final Uri emailLaunchUri = Uri(
                              scheme: 'mailto',
                              path: 'support@eballot.com',
                              query: 'subject=E-Ballot App Support',
                            );
                            if (await canLaunchUrl(emailLaunchUri)) {
                              await launchUrl(emailLaunchUri);
                            }
                          },
                          child: Text(
                            'Contact Support',
                            style: TextStyle(
                              color: colorScheme.primary,
                              fontSize: 14,
                              decoration: TextDecoration.underline,
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
      ],
    );
  }

  Color _getCardColor(Map<String, String> update, {ColorScheme? colorScheme}) {
    colorScheme ??= Theme.of(context).colorScheme;
    final title = update['title']?.toLowerCase() ?? '';
    final desc = update['description']?.toLowerCase() ?? '';
    if (title.contains('result') ||
        desc.contains('result') ||
        title.contains('success')) {
      return colorScheme.secondaryContainer;
    } else if (title.contains('reminder') ||
        desc.contains('reminder') ||
        title.contains('education')) {
      return colorScheme.tertiaryContainer;
    } else if (title.contains('alert') ||
        desc.contains('alert') ||
        title.contains('guideline')) {
      return colorScheme.errorContainer;
    } else {
      return colorScheme.surface;
    }
  }

  Icon _getCardIcon(Map<String, String> update, {ColorScheme? colorScheme}) {
    colorScheme ??= Theme.of(context).colorScheme;
    final title = update['title']?.toLowerCase() ?? '';
    final desc = update['description']?.toLowerCase() ?? '';
    if (title.contains('vote') || desc.contains('vote')) {
      return const Icon(Icons.how_to_vote, color: Color(0xFF1976D2), size: 32);
    } else if (title.contains('schedule') || desc.contains('schedule')) {
      return const Icon(Icons.schedule, color: Color(0xFF6D4C41), size: 32);
    } else if (title.contains('guideline') ||
        title.contains('alert') ||
        desc.contains('guideline') ||
        desc.contains('alert')) {
      return const Icon(Icons.announcement, color: Color(0xFFD32F2F), size: 32);
    } else if (title.contains('education') || desc.contains('education')) {
      return const Icon(Icons.school, color: Color(0xFF388E3C), size: 32);
    } else if (title.contains('result') || desc.contains('result')) {
      return const Icon(Icons.emoji_events, color: Color(0xFFFBC02D), size: 32);
    } else {
      return const Icon(Icons.campaign, color: Color(0xFF616161), size: 32);
    }
  }
}

// Search Page
class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Search Candidates')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('candidates').snapshots(),
        builder: (context, snapshot) {
          print('Snapshot state: ${snapshot.connectionState}');
          print('Documents: ${snapshot.data?.docs}');

          if (snapshot.hasError) {
            return Center(child: Text('Error: 24{snapshot.error}'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No candidates found.'));
          }

          final candidates = snapshot.data!.docs;

          return ListView.builder(
            itemCount: candidates.length,
            itemBuilder: (context, index) {
              final data = candidates[index].data() as Map<String, dynamic>;
              return ListTile(
                leading: const Icon(Icons.person),
                title: Text(data['name'] ?? 'No name'),
                subtitle: Text(data['party'] ?? 'No party'),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// Vote Page
class VotePage extends StatefulWidget {
  final TextEditingController voterIdController;
  final VoidCallback onVerify;
  final String? voteMessage;
  final Color? voteMessageColor;

  const VotePage({
    super.key,
    required this.voterIdController,
    required this.onVerify,
    this.voteMessage,
    this.voteMessageColor,
  });

  @override
  State<VotePage> createState() => _VotePageState();
}

class _VotePageState extends State<VotePage> {
  XFile? _capturedFace;
  String? _faceResult;
  bool get _isVerified => widget.voteMessage == 'Verified!';

  // Voting state
  String? _selectedCandidate;
  bool _voteSubmitted = false;
  final List<String> _candidates = [
    'Candidate A',
    'Candidate B',
    'Candidate C',
  ];

  Future<void> _captureAndVerifyFace() async {
    final ImagePicker picker = ImagePicker();
    try {
      final XFile? image = await picker.pickImage(source: ImageSource.camera);
      if (image != null) {
        setState(() {
          _capturedFace = image;
          // Placeholder: In a real app, compare with profile image
          _faceResult = 'Face verified (placeholder)!';
        });
      }
    } catch (e) {
      setState(() {
        _faceResult = 'Failed to capture: $e';
      });
    }
  }

  void _submitVote() {
    setState(() {
      _voteSubmitted = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: widget.voterIdController,
              decoration: const InputDecoration(labelText: 'Enter Voter ID'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: widget.onVerify,
              child: const Text('Verify'),
            ),
            if (widget.voteMessage != null)
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: Text(
                  widget.voteMessage!,
                  style: TextStyle(
                    color: widget.voteMessageColor ?? Colors.green,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            if (_isVerified)
              Column(
                children: [
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _captureAndVerifyFace,
                    child: const Text('Capture & Verify Face'),
                  ),
                  if (_capturedFace != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 16.0),
                      child:
                          kIsWeb
                              ? Image.network(
                                _capturedFace!.path,
                                width: 200,
                                height: 200,
                              )
                              : Image.file(
                                File(_capturedFace!.path),
                                width: 200,
                                height: 200,
                              ),
                    ),
                  if (_faceResult != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 16.0),
                      child: Text(
                        _faceResult!,
                        style: const TextStyle(
                          color: Colors.blue,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  // Voting UI after face verification
                  if (_faceResult == 'Face verified (placeholder)!')
                    _voteSubmitted
                        ? Padding(
                          padding: const EdgeInsets.only(top: 24.0),
                          child: Text(
                            'Your vote has been recorded anonymously.',
                            style: TextStyle(
                              color: Colors.green[700],
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        )
                        : Column(
                          children: [
                            const SizedBox(height: 24),
                            const Text('Select a candidate:'),
                            ..._candidates.map(
                              (candidate) => RadioListTile<String>(
                                title: Text(candidate),
                                value: candidate,
                                groupValue: _selectedCandidate,
                                onChanged: (value) {
                                  setState(() {
                                    _selectedCandidate = value;
                                  });
                                },
                              ),
                            ),
                            ElevatedButton(
                              onPressed:
                                  _selectedCandidate == null
                                      ? null
                                      : _submitVote,
                              child: const Text('Submit Vote'),
                            ),
                          ],
                        ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

// Social Page
class SocialPage extends StatefulWidget {
  const SocialPage({super.key});

  @override
  State<SocialPage> createState() => _SocialPageState();
}

class _SocialPageState extends State<SocialPage> {
  final List<String> _communities = const [
    'Party A – Progress First',
    'Party B – Green Future',
    'Independent Group – Unity Alliance',
  ];
  final Set<int> _joinedIndexes = {};

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _communities.length,
      itemBuilder: (context, index) {
        final joined = _joinedIndexes.contains(index);
        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          child: ListTile(
            title: Text(_communities[index]),
            trailing: ElevatedButton(
              onPressed:
                  joined
                      ? null
                      : () {
                        setState(() {
                          _joinedIndexes.add(index);
                        });
                      },
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    joined
                        ? Colors.grey
                        : Theme.of(context).colorScheme.primary,
              ),
              child: Text(joined ? 'Joined' : 'Join'),
            ),
          ),
        );
      },
    );
  }
}

// Profile Page
class ProfilePage extends StatefulWidget {
  final VoidCallback? onToggleTheme;
  const ProfilePage({super.key, this.onToggleTheme});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  String? _imageUrl;
  bool _isLoading = false;
  bool _isSaving = false;
  User? _user;
  String? _aadharNumber;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Profile'),
        leading: Container(
          margin: const EdgeInsets.only(left: 8, top: 8),
          decoration: BoxDecoration(
            color: colorScheme.surface.withOpacity(0.85),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 8),
            ],
          ),
          child: IconButton(
            icon: Icon(
              Theme.of(context).brightness == Brightness.dark
                  ? Icons.light_mode
                  : Icons.dark_mode,
              color: colorScheme.primary,
            ),
            tooltip:
                Theme.of(context).brightness == Brightness.dark
                    ? 'Switch to Light Mode'
                    : 'Switch to Dark Mode',
            onPressed: widget.onToggleTheme,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.error,
                foregroundColor: colorScheme.onError,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
              ),
              onPressed: _logout,
              icon: const Icon(Icons.logout),
              label: const Text('Logout'),
            ),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              colorScheme.primary.withOpacity(0.08),
              colorScheme.secondary.withOpacity(0.08),
            ],
          ),
        ),
        child:
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 32,
                    ),
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 420),
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        color: colorScheme.surface,
                        borderRadius: BorderRadius.circular(32),
                        boxShadow: [
                          BoxShadow(
                            color: colorScheme.shadow.withOpacity(0.08),
                            blurRadius: 32,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Avatar
                          Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: colorScheme.primary.withOpacity(0.18),
                                  blurRadius: 16,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                              border: Border.all(
                                color: colorScheme.primary,
                                width: 3,
                              ),
                            ),
                            child: CircleAvatar(
                              radius: 54,
                              backgroundImage:
                                  _imageUrl != null && _imageUrl!.isNotEmpty
                                      ? NetworkImage(_imageUrl!)
                                      : null,
                              child:
                                  _imageUrl == null || _imageUrl!.isEmpty
                                      ? const Icon(
                                        Icons.account_circle,
                                        size: 80,
                                      )
                                      : null,
                            ),
                          ),
                          const SizedBox(height: 24),
                          // User Info Card
                          _buildProfileInfoRow(
                            icon: Icons.person,
                            label: 'Name',
                            value: _nameController.text,
                            color: colorScheme.primary,
                          ),
                          _buildProfileInfoRow(
                            icon: Icons.cake,
                            label: 'Age',
                            value: _ageController.text,
                            color: colorScheme.secondary,
                          ),
                          _buildProfileInfoRow(
                            icon: Icons.location_on,
                            label: 'Location',
                            value: _locationController.text,
                            color: colorScheme.tertiary,
                          ),
                          _buildProfileInfoRow(
                            icon: Icons.email,
                            label: 'Email',
                            value: _user?.email ?? '',
                            color: colorScheme.primary,
                          ),
                          _buildProfileInfoRow(
                            icon: Icons.how_to_vote,
                            label: 'Voter ID',
                            value: _getVoterId(),
                            color: colorScheme.secondary,
                          ),
                          _buildProfileInfoRow(
                            icon: Icons.credit_card,
                            label: 'AADHAR Number',
                            value: _aadharNumber ?? '-',
                            color: colorScheme.tertiary,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
      ),
    );
  }

  // Helper to build info row
  Widget _buildProfileInfoRow({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    value.isNotEmpty ? value : '-',
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Helper to get voterId from Firestore data
  String _getVoterId() {
    // Try to get from Firestore data if loaded
    // (Assumes _user is set and _user!.uid is valid)
    // If not found, return '-'
    // This is a placeholder; you may want to cache voterId after loading profile
    return _user != null && _user!.uid.isNotEmpty
        ? _voterIdFromFirestore ?? '-'
        : '-';
  }

  String? _voterIdFromFirestore;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);
    _user = FirebaseAuth.instance.currentUser;
    if (_user == null) {
      // Not logged in, go back to login
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => AuthScreen()),
        (route) => false,
      );
      return;
    }
    final doc =
        await FirebaseFirestore.instance
            .collection('users')
            .doc(_user!.uid)
            .get();
    final data = doc.data();
    if (data != null) {
      _nameController.text = data['name'] ?? '';
      _ageController.text = data['age']?.toString() ?? '';
      _locationController.text = data['location'] ?? '';
      _imageUrl = data['imageUrl'] as String?;
      _voterIdFromFirestore = data['voterId'] as String?;
      _aadharNumber = data['aadharNumber'] as String?;
      // Update ProfileData static variables for use in other pages
      ProfileData.userName = data['name'] ?? '';
      ProfileData.userLocation = data['location'] ?? '';
    }
    setState(() => _isLoading = false);
  }

  Future<void> _pickAndUploadImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null && _user != null) {
      setState(() => _isSaving = true);
      try {
        final storageRef = FirebaseStorage.instance.ref().child(
          'profile_images/${_user!.uid}.jpg',
        );
        await storageRef.putFile(File(pickedFile.path));
        final url = await storageRef.getDownloadURL();
        setState(() {
          _imageUrl = url;
        });
        await FirebaseFirestore.instance
            .collection('users')
            .doc(_user!.uid)
            .update({'imageUrl': url});
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Profile image updated!')));
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Image upload failed: $e')));
      } finally {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate() || _user == null) return;
    setState(() => _isSaving = true);
    try {
      await FirebaseFirestore.instance.collection('users').doc(_user!.uid).set({
        'name': _nameController.text,
        'age': int.tryParse(_ageController.text) ?? '',
        'location': _locationController.text,
        'imageUrl': _imageUrl,
        'email': _user!.email,
        'aadharNumber': _aadharNumber,
      }, SetOptions(merge: true));

      // Update ProfileData static variables
      ProfileData.userName = _nameController.text;
      ProfileData.userLocation = _locationController.text;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Profile saved!')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Save failed: $e')));
    } finally {
      setState(() => _isSaving = false);
    }
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => AuthScreen()),
      (route) => false,
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _locationController.dispose();
    super.dispose();
  }
}

// Add this widget at the end of the file or after SearchPage
class CandidateDetailPage extends StatelessWidget {
  final Map<String, dynamic> candidate;
  const CandidateDetailPage({super.key, required this.candidate});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(candidate['name'] ?? 'Candidate Details')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Party: ${candidate['party'] ?? '-'}',
              style: const TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 12),
            Text(
              'State: ${candidate['state'] ?? '-'}',
              style: const TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 12),
            Text(
              'Constituency: ${candidate['constituency'] ?? '-'}',
              style: const TextStyle(fontSize: 18),
            ),
          ],
        ),
      ),
    );
  }
}

// --- Candidate Firestore Search Page ---
class CandidateFirestoreSearchPage extends StatefulWidget {
  const CandidateFirestoreSearchPage({super.key});

  @override
  State<CandidateFirestoreSearchPage> createState() =>
      _CandidateFirestoreSearchPageState();
}

class _CandidateFirestoreSearchPageState
    extends State<CandidateFirestoreSearchPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Search Candidates')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                labelText: 'Search by name',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream:
                  FirebaseFirestore.instance
                      .collection('candidates')
                      .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                final docs = snapshot.data?.docs ?? [];
                final filtered =
                    docs.where((doc) {
                      final data = doc.data() as Map<String, dynamic>?;
                      if (data == null) return false;
                      final name =
                          (data['name'] ?? '').toString().toLowerCase();
                      return _searchQuery.isEmpty ||
                          name.contains(_searchQuery);
                    }).toList();
                if (filtered.isEmpty) {
                  return const Center(child: Text('No candidates found.'));
                }
                return ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final data = filtered[index].data() as Map<String, dynamic>;
                    return ListTile(
                      title: Text(data['name'] ?? 'No name'),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (context) =>
                                    CandidateDetailPage(candidate: data),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class FirestoreCandidateSearch extends StatefulWidget {
  const FirestoreCandidateSearch({super.key});

  @override
  State<FirestoreCandidateSearch> createState() =>
      _FirestoreCandidateSearchState();
}

class _FirestoreCandidateSearchState extends State<FirestoreCandidateSearch> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Candidate Search')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search candidates by name...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 14,
                  horizontal: 20,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream:
                    FirebaseFirestore.instance
                        .collection('candidates')
                        .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text('Error: 24{snapshot.error}'));
                  }
                  final docs = snapshot.data?.docs ?? [];
                  final filtered =
                      docs.where((doc) {
                        final data = doc.data() as Map<String, dynamic>?;
                        if (data == null) return false;
                        final name =
                            (data['name'] ?? '').toString().toLowerCase();
                        return _searchQuery.isEmpty ||
                            name.contains(_searchQuery);
                      }).toList();
                  if (filtered.isEmpty) {
                    return const Center(child: Text('No candidates found.'));
                  }
                  return ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final data =
                          filtered[index].data() as Map<String, dynamic>?;
                      if (data == null) return const SizedBox.shrink();
                      return Card(
                        margin: const EdgeInsets.symmetric(
                          vertical: 6.0,
                          horizontal: 2.0,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 2,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                data['name'] ?? '-',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text('Party: \\${data['party'] ?? '-'}'),
                              Text('State: \\${data['state'] ?? '-'}'),
                              Text(
                                'Constituency: \\${data['constituency'] ?? '-'}',
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
