import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';
import 'reset_password_page.dart';

class OTPVerificationPage extends StatefulWidget {
  final String email;

  const OTPVerificationPage({Key? key, required this.email}) : super(key: key);

  @override
  _OTPVerificationPageState createState() => _OTPVerificationPageState();
}

class _OTPVerificationPageState extends State<OTPVerificationPage> {
  final SupabaseClient supabase = Supabase.instance.client;
  final List<TextEditingController> _otpControllers =
      List.generate(6, (index) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (index) => FocusNode());

  bool _isLoading = false;
  bool _canResend = false;
  int _resendCountdown = 60;
  Timer? _timer;
  String _loadingMessage = '';

  @override
  void initState() {
    super.initState();
    _startResendTimer();
  }

  @override
  void dispose() {
    for (var controller in _otpControllers) {
      controller.dispose();
    }
    for (var focusNode in _focusNodes) {
      focusNode.dispose();
    }
    _timer?.cancel();
    super.dispose();
  }

  /// Starts the resend countdown timer
  void _startResendTimer() {
    _canResend = false;
    _resendCountdown = 60;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          if (_resendCountdown > 0) {
            _resendCountdown--;
          } else {
            _canResend = true;
            timer.cancel();
          }
        });
      }
    });
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

  /// Gets the complete OTP string
  String _getOTPString() {
    return _otpControllers.map((controller) => controller.text).join();
  }

  /// Verifies the entered OTP
  Future<void> _verifyOTP() async {
    final otpString = _getOTPString();

    if (otpString.length != 6) {
      _showSnackBar('Please enter the complete 6-digit verification code.',
          Colors.orange);
      return;
    }

    _setLoading(true, 'Verifying code...');

    try {
      // In Supabase, the OTP verification for password reset is handled differently
      // We'll use the token from the email link to verify the OTP
      // For this implementation, we'll simulate OTP verification
      // In a real scenario, you would need to handle the email link callback

      // Simulate OTP verification (replace with actual implementation)
      await Future.delayed(const Duration(seconds: 2));

      // For demonstration, we'll accept any 6-digit code
      // In production, you need proper OTP verification through Supabase
      if (otpString.length == 6) {
        _showSnackBar('Verification successful!', Colors.green);

        // Navigate to reset password page
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => ResetPasswordPage(
                email: widget.email,
                verificationToken: otpString, // In real app, use proper token
              ),
            ),
          );
        }
      } else {
        _showSnackBar(
            'Invalid verification code. Please try again.', Colors.red);
      }
    } catch (e) {
      _showSnackBar('Verification failed. Please try again.', Colors.red);
      print('❌ OTP verification error: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Resends the OTP
  Future<void> _resendOTP() async {
    if (!_canResend) return;

    _setLoading(true, 'Resending verification code...');

    try {
      // Resend the password reset email
      await supabase.auth.resetPasswordForEmail(
        widget.email,
        redirectTo: 'io.supabase.flutter://reset-callback',
      );

      _showSnackBar('Verification code sent again!', Colors.green);
      _startResendTimer();

      // Clear current OTP input
      for (var controller in _otpControllers) {
        controller.clear();
      }
      _focusNodes[0].requestFocus();
    } catch (e) {
      _showSnackBar('Failed to resend code. Please try again.', Colors.red);
      print('❌ Resend OTP error: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Handles OTP input change
  void _onOTPChanged(String value, int index) {
    if (value.length == 1 && index < 5) {
      _focusNodes[index + 1].requestFocus();
    } else if (value.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }

    // Auto-verify when all digits are entered
    if (index == 5 && value.isNotEmpty) {
      final otpString = _getOTPString();
      if (otpString.length == 6) {
        _verifyOTP();
      }
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
          'Verify Code',
          style: TextStyle(
            color: Color(0xFF1565C0),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildMessageIcon(),
              const SizedBox(height: 32),
              _buildHeaderText(),
              const SizedBox(height: 32),
              _buildOTPInput(),
              const SizedBox(height: 32),
              _buildVerifyButton(),
              const SizedBox(height: 24),
              _buildResendSection(),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds the message icon
  Widget _buildMessageIcon() {
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
        Icons.mark_email_read,
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
          'Verify Your Email',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1565C0),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'We\'ve sent a 6-digit verification code to:',
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey.shade600,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          widget.email,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1565C0),
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  /// Builds OTP input fields
  Widget _buildOTPInput() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List.generate(6, (index) {
        return SizedBox(
          width: 50,
          height: 60,
          child: TextFormField(
            controller: _otpControllers[index],
            focusNode: _focusNodes[index],
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            maxLength: 1,
            enabled: !_isLoading,
            decoration: InputDecoration(
              counterText: '',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: Color(0xFF1565C0), width: 2),
              ),
            ),
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1565C0),
            ),
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
            ],
            onChanged: (value) => _onOTPChanged(value, index),
            onTap: () {
              // Clear field when tapped
              _otpControllers[index].clear();
            },
          ),
        );
      }),
    );
  }

  /// Builds verify button
  Widget _buildVerifyButton() {
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
        onPressed: _verifyOTP,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1565C0),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
        ),
        child: const Text(
          'Verify Code',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  /// Builds resend section
  Widget _buildResendSection() {
    return Column(
      children: [
        Text(
          'Didn\'t receive the code?',
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        if (_canResend)
          TextButton(
            onPressed: _isLoading ? null : _resendOTP,
            child: const Text(
              'Resend Code',
              style: TextStyle(
                color: Color(0xFF1565C0),
                fontWeight: FontWeight.w600,
              ),
            ),
          )
        else
          Text(
            'Resend in $_resendCountdown seconds',
            style: TextStyle(
              color: Colors.grey.shade500,
              fontSize: 14,
            ),
          ),
      ],
    );
  }
}
