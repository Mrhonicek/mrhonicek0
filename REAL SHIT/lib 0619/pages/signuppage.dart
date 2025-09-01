import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({Key? key}) : super(key: key);

  @override
  _SignUpPageState createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final SupabaseClient supabase = Supabase.instance.client;

  final _formKey = GlobalKey<FormState>();
  final _userNameController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  bool _passwordVisible = false;
  bool _confirmPasswordVisible = false;

  // Password strength indicators
  bool _hasMinLength = false;
  bool _hasUppercase = false;
  bool _hasLowercase = false;
  bool _hasNumber = false;

  @override
  void initState() {
    super.initState();
    // Listen to password changes for real-time validation
    _passwordController.addListener(_checkPasswordStrength);
  }

  @override
  void dispose() {
    _passwordController.removeListener(_checkPasswordStrength);
    _userNameController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  /// Check password strength in real-time
  void _checkPasswordStrength() {
    final password = _passwordController.text;
    setState(() {
      _hasMinLength = password.length >= 8;
      _hasUppercase = password.contains(RegExp(r'[A-Z]'));
      _hasLowercase = password.contains(RegExp(r'[a-z]'));
      _hasNumber = password.contains(RegExp(r'[0-9]'));
    });
  }

  /// Validate password requirements
  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }

    List<String> errors = [];

    if (value.length < 8) {
      errors.add('at least 8 characters');
    }
    if (!value.contains(RegExp(r'[A-Z]'))) {
      errors.add('one uppercase letter');
    }
    if (!value.contains(RegExp(r'[a-z]'))) {
      errors.add('one lowercase letter');
    }
    if (!value.contains(RegExp(r'[0-9]'))) {
      errors.add('one number');
    }

    if (errors.isNotEmpty) {
      return 'Password must contain ${errors.join(', ')}';
    }

    return null;
  }

  /// Password strength indicator widget
  Widget _buildPasswordStrengthIndicator() {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Password Requirements:',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          const SizedBox(height: 8),
          _buildRequirementRow('At least 8 characters', _hasMinLength),
          _buildRequirementRow('One uppercase letter (A-Z)', _hasUppercase),
          _buildRequirementRow('One lowercase letter (a-z)', _hasLowercase),
          _buildRequirementRow('One number (0-9)', _hasNumber),
        ],
      ),
    );
  }

  /// Individual requirement row
  Widget _buildRequirementRow(String requirement, bool isMet) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(
            isMet ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 16,
            color: isMet ? Colors.green : Colors.grey,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              requirement,
              style: TextStyle(
                fontSize: 13,
                color: isMet ? Colors.green.shade700 : Colors.grey.shade600,
                fontWeight: isMet ? FontWeight.w500 : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Fetch and store OneSignal Player ID
  Future<void> storeOneSignalPlayerID() async {
    try {
      final String? playerID = OneSignal.User.pushSubscription.id;

      if (playerID != null) {
        print('🔑 OneSignal Player ID: $playerID');

        final user = supabase.auth.currentUser;
        if (user != null) {
          await supabase
              .from('profiles')
              .update({'onesignal_player_id': playerID}).eq('id', user.id);
          print('✅ OneSignal Player ID stored in Supabase');
        } else {
          print('⚠️ No authenticated user found in Supabase');
        }
      } else {
        print('❌ Failed to retrieve OneSignal Player ID');
      }
    } catch (e) {
      print("❌ Error storing OneSignal Player ID: $e");
    }
  }

  /// Sign-up function - Modified to skip email confirmation
  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    final userName = _userNameController.text.trim();
    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    try {
      print("🚀 Attempting to sign up user: $email");

      // Modified: Add emailRedirectTo: null to skip email confirmation
      final response = await supabase.auth.signUp(
        email: email,
        password: password,
        data: {'display_name': userName},
        emailRedirectTo: null, // This disables email confirmation requirement
      );

      // Check if user was created successfully
      if (response.user != null) {
        print("✅ User signed up successfully: ${response.user!.id}");

        // Get OneSignal Player ID (if available)
        final String? playerId = OneSignal.User.pushSubscription.id;
        print("🔔 OneSignal Player ID: ${playerId ?? 'Not available'}");

        // Insert user profile into Supabase
        await supabase.from('profiles').insert({
          'id': response.user!.id,
          'username': userName,
          'first_name': firstName,
          'last_name': lastName,
          'email': email,
          'onesignal_player_id': playerId, // Store OneSignal Player ID
        });

        print("✅ Profile inserted into Supabase");

        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('🎉 Account created successfully! You can now login'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ));

        // Clear form fields
        _userNameController.clear();
        _firstNameController.clear();
        _lastNameController.clear();
        _emailController.clear();
        _passwordController.clear();
        _confirmPasswordController.clear();

        // Switch to login tab
        DefaultTabController.of(context)?.animateTo(0);
      } else {
        print("❌ Signup failed: No user object returned.");
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Sign-up failed. Please try again.'),
          backgroundColor: Colors.red,
        ));
      }
    } catch (e) {
      print("❌ Sign-up error: $e");
      String errorMessage = 'Sign-up failed. Please try again.';

      // Handle common Supabase auth errors
      if (e.toString().contains('already_registered') ||
          e.toString().contains('User already registered')) {
        errorMessage = 'An account with this email already exists.';
      } else if (e.toString().contains('invalid_email')) {
        errorMessage = 'Please enter a valid email address.';
      } else if (e.toString().contains('weak_password')) {
        errorMessage = 'Password does not meet requirements.';
      }

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(errorMessage),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
      ));
    }

    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 220, 242, 255),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Create Account',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1565C0),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'No email verification required',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 32),

                // Username Field
                TextFormField(
                  controller: _userNameController,
                  decoration: InputDecoration(
                    labelText: 'Username',
                    prefixIcon: const Icon(Icons.person_outline),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Username is required';
                    }
                    if (value.length < 3) {
                      return 'Username must be at least 3 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // First Name Field
                TextFormField(
                  controller: _firstNameController,
                  decoration: InputDecoration(
                    labelText: 'First Name',
                    prefixIcon: const Icon(Icons.badge_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  validator: (value) => value == null || value.isEmpty
                      ? 'First name is required'
                      : null,
                ),
                const SizedBox(height: 16),

                // Last Name Field
                TextFormField(
                  controller: _lastNameController,
                  decoration: InputDecoration(
                    labelText: 'Last Name',
                    prefixIcon: const Icon(Icons.badge_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  validator: (value) => value == null || value.isEmpty
                      ? 'Last name is required'
                      : null,
                ),
                const SizedBox(height: 16),

                // Email Field
                TextFormField(
                  controller: _emailController,
                  decoration: InputDecoration(
                    labelText: 'Email Address',
                    prefixIcon: const Icon(Icons.email_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Email address is required';
                    }
                    final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
                    if (!emailRegex.hasMatch(value)) {
                      return 'Please enter a valid email address';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Password Field
                TextFormField(
                  controller: _passwordController,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _passwordVisible
                            ? Icons.visibility
                            : Icons.visibility_off,
                      ),
                      onPressed: () {
                        setState(() {
                          _passwordVisible = !_passwordVisible;
                        });
                      },
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  obscureText: !_passwordVisible,
                  validator: _validatePassword,
                ),

                // Show password requirements when typing
                if (_passwordController.text.isNotEmpty)
                  _buildPasswordStrengthIndicator(),

                const SizedBox(height: 16),

                // Confirm Password Field
                TextFormField(
                  controller: _confirmPasswordController,
                  decoration: InputDecoration(
                    labelText: 'Confirm Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _confirmPasswordVisible
                            ? Icons.visibility
                            : Icons.visibility_off,
                      ),
                      onPressed: () {
                        setState(() {
                          _confirmPasswordVisible = !_confirmPasswordVisible;
                        });
                      },
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  obscureText: !_confirmPasswordVisible,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please confirm your password';
                    }
                    if (value != _passwordController.text) {
                      return 'Passwords do not match';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 32),

                // Sign Up Button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: _isLoading
                      ? ElevatedButton(
                          onPressed: null,
                          style: ElevatedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const CircularProgressIndicator(),
                        )
                      : ElevatedButton(
                          onPressed: _signUp,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1565C0),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 2,
                          ),
                          child: const Text(
                            'Create Account',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                ),
                const SizedBox(height: 16),

                // Login prompt
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Already have an account? ',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                    GestureDetector(
                      onTap: () {
                        DefaultTabController.of(context)?.animateTo(0);
                      },
                      child: const Text(
                        'Sign In',
                        style: TextStyle(
                          color: Color(0xFF1565C0),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
