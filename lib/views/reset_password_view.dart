// import 'package:flutter/material.dart';
// import 'package:get/get.dart';
// import '../view_models/auth_view_model.dart';
// import '../routes/app_routes.dart';
//
// class ResetPasswordView extends StatefulWidget {
//   const ResetPasswordView({super.key});
//
//   @override
//   State<ResetPasswordView> createState() => _ResetPasswordViewState();
// }
//
// class _ResetPasswordViewState extends State<ResetPasswordView> {
//   final _passwordController = TextEditingController();
//   final _confirmController = TextEditingController();
//   bool _isPasswordVisible = false;
//   bool _isConfirmVisible = false;
//   final authVm = Get.find<AuthViewModel>();
//   late String otp;
//
//   @override
//   void initState() {
//     super.initState();
//     final args = Get.arguments as Map<String, dynamic>;
//     otp = args['otp'];
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       body: Container(
//         decoration: BoxDecoration(
//           gradient: LinearGradient(
//             begin: Alignment.topLeft,
//             end: Alignment.bottomRight,
//             colors: [Colors.green.shade800, Colors.green.shade400],
//           ),
//         ),
//         child: SafeArea(
//           child: Padding(
//             padding: const EdgeInsets.all(24),
//             child: Column(
//               mainAxisAlignment: MainAxisAlignment.center,
//               children: [
//                 Container(
//                   padding: const EdgeInsets.all(20),
//                   decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
//                   child: Icon(Icons.lock_reset, size: 60, color: Colors.green.shade700),
//                 ),
//                 const SizedBox(height: 30),
//                 const Text(
//                   'Create New Password',
//                   style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
//                 ),
//                 const SizedBox(height: 30),
//                 Container(
//                   decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15)),
//                   child: TextField(
//                     controller: _passwordController,
//                     obscureText: !_isPasswordVisible,
//                     decoration: InputDecoration(
//                       hintText: 'New Password',
//                       prefixIcon: const Icon(Icons.lock_outline),
//                       suffixIcon: IconButton(
//                         icon: Icon(_isPasswordVisible ? Icons.visibility_off : Icons.visibility),
//                         onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
//                       ),
//                       border: InputBorder.none,
//                       contentPadding: const EdgeInsets.all(16),
//                     ),
//                   ),
//                 ),
//                 const SizedBox(height: 15),
//                 Container(
//                   decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15)),
//                   child: TextField(
//                     controller: _confirmController,
//                     obscureText: !_isConfirmVisible,
//                     decoration: InputDecoration(
//                       hintText: 'Confirm Password',
//                       prefixIcon: const Icon(Icons.lock_outline),
//                       suffixIcon: IconButton(
//                         icon: Icon(_isConfirmVisible ? Icons.visibility_off : Icons.visibility),
//                         onPressed: () => setState(() => _isConfirmVisible = !_isConfirmVisible),
//                       ),
//                       border: InputBorder.none,
//                       contentPadding: const EdgeInsets.all(16),
//                     ),
//                   ),
//                 ),
//                 const SizedBox(height: 20),
//                 Obx(
//                       () => SizedBox(
//                     width: double.infinity,
//                     height: 50,
//                     child: ElevatedButton(
//                       onPressed: authVm.isLoading.value
//                           ? null
//                           : () async {
//                         if (_passwordController.text != _confirmController.text) {
//                           Get.snackbar('Error', 'Passwords do not match',
//                               backgroundColor: Colors.red, colorText: Colors.white);
//                           return;
//                         }
//                         bool success = await authVm.resetPassword(otp, _passwordController.text);
//                         if (success) Get.offAllNamed(AppRoutes.login);
//                       },
//                       style: ElevatedButton.styleFrom(
//                         backgroundColor: Colors.white,
//                         foregroundColor: Colors.green.shade700,
//                         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
//                       ),
//                       child: authVm.isLoading.value
//                           ? const CircularProgressIndicator()
//                           : const Text('Reset Password', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
//                     ),
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         ),
//       ),
//     );
//   }
// }