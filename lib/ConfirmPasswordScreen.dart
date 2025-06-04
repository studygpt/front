import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class ConfirmPasswordScreen extends StatefulWidget {
  final String email; // Add email parameter to receive from ForgetPasswordScreen

  const ConfirmPasswordScreen({Key? key, required this.email}) : super(key: key);

  @override
  _ConfirmPasswordScreenState createState() => _ConfirmPasswordScreenState();
}

class _ConfirmPasswordScreenState extends State<ConfirmPasswordScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _formAnimation;
  late Animation<double> _buttonScaleAnimation;

  final _formKey = GlobalKey<FormState>();
  final TextEditingController _tokenController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FocusNode _tokenFocusNode = FocusNode();
  final FocusNode _passwordFocusNode = FocusNode();
  Color _buttonColor = const Color(0xFF007BFF);
  Color _backToLoginColor = const Color(0xFF007BFF);
  bool _obscurePassword = true;
  bool _isLoading = false;

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
    _tokenFocusNode.addListener(() => setState(() {}));
    _passwordFocusNode.addListener(() => setState(() {}));
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

  void _onBackToLoginEnter(PointerEvent details) {
    setState(() {
      _backToLoginColor = const Color(0xFF0056b3);
    });
  }

  void _onBackToLoginExit(PointerEvent details) {
    setState(() {
      _backToLoginColor = const Color(0xFF007BFF);
    });
  }

  Future<void> _onConfirmTap() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      String token = _tokenController.text;
      String newPassword = _passwordController.text;
      const String apiUrl = 'http://56.228.80.139/api/account/reset-password/';

      try {
        final response = await http.post(
          Uri.parse(apiUrl),
          headers: {
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'email': widget.email,
            'otp': token,
            'new_password': newPassword,
          }),
        );

        if (response.statusCode == 200 || response.statusCode == 201) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Password successfully reset!'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );

          // Navigate back to login after a short delay
          await Future.delayed(const Duration(seconds: 2));
          Navigator.pop(context);
        } else {
          // Handle API error
          final errorMessage = jsonDecode(response.body)['message'] ?? 'Failed to reset password';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        }
      } catch (e) {
        // Handle network or other errors
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Color _getLabelColor(FocusNode focusNode) {
    return focusNode.hasFocus ? const Color(0xFF007BFF) : Colors.grey;
  }

  @override
  void dispose() {
    _animationController.dispose();
    _tokenController.dispose();
    _passwordController.dispose();
    _tokenFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            height: MediaQuery.of(context).size.height * 0.6,
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
                        'Confirm New Password',
                        style: TextStyle(
                          fontSize: 49,
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
                height: MediaQuery.of(context).size.height * 0.6,
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
                          const Text(
                            'Enter your reset token and new password',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.normal,
                              color: Colors.black87,
                              shadows: [
                                Shadow(
                                  color: Colors.black12,
                                  offset: Offset(1, 1),
                                  blurRadius: 2,
                                ),
                              ],
                            ),
                            textAlign: TextAlign.left,
                          ),
                          const SizedBox(height: 30),
                          TextFormField(
                            controller: _tokenController,
                            focusNode: _tokenFocusNode,
                            keyboardType: TextInputType.text,
                            cursorColor: const Color(0xFF007BFF),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter the reset token';
                              }
                              return null;
                            },
                            decoration: InputDecoration(
                              labelText: 'Reset Token',
                              hintText: 'Enter your reset token',
                              prefixIcon: const Icon(Icons.vpn_key, color: Colors.grey),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(15),
                                borderSide: const BorderSide(color: Colors.grey),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(15),
                                borderSide: BorderSide(color: Colors.grey.shade300),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(15),
                                borderSide: const BorderSide(color: Color(0xFF007BFF), width: 2.0),
                              ),
                              filled: true,
                              fillColor: Colors.grey.shade50,
                              labelStyle: TextStyle(color: _getLabelColor(_tokenFocusNode)),
                              contentPadding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
                            ),
                            style: const TextStyle(color: Colors.black),
                          ),
                          const SizedBox(height: 20),
                          TextFormField(
                            controller: _passwordController,
                            focusNode: _passwordFocusNode,
                            obscureText: _obscurePassword,
                            cursorColor: const Color(0xFF007BFF),
                            validator: (value) {
                              if (value == null || value.length < 8) {
                                return 'Password must be at least 8 characters long';
                              }
                              return null;
                            },
                            decoration: InputDecoration(
                              labelText: 'New Password',
                              hintText: 'Enter your new password',
                              prefixIcon: const Icon(Icons.lock, color: Colors.grey),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword ? Icons.visibility : Icons.visibility_off,
                                  color: Colors.grey,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(15),
                                borderSide: const BorderSide(color: Colors.grey),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(15),
                                borderSide: BorderSide(color: Colors.grey.shade300),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(15),
                                borderSide: const BorderSide(color: Color(0xFF007BFF), width: 2.0),
                              ),
                              filled: true,
                              fillColor: Colors.grey.shade50,
                              labelStyle: TextStyle(color: _getLabelColor(_passwordFocusNode)),
                              contentPadding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
                            ),
                            style: const TextStyle(color: Colors.black),
                          ),
                          const SizedBox(height: 30),
                          Center(
                            child: MouseRegion(
                              onEnter: _onEnter,
                              onExit: _onExit,
                              child: GestureDetector(
                                onTap: _isLoading ? null : _onConfirmTap,
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
                                    child: Center(
                                      child: _isLoading
                                          ? const CircularProgressIndicator(
                                        color: Colors.white,
                                      )
                                          : const Text(
                                        'CONFIRM',
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
                          const SizedBox(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: [
                              const Text(
                                "Remember your password? ",
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black54,
                                ),
                              ),
                              MouseRegion(
                                onEnter: _onBackToLoginEnter,
                                onExit: _onBackToLoginExit,
                                child: GestureDetector(
                                  onTap: () => Navigator.pop(context),
                                  child: Text(
                                    "Sign in",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 17,
                                      color: _backToLoginColor,
                                    ),
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
              ),
            ),
          ),
        ],
      ),
    );
  }
}