import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ResetPasswordPage extends StatefulWidget {
  final String email;
  final String verificationToken;

  const ResetPasswordPage({
    Key? key,
    required this.email,
    required this.verificationToken,
  }) : super(key: key);

  @override
  _ResetPasswordPageState createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final SupabaseClient supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  bool _isLoading = false;
  bool _passwordVisible = false;
  bool _confirmPasswordVisible = false;
  String _loadingMessage = '';

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
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

  /// Validates password strength
  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }

    if (value.length < 8) {
      return 'Password must be at least 8 characters long';
    }

    if (!RegExp(r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)').hasMatch(value)) {
      return 'Password must contain uppercase, lowercase, and number';
    }

    return null;
  }

  /// Validates password confirmation
  String? _validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please confirm your password';
    }

    if (value != _passwordController.text) {
      return 'Passwords do not match';
    }

    return null;
  }

  /// Updates the user's password using the reset token
  Future<void> _updatePassword() async {
    if (!_formKey.currentState!.validate()) return;

    _setLoading(true, 'Updating your password...');

    try {
      // Method 1: Use verifyOtp with password update
      final response = await supabase.auth.verifyOTP(
        email: widget.email,
        token: widget.verificationToken,
        type: OtpType.recovery,
      );

      if (response.user != null) {
        // Now that we have a session, update the password
        await supabase.auth.updateUser(
          UserAttributes(password: _passwordController.text.trim()),
        );

        _showSnackBar('Password updated successfully!', Colors.green);

        // Navigate back to login page
        if (mounted) {
          Navigator.of(context).popUntil((route) => route.isFirst);
          _showSnackBar('Please sign in with your new password.', Colors.blue);
        }
      }
    } on AuthException catch (e) {
      String errorMessage = 'Failed to update password. Please try again.';

      if (e.message.contains('Invalid recovery token') ||
          e.message.contains('Token has expired')) {
        errorMessage =
            'Reset link has expired. Please request a new password reset.';
      } else if (e.message.contains('weak_password')) {
        errorMessage =
            'Password is too weak. Please choose a stronger password.';
      } else if (e.message.contains('same_password')) {
        errorMessage =
            'New password must be different from your current password.';
      }

      _showSnackBar(errorMessage, Colors.red, duration: 4);
      print('❌ Password update error: ${e.message}');
    } catch (e) {
      _showSnackBar(
          'An unexpected error occurred. Please try again.', Colors.red,
          duration: 4);
      print('❌ Unexpected error: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Alternative method: Use session from URL parameters if available
  Future<void> _updatePasswordWithSession() async {
    if (!_formKey.currentState!.validate()) return;

    _setLoading(true, 'Updating your password...');

    try {
      // If you have access token and refresh token from URL parameters,
      // you can set the session first
      // This assumes you extract these from the reset URL

      // Example:
      // await supabase.auth.setSession(accessToken, refreshToken);

      // Then update password
      final response = await supabase.auth.updateUser(
        UserAttributes(password: _passwordController.text.trim()),
      );

      if (response.user != null) {
        _showSnackBar('Password updated successfully!', Colors.green);

        // Sign out to clear the temporary session
        await supabase.auth.signOut();

        // Navigate back to login page
        if (mounted) {
          Navigator.of(context).popUntil((route) => route.isFirst);
          _showSnackBar('Please sign in with your new password.', Colors.blue);
        }
      }
    } catch (e) {
      String errorMessage = 'Failed to update password. Please try again.';

      if (e.toString().contains('weak_password')) {
        errorMessage =
            'Password is too weak. Please choose a stronger password.';
      } else if (e.toString().contains('same_password')) {
        errorMessage =
            'New password must be different from your current password.';
      }

      _showSnackBar(errorMessage, Colors.red, duration: 4);
      print('❌ Password update error: $e');
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
          'Reset Password',
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
                _buildKeyIcon(),
                const SizedBox(height: 32),
                _buildHeaderText(),
                const SizedBox(height: 32),
                _buildPasswordForm(),
                const SizedBox(height: 32),
                _buildUpdateButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Builds the key icon
  Widget _buildKeyIcon() {
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
        Icons.vpn_key,
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
          'Create New Password',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1565C0),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Your new password must be different from your previous password.',
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey.shade600,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue.shade200),
          ),
          child: Row(
            children: [
              const Icon(Icons.email_outlined, color: Color(0xFF1565C0)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.email,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF1565C0),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Builds the password form
  Widget _buildPasswordForm() {
    return Column(
      children: [
        TextFormField(
          controller: _passwordController,
          decoration: InputDecoration(
            labelText: 'New Password',
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
          validator: _validatePassword,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _confirmPasswordController,
          decoration: InputDecoration(
            labelText: 'Confirm New Password',
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
          enabled: !_isLoading,
          validator: _validateConfirmPassword,
        ),
        const SizedBox(height: 16),
        _buildPasswordRequirements(),
      ],
    );
  }

  /// Builds password requirements info
  Widget _buildPasswordRequirements() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Password Requirements:',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          _buildRequirementItem('At least 8 characters long'),
          _buildRequirementItem('Contains uppercase letter (A-Z)'),
          _buildRequirementItem('Contains lowercase letter (a-z)'),
          _buildRequirementItem('Contains at least one number (0-9)'),
        ],
      ),
    );
  }

  /// Builds individual requirement item
  Widget _buildRequirementItem(String requirement) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 16,
            color: Colors.grey.shade500,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              requirement,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Builds update button
  Widget _buildUpdateButton() {
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
        onPressed: _updatePassword,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1565C0),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
        ),
        child: const Text(
          'Update Password',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
