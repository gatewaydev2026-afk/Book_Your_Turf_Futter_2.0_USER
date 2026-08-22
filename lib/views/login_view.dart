// import 'package:flutter/material.dart';
// import 'package:get/get.dart';
// import '../view_models/auth_view_model.dart';
// import '../services/shared_prefs_helper.dart';
// import '../routes/app_routes.dart';
//
// class LoginView extends StatefulWidget {
//   const LoginView({Key? key}) : super(key: key);
//
//   @override
//   State<LoginView> createState() => _LoginViewState();
// }
//
// class _LoginViewState extends State<LoginView> {
//   final _emailController = TextEditingController();
//   final _passwordController = TextEditingController();
//   bool _isPasswordVisible = false;
//   final authVm = Get.find<AuthViewModel>();
//
//   @override
//   Widget build(BuildContext context) {
//     final size = MediaQuery.of(context).size;
//     final isTablet = size.width > 600;
//
//     return Scaffold(
//       appBar: AppBar(
//         backgroundColor: Colors.green.shade800,
//         elevation: 0,
//         leading: IconButton(
//           icon: const Icon(Icons.arrow_back, color: Colors.white),
//           onPressed: () {
//             // Navigate back to GuestOrLoginView
//             Get.offAllNamed(AppRoutes.guestOrLogin);
//           },
//         ),
//         title: const Text(
//           'Sign In',
//           style: TextStyle(color: Colors.white),
//         ),
//         centerTitle: true,
//       ),
//       body: SizedBox(
//         width: double.infinity,
//         height: size.height,
//         child: Container(
//           constraints: BoxConstraints(minHeight: size.height),
//           decoration: BoxDecoration(
//             gradient: LinearGradient(
//               begin: Alignment.topLeft,
//               end: Alignment.bottomRight,
//               colors: [
//                 Colors.green.shade800,
//                 Colors.green.shade600,
//                 Colors.green.shade400,
//               ],
//             ),
//           ),
//           child: SafeArea(
//             child: SingleChildScrollView(
//               physics: const BouncingScrollPhysics(),
//               padding: EdgeInsets.symmetric(horizontal: isTablet ? 50 : 24),
//               child: ConstrainedBox(
//                 constraints: BoxConstraints(minHeight: size.height * 0.9),
//                 child: bodyContent(),
//               ),
//             ),
//           ),
//         ),
//       ),
//     );
//   }
//
//   Column bodyContent() {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         const SizedBox(height: 20),
//         Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text(
//               'Welcome\nBack!',
//               style: TextStyle(
//                 fontSize: 30,
//                 fontWeight: FontWeight.bold,
//                 color: Colors.white,
//                 height: 1.2,
//               ),
//             ),
//             const SizedBox(height: 12),
//             Text(
//               'Sign in to continue',
//               style: TextStyle(
//                 fontSize: 16,
//                 color: Colors.white.withOpacity(0.9),
//               ),
//             ),
//           ],
//         ),
//         const SizedBox(height: 25),
//         Container(
//           padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
//           decoration: BoxDecoration(
//             color: Colors.white,
//             borderRadius: BorderRadius.circular(30),
//           ),
//           child: Column(
//             children: [
//               _buildTextField(
//                 _emailController,
//                 Icons.email_outlined,
//                 'Email / Phone',
//                 'Enter email or phone',
//               ),
//               const Divider(height: 1, indent: 20, endIndent: 20),
//               _buildPasswordField(
//                 _passwordController,
//                 'Password',
//                 'Enter password',
//                 _isPasswordVisible,
//                     () => setState(() => _isPasswordVisible = !_isPasswordVisible),
//               ),
//             ],
//           ),
//         ),
//         const SizedBox(height: 20),
//         Row(
//           mainAxisAlignment: MainAxisAlignment.end,
//           children: [
//             TextButton(
//               onPressed: () => Get.toNamed(AppRoutes.forgotPassword),
//               child: const Text(
//                 'Forgot Password?',
//                 style: TextStyle(color: Colors.white),
//               ),
//             ),
//           ],
//         ),
//         const SizedBox(height: 30),
//         Obx(
//               () => SizedBox(
//             width: double.infinity,
//             height: 55,
//             child: ElevatedButton(
//               onPressed: authVm.isLoading.value
//                   ? null
//                   : () async {
//                 print('\n========== LOGIN ATTEMPT ==========');
//                 print('Login ID: ${_emailController.text}');
//
//                 bool success = await authVm.login(
//                   _emailController.text,
//                   _passwordController.text,
//                 );
//
//                 if (success) {
//                   final token = SharedPrefsHelper.getToken();
//                   print('✅ Login successful!');
//                   print('Token saved: ${token != null ? "Yes" : "No"}');
//                   if (token != null && token.isNotEmpty) {
//                     print('Token preview: ${token.substring(0, token.length > 20 ? 20 : token.length)}...');
//                   }
//                   // Navigation handled in authVm.login()
//                 } else {
//                   print('❌ Login failed - No token saved');
//                 }
//                 print('=====================================\n');
//               },
//               style: ElevatedButton.styleFrom(
//                 backgroundColor: Colors.white,
//                 foregroundColor: Colors.green.shade700,
//                 shape: RoundedRectangleBorder(
//                   borderRadius: BorderRadius.circular(18),
//                 ),
//               ),
//               child: authVm.isLoading.value
//                   ? const CircularProgressIndicator()
//                   : const Text(
//                 'Sign In',
//                 style: TextStyle(
//                   fontSize: 18,
//                   fontWeight: FontWeight.bold,
//                 ),
//               ),
//             ),
//           ),
//         ),
//         const SizedBox(height: 25),
//         Row(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             Text(
//               "Don't have an account? ",
//               style: TextStyle(color: Colors.white.withOpacity(0.9)),
//             ),
//             GestureDetector(
//               onTap: () {
//                 print('🔀 Navigate to Register');
//                 Get.toNamed(AppRoutes.register);
//               },
//               child: const Text(
//                 'Sign Up',
//                 style: TextStyle(
//                   color: Colors.white,
//                   fontWeight: FontWeight.bold,
//                 ),
//               ),
//             ),
//           ],
//         ),
//         const SizedBox(height: 30),
//       ],
//     );
//   }
//
//   Widget _buildTextField(
//       TextEditingController c,
//       IconData icon,
//       String label,
//       String hint,
//       ) {
//     return Padding(
//       padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Row(
//             children: [
//               Icon(icon, color: Colors.green.shade700, size: 20),
//               const SizedBox(width: 10),
//               Text(
//                 label,
//                 style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
//               ),
//             ],
//           ),
//           const SizedBox(height: 8),
//           TextField(
//             keyboardType: TextInputType.emailAddress,
//             controller: c,
//             decoration: InputDecoration(
//               hintText: hint,
//               hintStyle: TextStyle(fontSize: 12),
//               border: InputBorder.none,
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildPasswordField(
//       TextEditingController c,
//       String label,
//       String hint,
//       bool isVisible,
//       VoidCallback toggle,
//       ) {
//     return Padding(
//       padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Row(
//             children: [
//               const Icon(Icons.lock_outline, color: Colors.green, size: 20),
//               const SizedBox(width: 10),
//               Text(
//                 label,
//                 style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
//               ),
//             ],
//           ),
//           const SizedBox(height: 8),
//           TextField(
//             controller: c,
//             obscureText: !isVisible,
//             maxLength: 20,
//             buildCounter: (context, {required currentLength, required isFocused, maxLength}) {
//               return null;
//             },
//             decoration: InputDecoration(
//               hintText: hint,
//               hintStyle: TextStyle(fontSize: 12),
//               border: InputBorder.none,
//               suffixIcon: IconButton(
//                 icon: Icon(isVisible ? Icons.visibility_off : Icons.visibility),
//                 onPressed: toggle,
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }