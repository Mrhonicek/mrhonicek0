import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EditAccountInfo extends StatefulWidget {
  @override
  _EditAccountInfoState createState() => _EditAccountInfoState();
}

class _EditAccountInfoState extends State<EditAccountInfo> {
  final SupabaseClient supabase = Supabase.instance.client;
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController firstNameController = TextEditingController();
  final TextEditingController lastNameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController newPasswordController = TextEditingController();
  final TextEditingController confirmPasswordController =
      TextEditingController();

  bool _isObscuredNew = true;
  bool _isObscuredConfirm = true;
  bool _isLoading = false;

  // Password strength indicators
  bool _hasMinLength = false;
  bool _hasUppercase = false;
  bool _hasLowercase = false;
  bool _hasNumber = false;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
    newPasswordController.addListener(_checkPasswordStrength);
  }

  @override
  void dispose() {
    newPasswordController.removeListener(_checkPasswordStrength);
    usernameController.dispose();
    firstNameController.dispose();
    lastNameController.dispose();
    emailController.dispose();
    newPasswordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  /// Check password strength in real-time
  void _checkPasswordStrength() {
    final password = newPasswordController.text;
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
      return null; // Password change is optional
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

  Future<void> _fetchUserData() async {
    final user = supabase.auth.currentUser;
    if (user != null) {
      try {
        final response =
            await supabase.from('profiles').select().eq('id', user.id).single();

        setState(() {
          usernameController.text = response['username'] ?? '';
          firstNameController.text = response['first_name'] ?? '';
          lastNameController.text = response['last_name'] ?? '';
          emailController.text = user.email ?? '';
        });
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load profile data. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _updateUserInfo() async {
    // Validate password if it's being changed
    if (newPasswordController.text.isNotEmpty) {
      final passwordError = _validatePassword(newPasswordController.text);
      if (passwordError != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(passwordError),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      if (newPasswordController.text != confirmPasswordController.text) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Passwords do not match'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    setState(() {
      _isLoading = true;
    });

    final user = supabase.auth.currentUser;
    if (user != null) {
      try {
        // Update profile data
        await supabase.from('profiles').update({
          'username': usernameController.text,
          'first_name': firstNameController.text,
          'last_name': lastNameController.text,
        }).eq('id', user.id);

        // Update password if changed
        if (newPasswordController.text.isNotEmpty) {
          await supabase.auth.updateUser(
            UserAttributes(password: newPasswordController.text),
          );
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Profile updated successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );

        // Clear password fields after successful update
        newPasswordController.clear();
        confirmPasswordController.clear();
        setState(() {
          _hasMinLength = false;
          _hasUppercase = false;
          _hasLowercase = false;
          _hasNumber = false;
        });
      } catch (error) {
        String errorMessage = 'Failed to update profile. Please try again.';

        if (error.toString().contains('duplicate key value')) {
          errorMessage = 'Username already exists. Please choose another.';
        } else if (error.toString().contains('weak_password')) {
          errorMessage = 'Password does not meet requirements.';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 4),
          ),
        );
      }
    }

    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 220, 242, 255),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Edit Account Information',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1565C0),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Username Field
            TextFormField(
              controller: usernameController,
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
              controller: firstNameController,
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
              controller: lastNameController,
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

            // Email Field (disabled)
            TextFormField(
              controller: emailController,
              decoration: InputDecoration(
                labelText: 'Email Address',
                prefixIcon: const Icon(Icons.email_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey.shade200,
              ),
              enabled: false,
            ),
            const SizedBox(height: 24),

            // Password Change Section
            const Text(
              'Change Password (optional)',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1565C0),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Leave blank to keep current password',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 16),

            // New Password Field
            TextFormField(
              controller: newPasswordController,
              decoration: InputDecoration(
                labelText: 'New Password',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(
                    _isObscuredNew ? Icons.visibility : Icons.visibility_off,
                  ),
                  onPressed: () {
                    setState(() {
                      _isObscuredNew = !_isObscuredNew;
                    });
                  },
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
              obscureText: _isObscuredNew,
              validator: _validatePassword,
            ),

            // Show password requirements when typing
            if (newPasswordController.text.isNotEmpty)
              _buildPasswordStrengthIndicator(),

            const SizedBox(height: 16),

            // Confirm Password Field
            TextFormField(
              controller: confirmPasswordController,
              decoration: InputDecoration(
                labelText: 'Confirm New Password',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(
                    _isObscuredConfirm
                        ? Icons.visibility
                        : Icons.visibility_off,
                  ),
                  onPressed: () {
                    setState(() {
                      _isObscuredConfirm = !_isObscuredConfirm;
                    });
                  },
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
              obscureText: _isObscuredConfirm,
              validator: (value) {
                if (newPasswordController.text.isNotEmpty &&
                    (value == null || value.isEmpty)) {
                  return 'Please confirm your new password';
                }
                if (value != newPasswordController.text) {
                  return 'Passwords do not match';
                }
                return null;
              },
            ),
            const SizedBox(height: 32),

            // Save Button
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
                      onPressed: _updateUserInfo,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1565C0),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                      child: const Text(
                        'Save Changes',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
