import 'package:flutter/material.dart';
import 'package:gismultiinstancetestingenvironment/main.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:gismultiinstancetestingenvironment/pages/newsfeed/newsfeed.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:gismultiinstancetestingenvironment/pages/inbox/inbox_page.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:gismultiinstancetestingenvironment/pages/forgotpasswordpage.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({Key? key}) : super(key: key);

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final SupabaseClient supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _passwordVisible = false;
  String _loadingMessage = '';

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// Sets loading state with optional message
  void _setLoading(bool loading, [String message = '']) {
    if (mounted) {
      setState(() {
        _isLoading = loading;
        _loadingMessage = message;
      });
    }
  }

  /// Displays a snackbar message
  void _showSnackBar(String message, Color color, {int duration = 3}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(
        children: [
          Icon(
            color == Colors.green ? Icons.check_circle : Icons.error,
            color: Colors.white,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(message)),
        ],
      ),
      backgroundColor: color,
      duration: Duration(seconds: duration),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ));
  }

  /// Stores the FCM token in Supabase after login
  Future<void> _storeFCMToken() async {
    try {
      FirebaseMessaging messaging = FirebaseMessaging.instance;
      String? token = await messaging.getToken();
      print('🔑 FCM Token: $token');

      final user = supabase.auth.currentUser;
      if (token != null && user != null) {
        await supabase
            .from('profiles')
            .update({'fcm_token': token}).eq('id', user.id);
        print('✅ FCM Token stored successfully for user: ${user.id}');
      } else {
        print('⚠️ No authenticated user found or FCM token is null.');
      }
    } catch (e) {
      print('❌ FCM Token Error: $e');
    }
  }

  /// Stores OneSignal Player ID
  Future<void> storeOneSignalPlayerID() async {
    try {
      final String? playerID = OneSignal.User.pushSubscription.id;
      if (playerID != null) {
        final user = supabase.auth.currentUser;
        if (user != null) {
          await supabase
              .from('profiles')
              .update({'onesignal_player_id': playerID}).eq('id', user.id);
          print('✅ OneSignal Player ID stored');
        }
      }
    } catch (e) {
      print("❌ Error storing OneSignal Player ID: $e");
    }
  }

  /// Checks if user account is accessible
  Future<bool> _checkUserAccess(String userId) async {
    try {
      final profile = await supabase
          .from('profiles')
          .select('canAccess')
          .eq('id', userId)
          .single();

      if (profile != null && profile['canAccess'] == 0) {
        _showSnackBar(
          'Your account has been disabled. Please contact an administrator.',
          Colors.red,
          duration: 5,
        );
        return false;
      }
      return true;
    } catch (e) {
      print('❌ Error checking user access: $e');
      return true; // Allow access if check fails
    }
  }

  /// Handles post-login setup
  Future<void> _handlePostLogin() async {
    try {
      await FirebaseMessaging.instance.requestPermission();
      await _storeFCMToken();
      await storeOneSignalPlayerID();

      // Listen for FCM token refresh
      FirebaseMessaging.instance.onTokenRefresh.listen((token) async {
        await _storeFCMToken();
      });
    } catch (e) {
      print('❌ Post-login setup error: $e');
    }
  }

  /// Handles regular email/password login
  Future<void> _logIn() async {
    if (!_formKey.currentState!.validate()) return;

    _setLoading(true, 'Signing you in...');

    try {
      final response = await supabase.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      if (response.user != null) {
        final userId = response.user!.id;

        // Check account access
        final hasAccess = await _checkUserAccess(userId);
        if (!hasAccess) return;

        await _handlePostLogin();
        _showSnackBar('Welcome! 🎉', Colors.green);
        _navigateToNewsFeed();
      }
    } catch (e) {
      String errorMessage = 'Sign in failed. Please try again.';

      if (e.toString().contains('invalid_credentials') ||
          e.toString().contains('Invalid login credentials')) {
        errorMessage =
            'Invalid email or password. Please check your credentials.';
      } else if (e.toString().contains('too_many_requests')) {
        errorMessage = 'Too many login attempts. Please try again later.';
      }
      // Removed email_not_confirmed check - users can login without email verification

      _showSnackBar(errorMessage, Colors.red, duration: 4);
      print('❌ Login error: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Handles Google sign-in
  Future<void> _signInWithGoogle() async {
    _setLoading(true, 'Connecting to Google...');

    try {
      await supabase.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: "io.supabase.flutter://login-callback",
      );

      _showSnackBar('Redirecting to Google Sign-In...', Colors.blue);

      // Listen for auth state changes
      supabase.auth.onAuthStateChange.listen((data) async {
        final session = data.session;
        final user = session?.user;

        if (user != null && mounted) {
          try {
            final email = user.email;
            final fullName = user.userMetadata?['full_name'] ?? 'Anonymous';
            final firstName = fullName.split(' ').first;
            final lastName = fullName.split(' ').length > 1
                ? fullName.split(' ').last
                : null;

            // Check if user exists in profiles
            final existingUser = await supabase
                .from('profiles')
                .select()
                .eq('id', user.id)
                .maybeSingle();

            if (existingUser == null) {
              // Insert new user
              await supabase.from('profiles').insert({
                'id': user.id,
                'email': email,
                'first_name': firstName,
                'last_name': lastName,
                'username': fullName,
              });
              print('✅ New Google user added to profiles.');
            }

            // Check account access
            final hasAccess = await _checkUserAccess(user.id);
            if (!hasAccess) return;

            await _handlePostLogin();
            _showSnackBar('Welcome! Signed in with Google 🎉', Colors.green);
            _navigateToNewsFeed();
          } catch (e) {
            _showSnackBar(
                'Error setting up Google account: ${e.toString()}', Colors.red);
            print('❌ Google setup error: $e');
          }
        }
      });
    } catch (e) {
      _showSnackBar('Google Sign-In failed: ${e.toString()}', Colors.red);
      print('❌ Google Sign-In error: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Handles anonymous login
  Future<void> _anonymousLogin() async {
    _setLoading(true, 'Creating guest session...');

    try {
      final response = await supabase.auth.signInAnonymously();

      if (response.user != null) {
        final userId = response.user!.id;

        // Check account access
        final hasAccess = await _checkUserAccess(userId);
        if (!hasAccess) return;

        await _handlePostLogin();
        _showSnackBar('Welcome, Guest! 👋', Colors.green);
        _navigateToNewsFeed();
      }
    } catch (e) {
      _showSnackBar('Anonymous sign-in failed: ${e.toString()}', Colors.red);
      print('❌ Anonymous login error: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Navigates to the NewsFeed after successful login
  void _navigateToNewsFeed() {
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => NewsFeed()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 220, 242, 255),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildProfileIcon(),
                const SizedBox(height: 32),
                _buildWelcomeText(),
                const SizedBox(height: 32),
                _buildLoginForm(),
                const SizedBox(height: 32),
                _buildLoginButtons(),
                const SizedBox(height: 24),
                //_buildSignUpPrompt(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Builds the profile icon with modern styling
  Widget _buildProfileIcon() {
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1565C0), Color(0xFF42A5F5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: const Icon(
        Icons.person,
        size: 60,
        color: Colors.white,
      ),
    );
  }

  /// Builds welcome text
  Widget _buildWelcomeText() {
    return Column(
      children: [
        const Text(
          'Welcome',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1565C0),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Sign in to continue',
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  /// Builds the login form with enhanced styling
  Widget _buildLoginForm() {
    return Column(
      children: [
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
          enabled: !_isLoading,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Email is required';
            }
            final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
            if (!emailRegex.hasMatch(value)) {
              return 'Please enter a valid email address';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _passwordController,
          decoration: InputDecoration(
            labelText: 'Password',
            prefixIcon: const Icon(Icons.lock_outline),
            suffixIcon: IconButton(
              icon: Icon(
                _passwordVisible ? Icons.visibility : Icons.visibility_off,
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
          enabled: !_isLoading,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Password is required';
            }
            return null;
          },
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: _isLoading
                ? null
                : () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ForgotPasswordPage(),
                      ),
                    );
                  },
            child: const Text(
              'Forgot Password?',
              style: TextStyle(color: Color(0xFF1565C0)),
            ),
          ),
        ),
      ],
    );
  }

  /// Builds login buttons with single loading state
  Widget _buildLoginButtons() {
    if (_isLoading) {
      return Column(
        children: [
          const CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1565C0)),
          ),
          const SizedBox(height: 16),
          Text(
            _loadingMessage,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 14,
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        // Primary Sign In Button
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: _logIn,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1565C0),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 2,
            ),
            child: const Text(
              'Sign In',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Divider
        Row(
          children: [
            Expanded(child: Divider(color: Colors.grey.shade400)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'or continue with',
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ),
            Expanded(child: Divider(color: Colors.grey.shade400)),
          ],
        ),
        const SizedBox(height: 16),

        // Google Sign In Button
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton.icon(
            onPressed: _signInWithGoogle,
            icon: const FaIcon(FontAwesomeIcons.google, size: 20),
            label: const Text(
              'Google',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black87,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey.shade300),
              ),
              elevation: 1,
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Anonymous Login Button
        /*SizedBox(
          width: double.infinity,
          height: 56,
          child: OutlinedButton.icon(
            onPressed: _anonymousLogin,
            icon: const Icon(Icons.person_outline, size: 20),
            label: const Text(
              'Annonymous Login',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF1565C0),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              side: const BorderSide(color: Color(0xFF1565C0)),
            ),
          ),
        ),*/
      ],
    );
  }

  /// Builds sign up prompt
  /*Widget _buildSignUpPrompt() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          "Don't have an account? ",
          style: TextStyle(color: Colors.grey.shade600),
        ),
        GestureDetector(
          onTap: _isLoading
              ? null
              : () {
                  DefaultTabController.of(context)?.animateTo(1);
                },
          child: Text(
            'Sign Up',
            style: TextStyle(
              color: _isLoading ? Colors.grey : const Color(0xFF1565C0),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }*/
}
