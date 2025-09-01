import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/services.dart';
import 'otpverificationpage.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({Key? key}) : super(key: key);

  @override
  _ForgotPasswordPageState createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final SupabaseClient supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();

  bool _isLoading = false;
  bool _captchaCompleted = false;
  String _loadingMessage = '';

  @override
  void dispose() {
    _emailController.dispose();
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

  /// Simulates CAPTCHA completion (replace with actual reCAPTCHA implementation)
  void _completeCaptcha() {
    // In a real implementation, you would integrate with Google reCAPTCHA
    // For now, we'll simulate it with a simple dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('CAPTCHA Verification'),
        content: const Text(
            'Please verify that you are human by completing this simple task:\n\nWhat is 5 + 3?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              // Simple verification - in real app, use proper reCAPTCHA
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Enter Answer'),
                  content: TextField(
                    keyboardType: TextInputType.number,
                    onSubmitted: (value) {
                      if (value == '8') {
                        setState(() {
                          _captchaCompleted = true;
                        });
                        Navigator.pop(context);
                        Navigator.pop(context);
                        _showSnackBar(
                            'CAPTCHA completed successfully!', Colors.green);
                      } else {
                        _showSnackBar(
                            'Incorrect answer. Please try again.', Colors.red);
                      }
                    },
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                  ],
                ),
              );
            },
            child: const Text('Verify'),
          ),
        ],
      ),
    );
  }

  /// Sends password reset OTP
  Future<void> _sendResetOTP() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_captchaCompleted) {
      _showSnackBar(
          'Please complete the CAPTCHA verification first.', Colors.orange);
      return;
    }

    _setLoading(true, 'Sending verification code...');

    try {
      final email = _emailController.text.trim();

      // Check if email exists in the database
      final existingUser = await supabase
          .from('profiles')
          .select('email')
          .eq('email', email)
          .maybeSingle();

      if (existingUser == null) {
        _showSnackBar('No account found with this email address.', Colors.red);
        return;
      }

      // Send password reset email with OTP
      await supabase.auth.resetPasswordForEmail(
        email,
        redirectTo: 'io.supabase.flutter://reset-callback',
      );

      _showSnackBar('Verification code sent to your email!', Colors.green);

      // Navigate to OTP verification page
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => OTPVerificationPage(email: email),
          ),
        );
      }
    } catch (e) {
      String errorMessage =
          'Failed to send verification code. Please try again.';

      if (e.toString().contains('rate_limit')) {
        errorMessage = 'Too many requests. Please wait before trying again.';
      } else if (e.toString().contains('invalid_email')) {
        errorMessage = 'Please enter a valid email address.';
      }

      _showSnackBar(errorMessage, Colors.red, duration: 4);
      print('❌ Reset password error: $e');
    } finally {
      _setLoading(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 220, 242, 255),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1565C0)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Forgot Password',
          style: TextStyle(
            color: Color(0xFF1565C0),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildLockIcon(),
                const SizedBox(height: 32),
                _buildHeaderText(),
                const SizedBox(height: 32),
                _buildEmailForm(),
                const SizedBox(height: 16),
                _buildCaptchaSection(),
                const SizedBox(height: 32),
                _buildSendButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Builds the lock icon
  Widget _buildLockIcon() {
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
        Icons.lock_reset,
        size: 60,
        color: Colors.white,
      ),
    );
  }

  /// Builds header text
  Widget _buildHeaderText() {
    return Column(
      children: [
        const Text(
          'Reset Password',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1565C0),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Enter your email address and we\'ll send you a verification code to reset your password.',
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey.shade600,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  /// Builds the email form
  Widget _buildEmailForm() {
    return TextFormField(
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
    );
  }

  /// Builds CAPTCHA section
  Widget _buildCaptchaSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                _captchaCompleted ? Icons.check_circle : Icons.security,
                color: _captchaCompleted ? Colors.green : Colors.grey.shade600,
              ),
              const SizedBox(width: 8),
              Text(
                _captchaCompleted
                    ? 'CAPTCHA Verified'
                    : 'CAPTCHA Verification Required',
                style: TextStyle(
                  color:
                      _captchaCompleted ? Colors.green : Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          if (!_captchaCompleted) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _isLoading ? null : _completeCaptcha,
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('Complete CAPTCHA'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Builds send button
  Widget _buildSendButton() {
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

    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _sendResetOTP,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1565C0),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
        ),
        child: const Text(
          'Send Verification Code',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
