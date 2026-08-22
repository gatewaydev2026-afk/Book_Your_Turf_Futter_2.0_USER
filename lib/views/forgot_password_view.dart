// // forgot_password_view.dart - NO AUTO-LOGIN (User must click button)
//
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:get/get.dart';
// import '../view_models/auth_view_model.dart';
// import '../routes/app_routes.dart';
//
// class ForgotPasswordView extends StatefulWidget {
//   const ForgotPasswordView({Key? key}) : super(key: key);
//
//   // @override
//   State<ForgotPasswordView> createState() => _ForgotPasswordViewState();
// }
//
// class _ForgotPasswordViewState extends State<ForgotPasswordView> {
//   final _emailController = TextEditingController();
//   final _phoneController = TextEditingController();
//   String _verificationMethod = 'email';
//   final authVm = Get.find<AuthViewModel>();
//
//   final FocusNode _emailFocusNode = FocusNode();
//   final FocusNode _phoneFocusNode = FocusNode();
//
//   // Error messages
//   String? _emailError;
//   String? _phoneError;
//
//   @override
//   void initState() {
//     super.initState();
//     _emailController.addListener(_validateEmail);
//     _phoneController.addListener(_validatePhone);
//   }
//
//   void _validateEmail() {
//     setState(() {
//       final email = _emailController.text.trim();
//       if (email.isEmpty) {
//         _emailError = null;
//       } else {
//         final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
//         if (!emailRegex.hasMatch(email)) {
//           _emailError = 'Enter a valid email address';
//         } else {
//           _emailError = null;
//         }
//       }
//     });
//   }
//
//   void _validatePhone() {
//     setState(() {
//       final phone = _phoneController.text.trim();
//       if (phone.isEmpty) {
//         _phoneError = null;
//       } else if (phone.length != 10) {
//         _phoneError = 'Phone number must be exactly 10 digits';
//       } else if (!RegExp(r'^[0-9]+$').hasMatch(phone)) {
//         _phoneError = 'Only numbers allowed';
//       } else {
//         _phoneError = null;
//       }
//     });
//   }
//
//   @override
//   void dispose() {
//     _emailController.removeListener(_validateEmail);
//     _phoneController.removeListener(_validatePhone);
//     _emailController.dispose();
//     _phoneController.dispose();
//     _emailFocusNode.dispose();
//     _phoneFocusNode.dispose();
//     super.dispose();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Colors.transparent,
//       body: Container(
//         decoration: BoxDecoration(
//           gradient: LinearGradient(
//             begin: Alignment.topLeft,
//             end: Alignment.bottomRight,
//             colors: [Colors.green.shade800, Colors.green.shade400],
//           ),
//         ),
//         child: SafeArea(
//           child: Column(
//             children: [
//               // Back button row
//               Padding(
//                 padding: const EdgeInsets.all(16),
//                 child: Row(
//                   children: [
//                     IconButton(
//                       onPressed: () {
//                         Get.back();
//                       },
//                       icon: const Icon(Icons.arrow_back, color: Colors.white),
//                       style: IconButton.styleFrom(
//                         backgroundColor: Colors.white.withOpacity(0.2),
//                       ),
//                     ),
//                     const Spacer(),
//                   ],
//                 ),
//               ),
//               // Main content
//               Expanded(
//                 child: SingleChildScrollView(
//                   padding: const EdgeInsets.all(24),
//                   child: Column(
//                     mainAxisAlignment: MainAxisAlignment.center,
//                     children: [
//                       Container(
//                         padding: const EdgeInsets.all(20),
//                         decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
//                         child: Icon(Icons.lock_reset, size: 60, color: Colors.green.shade700),
//                       ),
//                       const SizedBox(height: 30),
//                       const Text(
//                         'Forgot Password?',
//                         style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
//                       ),
//                       const SizedBox(height: 10),
//                       AnimatedSwitcher(
//                         duration: const Duration(milliseconds: 300),
//                         child: Text(
//                           _verificationMethod == 'email'
//                               ? 'Enter your email to reset password'
//                               : 'Enter your 10-digit phone number to reset password',
//                           key: ValueKey(_verificationMethod),
//                           style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.8)),
//                         ),
//                       ),
//                       const SizedBox(height: 20),
//
//                       // Toggle buttons
//                       Container(
//                         padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
//                         decoration: BoxDecoration(
//                           color: Colors.white,
//                           borderRadius: BorderRadius.circular(30),
//                         ),
//                         child: Row(
//                           children: [
//                             Expanded(
//                               child: GestureDetector(
//                                 onTap: () {
//                                   setState(() {
//                                     _verificationMethod = 'email';
//                                   });
//                                   WidgetsBinding.instance.addPostFrameCallback((_) {
//                                     _emailFocusNode.requestFocus();
//                                   });
//                                 },
//                                 child: AnimatedContainer(
//                                   duration: const Duration(milliseconds: 200),
//                                   padding: const EdgeInsets.symmetric(vertical: 10),
//                                   decoration: BoxDecoration(
//                                     color: _verificationMethod == 'email'
//                                         ? Colors.green.shade100
//                                         : Colors.transparent,
//                                     borderRadius: BorderRadius.circular(25),
//                                   ),
//                                   child: Center(
//                                     child: Text(
//                                       'Email',
//                                       style: TextStyle(
//                                         color: _verificationMethod == 'email'
//                                             ? Colors.green.shade700
//                                             : Colors.grey.shade600,
//                                         fontWeight: FontWeight.w600,
//                                       ),
//                                     ),
//                                   ),
//                                 ),
//                               ),
//                             ),
//                             Expanded(
//                               child: GestureDetector(
//                                 onTap: () {
//                                   setState(() {
//                                     _verificationMethod = 'phone';
//                                   });
//                                   WidgetsBinding.instance.addPostFrameCallback((_) {
//                                     _phoneFocusNode.requestFocus();
//                                   });
//                                 },
//                                 child: AnimatedContainer(
//                                   duration: const Duration(milliseconds: 200),
//                                   padding: const EdgeInsets.symmetric(vertical: 10),
//                                   decoration: BoxDecoration(
//                                     color: _verificationMethod == 'phone'
//                                         ? Colors.green.shade100
//                                         : Colors.transparent,
//                                     borderRadius: BorderRadius.circular(25),
//                                   ),
//                                   child: Center(
//                                     child: Text(
//                                       'Phone',
//                                       style: TextStyle(
//                                         color: _verificationMethod == 'phone'
//                                             ? Colors.green.shade700
//                                             : Colors.grey.shade600,
//                                         fontWeight: FontWeight.w600,
//                                       ),
//                                     ),
//                                   ),
//                                 ),
//                               ),
//                             ),
//                           ],
//                         ),
//                       ),
//
//                       const SizedBox(height: 20),
//
//                       // Input field
//                       AnimatedSwitcher(
//                         duration: const Duration(milliseconds: 300),
//                         transitionBuilder: (Widget child, Animation<double> animation) {
//                           return FadeTransition(
//                             opacity: animation,
//                             child: SlideTransition(
//                               position: Tween<Offset>(
//                                 begin: const Offset(0.2, 0),
//                                 end: Offset.zero,
//                               ).animate(animation),
//                               child: child,
//                             ),
//                           );
//                         },
//                         child: Container(
//                           key: ValueKey(_verificationMethod),
//                           decoration: BoxDecoration(
//                               color: Colors.white,
//                               borderRadius: BorderRadius.circular(15)
//                           ),
//                           child: _verificationMethod == 'email'
//                               ? Column(
//                             children: [
//                               TextField(
//                                 controller: _emailController,
//                                 focusNode: _emailFocusNode,
//                                 keyboardType: TextInputType.emailAddress,
//                                 textInputAction: TextInputAction.done,
//                                 autocorrect: false,
//                                 enableSuggestions: true,
//                                 decoration: const InputDecoration(
//                                   hintText: 'Email Address',
//                                   border: InputBorder.none,
//                                   contentPadding: EdgeInsets.all(16),
//                                   prefixIcon: Icon(Icons.email_outlined, color: Colors.green),
//                                 ),
//                                 onChanged: (_) => setState(() {}),
//                               ),
//                               if (_emailError != null)
//                                 Padding(
//                                   padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
//                                   child: Align(
//                                     alignment: Alignment.centerLeft,
//                                     child: Text(
//                                       _emailError!,
//                                       style: TextStyle(color: Colors.red.shade600, fontSize: 12),
//                                     ),
//                                   ),
//                                 ),
//                             ],
//                           )
//                               : Column(
//                             children: [
//                               TextField(
//                                 controller: _phoneController,
//                                 focusNode: _phoneFocusNode,
//                                 keyboardType: TextInputType.phone,
//                                 textInputAction: TextInputAction.done,
//                                 maxLength: 10,
//                                 inputFormatters: [
//                                   FilteringTextInputFormatter.digitsOnly,
//                                   LengthLimitingTextInputFormatter(10),
//                                 ],
//                                 decoration: const InputDecoration(
//                                   hintText: 'Phone Number (10 digits)',
//                                   border: InputBorder.none,
//                                   contentPadding: EdgeInsets.all(16),
//                                   prefixIcon: Icon(Icons.phone_outlined, color: Colors.green),
//                                   counterText: '',
//                                 ),
//                                 onChanged: (_) => setState(() {}),
//                               ),
//                               if (_phoneError != null)
//                                 Padding(
//                                   padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
//                                   child: Align(
//                                     alignment: Alignment.centerLeft,
//                                     child: Text(
//                                       _phoneError!,
//                                       style: TextStyle(color: Colors.red.shade600, fontSize: 12),
//                                     ),
//                                   ),
//                                 ),
//                             ],
//                           ),
//                         ),
//                       ),
//
//                       const SizedBox(height: 20),
//
//                       // Send OTP Button - NO AUTO-LOGIN, USER MUST CLICK
//                       Obx(() => SizedBox(
//                         width: double.infinity,
//                         height: 50,
//                         child: ElevatedButton(
//                           onPressed: authVm.isLoading.value || !_isFormValid()
//                               ? null
//                               : () async {
//                             // ✅ USER MUST CLICK THE BUTTON - NO AUTO SUBMIT
//                             print('\n========== SEND OTP BUTTON PRESSED ==========');
//                             print('Verification Method: $_verificationMethod');
//
//                             bool success;
//                             String identifier = '';
//
//                             if (_verificationMethod == 'email') {
//                               if (_emailController.text.trim().isEmpty) {
//                                 Get.snackbar('Error', 'Please enter your email',
//                                     backgroundColor: Colors.red, colorText: Colors.white);
//                                 return;
//                               }
//
//                               String emailPattern = r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$';
//                               if (!RegExp(emailPattern).hasMatch(_emailController.text.trim())) {
//                                 Get.snackbar('Error', 'Please enter a valid email address',
//                                     backgroundColor: Colors.red, colorText: Colors.white);
//                                 return;
//                               }
//
//                               identifier = _emailController.text.trim();
//                               print('✅ Email: $identifier');
//
//                               success = await authVm.sendPasswordResetOtp(
//                                 verificationMethod: 'email',
//                                 email: identifier,
//                               );
//                             } else {
//                               if (_phoneController.text.trim().isEmpty) {
//                                 Get.snackbar('Error', 'Please enter your phone number',
//                                     backgroundColor: Colors.red, colorText: Colors.white);
//                                 return;
//                               }
//
//                               String phoneNumber = _phoneController.text.trim();
//                               if (phoneNumber.length != 10 || !RegExp(r'^[0-9]+$').hasMatch(phoneNumber)) {
//                                 Get.snackbar('Error', 'Please enter a valid 10-digit phone number',
//                                     backgroundColor: Colors.red, colorText: Colors.white);
//                                 return;
//                               }
//
//                               identifier = phoneNumber;
//                               print('✅ Phone: $identifier');
//
//                               success = await authVm.sendPasswordResetOtp(
//                                 verificationMethod: 'phone',
//                                 phone: identifier,
//                               );
//                             }
//
//                             print('📥 API Response Success: $success');
//
//                             if (success) {
//                               print('🔀 Navigating to OTP Verification');
//                               print('   Identifier: $identifier');
//
//                               Get.toNamed(
//                                 AppRoutes.otpVerification,
//                                 arguments: {
//                                   'identifier': identifier,
//                                   'isRegistration': false,
//                                   'verificationMethod': _verificationMethod,
//                                 },
//                               );
//                             }
//                             print('========== SEND OTP BUTTON PRESSED END ==========\n');
//                           },
//                           style: ElevatedButton.styleFrom(
//                             backgroundColor: Colors.white,
//                             foregroundColor: Colors.green.shade700,
//                             shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
//                           ),
//                           child: authVm.isLoading.value
//                               ? const SizedBox(
//                             height: 20,
//                             width: 20,
//                             child: CircularProgressIndicator(
//                               strokeWidth: 2,
//                               valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
//                             ),
//                           )
//                               : const Text('Send OTP', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
//                         ),
//                       )),
//
//                       const SizedBox(height: 20),
//
//                       // Back to login button
//                       TextButton(
//                         onPressed: () {
//                           Get.back();
//                         },
//                         child: const Text('Back to Login', style: TextStyle(color: Colors.white)),
//                       ),
//                     ],
//                   ),
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
//
//   bool _isFormValid() {
//     if (_verificationMethod == 'email') {
//       final email = _emailController.text.trim();
//       if (email.isEmpty) return false;
//       final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
//       return emailRegex.hasMatch(email);
//     } else {
//       final phone = _phoneController.text.trim();
//       if (phone.isEmpty) return false;
//       return phone.length == 10 && RegExp(r'^[0-9]+$').hasMatch(phone);
//     }
//   }
// }