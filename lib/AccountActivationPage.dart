import 'dart:io';

import 'package:flutter/material.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
class AccountActivationPage extends StatefulWidget {
  final String email;
  const AccountActivationPage({Key? key, required this.email}) : super(key: key);

  @override
  _AccountActivationPageState createState() => _AccountActivationPageState();
}

class _AccountActivationPageState extends State<AccountActivationPage>
    with SingleTickerProviderStateMixin {
  final TextEditingController _otpController = TextEditingController();
  final FocusNode _otpFocusNode = FocusNode();
  bool _isLoading = false;
  Color _buttonColor = const Color(0xFF007BFF);
  final _formKey = GlobalKey<FormState>();

  late AnimationController _animationController;
  late Animation<double> _formAnimation;
  late Animation<double> _buttonScaleAnimation;

  // Define API base URL (use HTTPS for security)
  static const String apiBaseUrl = 'http://56.228.80.139';

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _formAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    );

    _buttonScaleAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );

    _animationController.forward();
    _otpFocusNode.addListener(() => setState(() {}));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _animationController.reset();
    _animationController.forward();
  }

  void _onEnter(PointerEvent details) {
    setState(() {
      _buttonColor = const Color(0xFF0056b3);
    });
  }

  void _onExit(PointerEvent details) {
    setState(() {
      _buttonColor = const Color(0xFF007BFF);
    });
  }

  Future<void> _activateAccount() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      try {
        final response = await http
            .post(
          Uri.parse('$apiBaseUrl/api/account/confirm-email/'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'email': widget.email.trim(),
            'otp': _otpController.text.trim(),
          }),
        )
            .timeout(const Duration(seconds: 15));

        if (response.statusCode == 200) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('is_active', true);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Account activated successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context, true); // Return true to trigger refresh
        } else {
          final errorData = jsonDecode(response.body);
          String errorMessage = 'Activation failed. Please try again.';
          if (errorData is Map<String, dynamic>) {
            errorMessage = errorData['detail'] ??
                errorData['non_field_errors']?.first ??
                errorData['email']?.first ??
                errorData['otp']?.first ??
                'Error: ${response.body}';
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage),
              backgroundColor: Colors.red,
            ),
          );
        }
      } on TimeoutException {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Request timed out. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      } on SocketException {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No internet connection. Please check your network.'),
            backgroundColor: Colors.red,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unexpected error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  Color _getLabelColor(FocusNode focusNode) {
    return focusNode.hasFocus ? const Color(0xFF007BFF) : Colors.grey;
  }

  @override
  void dispose() {
    _animationController.dispose();
    _otpController.dispose();
    _otpFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            height: MediaQuery.of(context).size.height * 0.4,
            width: double.infinity,
            decoration: const BoxDecoration(
              color: Color(0xFF007BFF),
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: Opacity(
                    opacity: 0.1,
                    child: Image.asset(
                      'assets/background_pattern.png',
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 60.0, left: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 20),
                      const Text(
                        'Activate Your Account',
                        style: TextStyle(
                          fontSize: 36,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          shadows: [
                            Shadow(
                              color: Colors.black26,
                              offset: Offset(2, 2),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Enter the OTP sent to ${widget.email}',
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 1),
                end: Offset.zero,
              ).animate(_formAnimation),
              child: Container(
                height: MediaQuery.of(context).size.height * 0.65,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(40),
                    topRight: Radius.circular(40),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 20,
                      offset: Offset(0, -5),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.only(top: 30, bottom: 20),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 20),
                          Text(
                            'Account Activation',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Please enter the OTP to activate your account and access all features.',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.black54,
                            ),
                          ),
                          const SizedBox(height: 20),
                          TextFormField(
                            controller: _otpController,
                            focusNode: _otpFocusNode,
                            keyboardType: TextInputType.number,
                            cursorColor: const Color(0xFF007BFF),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter the OTP';
                              }
                              if (!RegExp(r'^\d{4,6}$').hasMatch(value)) {
                                return 'Enter a valid OTP (4-6 digits)';
                              }
                              return null;
                            },
                            decoration: InputDecoration(
                              labelText: 'OTP',
                              hintText: 'Enter OTP',
                              prefixIcon: Icon(Icons.lock, color: Colors.grey),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(15),
                                borderSide: BorderSide(color: Colors.grey),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(15),
                                borderSide: BorderSide(color: Colors.grey.shade300),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(15),
                                borderSide: BorderSide(
                                    color: Color(0xFF007BFF), width: 2.0),
                              ),
                              filled: true,
                              fillColor: Colors.grey.shade50,
                              labelStyle: TextStyle(color: _getLabelColor(_otpFocusNode)),
                              contentPadding:
                              EdgeInsets.symmetric(vertical: 15, horizontal: 20),
                            ),
                            style: TextStyle(color: Colors.black),
                          ),
                          const SizedBox(height: 30),
                          Center(
                            child: _isLoading
                                ? CircularProgressIndicator()
                                : MouseRegion(
                              onEnter: _onEnter,
                              onExit: _onExit,
                              child: GestureDetector(
                                onTap: _activateAccount,
                                child: ScaleTransition(
                                  scale: _buttonScaleAnimation,
                                  child: Container(
                                    height: 55,
                                    width: 300,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(30),
                                      gradient: LinearGradient(
                                        colors: [
                                          _buttonColor,
                                          _buttonColor.withOpacity(0.8),
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: _buttonColor.withOpacity(0.4),
                                          blurRadius: 8,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: const Center(
                                      child: Text(
                                        'ACTIVATE ACCOUNT',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 20,
                                          color: Colors.white,
                                          letterSpacing: 1.2,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}