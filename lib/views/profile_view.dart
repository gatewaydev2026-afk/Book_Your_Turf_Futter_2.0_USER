// views/profile_view.dart
// ✅ Complete with Device Management menu item & Lazy Loading
// ✅ Duplicate API call prevention with flags
// ✅ Updated to use system_media_picker (No permissions required)
// ✅ StatefulWidget to fix immutable warnings

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:system_media_picker/system_media_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import '../services/shared_prefs_helper.dart';
import '../view_models/profile_view_model.dart';
import '../view_models/auth_view_model.dart';
import '../view_models/wallet_view_model.dart';
import '../view_models/coin_view_model.dart';
import '../view_models/booking_view_model.dart';
import '../view_models/main_page_view_model.dart';
import '../themes/app_colors.dart';
import '../routes/app_routes.dart';
import '../views/wallet_recharge_dialog.dart';
import '../views/wallet_transactions_view.dart';
import '../views/coin_transactions_view.dart';
import '../views/device_management_view.dart';

class ProfileView extends StatefulWidget {
  const ProfileView({super.key});

  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> {
  // ✅ DUPLICATE API CALL PREVENTION FLAGS
  bool _isRefreshing = false;
  bool _isDialogOpen = false;
  bool _isBottomSheetOpen = false;

  late final ProfileViewModel vm;
  late final AuthViewModel authVm;
  late final WalletViewModel walletVm;

  @override
  void initState() {
    super.initState();
    if (!Get.isRegistered<ProfileViewModel>()) {
      Get.put(ProfileViewModel(), permanent: true);
    }
    if (!Get.isRegistered<WalletViewModel>()) {
      Get.put(WalletViewModel(), permanent: true);
    }
    vm = Get.find<ProfileViewModel>();
    authVm = Get.find<AuthViewModel>();
    walletVm = Get.find<WalletViewModel>();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          // ✅ Prevent duplicate refreshes
          if (_isRefreshing) {
            print('⏭️ Profile refresh already in progress - skipping duplicate');
            return;
          }
          _isRefreshing = true;
          try {
            await vm.refresh();
          } finally {
            _isRefreshing = false;
          }
        },
        child: Obx(() {
          if (vm.isLoading.value && vm.name.value.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          return CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // SliverAppBar with Large Profile Image
              SliverAppBar(
                expandedHeight: 320,
                pinned: false,
                stretch: true,
                backgroundColor: Colors.green,
                flexibleSpace: LayoutBuilder(
                  builder: (context, constraints) {
                    double percent =
                        (constraints.maxHeight - kToolbarHeight) /
                            (320 - kToolbarHeight);
                    double scale = percent.clamp(0.6, 1.0);
                    return Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.asset(
                          'assets/images/turf.jpg',
                          fit: BoxFit.cover,
                        ),
                        Container(color: Colors.black.withOpacity(0.5)),
                        Align(
                          alignment: Alignment.bottomCenter,
                          child: Padding(
                            padding: EdgeInsets.only(bottom: 20 * scale),
                            child: Transform.scale(
                              scale: scale,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Profile Image with Edit Icon
                                  GestureDetector(
                                    onTap: () => _showFullScreenImage(context),
                                    child: Stack(
                                      children: [
                                        Obx(
                                              () => Container(
                                            width: 150 * scale,
                                            height: 150 * scale,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: Colors.white,
                                                width: 3 * scale,
                                              ),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black.withOpacity(0.3),
                                                  blurRadius: 10,
                                                  offset: const Offset(0, 5),
                                                ),
                                              ],
                                            ),
                                            child: ClipOval(
                                              child: _buildProfileImage(
                                                imageUrl: vm.profileImageUrl.value,
                                                size: 150 * scale,
                                              ),
                                            ),
                                          ),
                                        ),
                                        // Edit Icon Button
                                        Positioned(
                                          bottom: 0,
                                          right: 0,
                                          child: GestureDetector(
                                            onTap: () => _showEditProfileDialog(context),
                                            child: Container(
                                              padding: EdgeInsets.all(8 * scale),
                                              decoration: BoxDecoration(
                                                color: Colors.green,
                                                shape: BoxShape.circle,
                                                border: Border.all(
                                                  color: Colors.white,
                                                  width: 2,
                                                ),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: Colors.black.withOpacity(0.2),
                                                    blurRadius: 4,
                                                    offset: const Offset(0, 2),
                                                  ),
                                                ],
                                              ),
                                              child: Icon(
                                                Icons.edit,
                                                size: 20 * scale,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Obx(
                                        () => Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 20,
                                      ),
                                      child: Text(
                                        vm.name.value,
                                        style: TextStyle(
                                          fontSize: 18 * scale,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                  Obx(
                                        () => Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 20,
                                      ),
                                      child: Text(
                                        vm.phone.value,
                                        style: TextStyle(
                                          fontSize: 13 * scale,
                                          color: Colors.white70,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
                actions: [
                  LayoutBuilder(
                    builder: (context, constraints) {
                      double percent =
                          (constraints.maxHeight - kToolbarHeight) /
                              (320 - kToolbarHeight);
                      double opacity = (1 - percent).clamp(0.0, 1.0);
                      return Opacity(
                        opacity: opacity,
                        child: Row(
                          children: [
                            IconButton(
                              onPressed: () => vm.refresh(),
                              icon: const Icon(
                                Icons.refresh,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
                title: LayoutBuilder(
                  builder: (context, constraints) {
                    double percent =
                        (constraints.maxHeight - kToolbarHeight) /
                            (320 - kToolbarHeight);
                    double opacity = (1 - percent).clamp(0.0, 1.0);
                    return Obx(
                          () => Opacity(
                        opacity: opacity,
                        child: Text(
                          vm.name.value,
                          style: const TextStyle(fontSize: 16),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    );
                  },
                ),
                centerTitle: true,
              ),
              SliverToBoxAdapter(
                child: Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    image: DecorationImage(
                      image: AssetImage('assets/images/byt-bg.png'),
                      fit: BoxFit.cover,
                      opacity: 0.3,
                    ),
                  ),
                  child: Column(
                    children: [
                      const SizedBox(height: 20),
                      // Refer & Earn Card
                      referEarnCard(
                        image: 'assets/icons/undraw_fans_icv6.svg',
                        code: vm.referralCode.value,
                        onCopy: () {
                          Clipboard.setData(
                            ClipboardData(text: vm.referralCode.value),
                          );
                          Get.snackbar(
                            'Copied',
                            'Referral code copied to clipboard',
                            backgroundColor: Colors.green,
                            colorText: Colors.white,
                          );
                        },
                      ),
                      const SizedBox(height: 20),
                      // Points and Wallet Card
                      responsiveWrapper(
                        child: Obx(
                              () => PointsCard(
                            points: vm.gameCoins.value,
                            walletBalance: vm.walletBalance.value,
                            onRedeem: () => _showConvertCoinsDialog(),
                            onRefreshWallet: () => vm.refreshWalletBalance(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Menu Items
                      responsiveWrapper(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.white,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            children: [
                              others(
                                title: 'My Bookings',
                                icon: 'assets/icons/calender copy.svg',
                                onTap: () {
                                  final mainPageVm = Get.find<MainPageViewModel>();
                                  mainPageVm.changeTab(1);
                                  final bookingVm = Get.find<BookingViewModel>();
                                  bookingVm.loadBookings();
                                },
                              ),
                              Divider(color: AppColors.grey.withOpacity(0.3)),
                              others(
                                title: 'Favorite Turfs',
                                icon: 'assets/icons/fav copy.svg',
                                onTap: () => Get.toNamed(AppRoutes.favorites),
                              ),
                              Divider(color: AppColors.grey.withOpacity(0.3)),
                              others(
                                title: 'Wallet',
                                icon: Icons.account_balance_wallet,
                                onTap: () => _showWalletOptions(),
                              ),
                              Divider(color: AppColors.grey.withOpacity(0.3)),
                              others(
                                title: 'Wallet Transactions',
                                icon: Icons.history,
                                onTap: () {
                                  final walletVm = Get.find<WalletViewModel>();
                                  walletVm.loadWalletData();
                                  Get.to(() => const WalletTransactionsView());
                                },
                              ),
                              Divider(color: AppColors.grey.withOpacity(0.3)),
                              others(
                                title: 'Coin History',
                                icon: 'assets/icons/coin.svg',
                                onTap: () {
                                  final coinVm = Get.find<CoinViewModel>();
                                  coinVm.loadCoinData();
                                  Get.to(() => const CoinTransactionsView());
                                },
                              ),
                              Divider(color: AppColors.grey.withOpacity(0.3)),
                              others(
                                title: 'App Info',
                                icon: 'assets/icons/info copy.svg',
                                onTap: () => Get.toNamed(AppRoutes.aboutUs),
                              ),
                              Divider(color: AppColors.grey.withOpacity(0.3)),
                              others(
                                title: 'Privacy Policy',
                                icon: 'assets/icons/privacy.svg',
                                onTap: () => Get.toNamed(AppRoutes.privacyPolicy),
                              ),
                              Divider(color: AppColors.grey.withOpacity(0.3)),
                              others(
                                title: 'Terms & Conditions',
                                icon: 'assets/icons/terms.svg',
                                onTap: () => Get.toNamed(AppRoutes.termAndCondition),
                              ),
                              Divider(color: AppColors.grey.withOpacity(0.3)),
                              others(
                                title: 'Manage Devices',
                                icon: Icons.devices,
                                onTap: () => Get.to(() => const DeviceManagementView()),
                              ),
                              Divider(color: AppColors.grey.withOpacity(0.3)),
                              others(
                                title: 'Logout',
                                icon: 'assets/icons/logout.svg',
                                onTap: () => _showLogoutConfirmation(),
                                color: Colors.red,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text('App version 2.0.0'),
                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

  // Build profile image with perfect cover fit
  Widget _buildProfileImage({required String imageUrl, required double size}) {
    if (imageUrl.isNotEmpty) {
      return Image.network(
        '${imageUrl}?v=${vm.imageVersion.value}',
        width: size,
        height: size,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Center(
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.green,
            ),
          );
        },
        errorBuilder: (_, __, ___) => Container(
          color: Colors.green.shade100,
          child: Icon(
            Icons.person,
            size: size * 0.5,
            color: Colors.green,
          ),
        ),
      );
    } else {
      return Container(
        color: Colors.green.shade100,
        child: Icon(
          Icons.person,
          size: size * 0.5,
          color: Colors.green,
        ),
      );
    }
  }

  // Show full screen image with zoom
  void _showFullScreenImage(BuildContext context) {
    final imageUrl = vm.profileImageUrl.value;

    if (imageUrl.isEmpty) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FullScreenImageViewer(
          imageUrl: '${imageUrl}?v=${vm.imageVersion.value}',
        ),
      ),
    );
  }

  // ✅ FIXED: Wallet options with duplicate prevention
  void _showWalletOptions() {
    if (_isBottomSheetOpen || (Get.isBottomSheetOpen ?? false)) {
      print('⏭️ Wallet options already open - skipping duplicate');
      return;
    }

    _isBottomSheetOpen = true;

    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Obx(() => Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.green.shade400, Colors.green.shade600],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  const Icon(Icons.account_balance_wallet, color: Colors.white, size: 30),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Wallet Balance',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                      Text(
                        '₹${walletVm.walletBalance.value.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => walletVm.loadWalletData(forceRefresh: true),
                    icon: const Icon(Icons.refresh, color: Colors.white),
                  ),
                ],
              ),
            )),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.add_circle, color: Colors.green),
              title: const Text('Recharge Wallet'),
              onTap: () {
                Get.back();
                showDialog(
                  context: Get.context!,
                  builder: (context) => const WalletRechargeDialog(),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.history, color: Colors.blue),
              title: const Text('View Transactions'),
              onTap: () {
                Get.back();
                walletVm.loadWalletData();
                Get.to(() => const WalletTransactionsView());
              },
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    ).whenComplete(() {
      _isBottomSheetOpen = false;
    });
  }

  // ✅ FIXED: Logout confirmation with duplicate prevention
  void _showLogoutConfirmation() {
    if (_isDialogOpen || (Get.isDialogOpen ?? false)) {
      print('⏭️ Dialog already open - skipping duplicate');
      return;
    }

    _isDialogOpen = true;

    Get.dialog(
      Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 35),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Logout?",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                "Are you sure want to logout?",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Get.back();
                        authVm.logout();
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      child: const Text(
                        "Yes",
                        style: TextStyle(color: Colors.black),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Get.back(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      child: const Text(
                        "No",
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      barrierDismissible: false,
    ).whenComplete(() {
      _isDialogOpen = false;
    });
  }

  // ✅ FIXED: Edit profile with duplicate prevention
  void _showEditProfileDialog(BuildContext context) {
    if (_isBottomSheetOpen || (Get.isBottomSheetOpen ?? false)) {
      print('⏭️ Edit profile already open - skipping duplicate');
      return;
    }

    _isBottomSheetOpen = true;
    final nameController = TextEditingController(text: vm.name.value);
    File? selectedImageFile;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return SafeArea(
            child: Container(
              height: MediaQuery.of(context).size.height * 0.85,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
              ),
              child: EditProfileContent(
                vm: vm,
                selectedImageFile: selectedImageFile,
                onImageSelected: (file) {
                  setState(() {
                    selectedImageFile = file;
                  });
                },
                nameController: nameController,
                context: context,
              ),
            ),
          );
        },
      ),
    ).whenComplete(() {
      _isBottomSheetOpen = false;
    });
  }

  // ✅ FIXED: Convert coins dialog with duplicate prevention
  void _showConvertCoinsDialog() {
    if (_isDialogOpen || (Get.isDialogOpen ?? false)) {
      print('⏭️ Dialog already open - skipping duplicate');
      return;
    }

    _isDialogOpen = true;
    final coinsController = TextEditingController();

    Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Convert Coins to Wallet"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Enter number of coins to convert:"),
            const SizedBox(height: 10),
            TextField(
              controller: coinsController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                hintText: "Min 200 coins",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Obx(
                  () => Text(
                "Current wallet balance: ₹${vm.walletBalance.value.toStringAsFixed(2)}",
                style: const TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text("Cancel")),
          Obx(
                () => ElevatedButton(
              onPressed: vm.isLoading.value
                  ? null
                  : () async {
                int coins = int.tryParse(coinsController.text) ?? 0;
                if (coins >= 200) {
                  Get.back();
                  await vm.convertCoins(coins);
                  await vm.refreshWalletBalance();
                } else {
                  Get.snackbar(
                    'Error',
                    'Minimum 200 coins required',
                    backgroundColor: Colors.red,
                    colorText: Colors.white,
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: vm.isLoading.value
                  ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
                  : const Text(
                "Convert",
                style: TextStyle(color: Colors.white),
              ),
            ),
          ),
        ],
      ),
      barrierDismissible: false,
    ).whenComplete(() {
      _isDialogOpen = false;
    });
  }
}

// ============================================================
// Full Screen Image Viewer with Zoom
// ============================================================

class FullScreenImageViewer extends StatelessWidget {
  final String imageUrl;

  const FullScreenImageViewer({
    super.key,
    required this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white, size: 28),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.download_outlined, color: Colors.white),
            onPressed: () {
              Get.snackbar(
                'Info',
                'Download feature coming soon',
                backgroundColor: Colors.grey,
                colorText: Colors.white,
              );
            },
          ),
        ],
      ),
      body: GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Center(
          child: InteractiveViewer(
            minScale: 0.5,
            maxScale: 4.0,
            child: Image.network(
              imageUrl,
              fit: BoxFit.contain,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                );
              },
              errorBuilder: (_, __, ___) => const Center(
                child: Icon(
                  Icons.broken_image,
                  color: Colors.white,
                  size: 64,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// Edit Profile Content Widget
// ============================================================

class EditProfileContent extends StatefulWidget {
  final ProfileViewModel vm;
  final File? selectedImageFile;
  final Function(File) onImageSelected;
  final TextEditingController nameController;
  final BuildContext context;

  const EditProfileContent({
    super.key,
    required this.vm,
    required this.selectedImageFile,
    required this.onImageSelected,
    required this.nameController,
    required this.context,
  });

  @override
  State<EditProfileContent> createState() => _EditProfileContentState();
}

class _EditProfileContentState extends State<EditProfileContent> {
  // ✅ SystemMediaPicker - No permissions required on Android & iOS
  final SystemMediaPicker _picker = SystemMediaPicker();

  Future<void> _pickImage() async {
    try {
      // ✅ Using system_media_picker - works on both Android & iOS without permissions
      final List<PickedMedia> images = await _picker.pickImages(limit: 1);

      if (images.isNotEmpty) {
        final PickedMedia image = images.first;
        print('Image picked: ${image.path}');

        final File file = File(image.path);
        final int size = await file.length();
        print('Image size: ${(size / 1024).toStringAsFixed(2)} KB');

        widget.onImageSelected(file);
      } else {
        print('No image selected');
      }
    } catch (e) {
      print('Error picking image: $e');
      if (mounted) {
        Get.snackbar(
          'Error',
          'Failed to pick image: $e',
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.only(top: 12),
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.grey.shade300,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'Edit Profile',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 20),

        // Profile Image with tap to change
        GestureDetector(
          onTap: _pickImage,
          child: Stack(
            children: [
              Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.green, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipOval(
                  child: Obx(
                        () {
                      if (widget.selectedImageFile != null) {
                        return Image.file(
                          widget.selectedImageFile!,
                          width: 140,
                          height: 140,
                          fit: BoxFit.cover,
                        );
                      } else if (widget.vm.profileImageUrl.value.isNotEmpty) {
                        return Image.network(
                          '${widget.vm.profileImageUrl.value}?v=${widget.vm.imageVersion.value}',
                          width: 140,
                          height: 140,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Container(
                              color: Colors.green.shade100,
                              child: const Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.green,
                                ),
                              ),
                            );
                          },
                          errorBuilder: (_, __, ___) => Container(
                            color: Colors.green.shade100,
                            child: const Icon(
                              Icons.person,
                              size: 70,
                              color: Colors.green,
                            ),
                          ),
                        );
                      } else {
                        return Container(
                          color: Colors.green.shade100,
                          child: const Icon(
                            Icons.person,
                            size: 70,
                            color: Colors.green,
                          ),
                        );
                      }
                    },
                  ),
                ),
              ),
              Positioned(
                bottom: 5,
                right: 5,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: const BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.camera_alt,
                    size: 24,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Tap on image to change',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 30),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              // Name field - Editable
              TextField(
                controller: widget.nameController,
                decoration: InputDecoration(
                  labelText: 'Full Name',
                  prefixIcon: const Icon(
                    Icons.person_outline,
                    color: Colors.green,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.green, width: 2),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 14,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Email field - LOCKED
              Obx(
                    () => TextField(
                  controller: TextEditingController(
                    text: widget.vm.email.value,
                  ),
                  keyboardType: TextInputType.emailAddress,
                  enabled: false,
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  decoration: InputDecoration(
                    labelText: 'Email Address',
                    hintText: 'Email cannot be changed',
                    prefixIcon: const Icon(
                      Icons.email_outlined,
                      color: Colors.green,
                    ),
                    suffixIcon: const Icon(
                      Icons.lock_outline,
                      size: 18,
                      color: Colors.grey,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    disabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade200),
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 14,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Phone field - LOCKED
              Obx(
                    () => TextField(
                  controller: TextEditingController(
                    text: widget.vm.phone.value,
                  ),
                  keyboardType: TextInputType.phone,
                  enabled: false,
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  decoration: InputDecoration(
                    labelText: 'Phone Number',
                    hintText: 'Phone number cannot be changed',
                    prefixIcon: const Icon(
                      Icons.phone_outlined,
                      color: Colors.green,
                    ),
                    suffixIcon: const Icon(
                      Icons.lock_outline,
                      size: 18,
                      color: Colors.grey,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    disabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade200),
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 14,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        const Spacer(),

        Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Get.back(),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    side: BorderSide(color: Colors.grey.shade400),
                  ),
                  child: const Text('Cancel', style: TextStyle(fontSize: 16)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Obx(
                      () => ElevatedButton(
                    onPressed: widget.vm.isUpdating.value
                        ? null
                        : () async {
                      print('=== SAVING PROFILE ===');
                      print('Name: ${widget.nameController.text.trim()}');
                      print('Has Image: ${widget.selectedImageFile != null}');

                      final success = await widget.vm.updateProfile(
                        name: widget.nameController.text.trim(),
                        profileImageFile: widget.selectedImageFile,
                      );

                      if (success && mounted) {
                        if (widget.nameController.text.trim().isNotEmpty) {
                          await SharedPrefsHelper.setUserName(
                            widget.nameController.text.trim(),
                          );
                        }
                        Get.back();
                        if (widget.context.mounted) {
                          Navigator.pop(widget.context, true);
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: widget.vm.isUpdating.value
                        ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                        : const Text(
                      'Save Changes',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}

// ============================================================
// Menu Item Widget
// ============================================================

class others extends StatelessWidget {
  final String title;
  final dynamic icon;
  final VoidCallback onTap;
  final Color? color;

  const others({
    super.key,
    required this.title,
    required this.icon,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        child: Row(
          children: [
            if (icon is String)
              SvgPicture.asset(
                icon as String,
                height: 24,
                width: 24,
                colorFilter: const ColorFilter.mode(Colors.black, BlendMode.srcIn),
              ),
            if (icon is IconData)
              Icon(
                icon as IconData,
                size: 24,
                color: Colors.black,
              ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(color: color ?? Colors.black, fontSize: 15),
              ),
            ),
            const Icon(Icons.chevron_right, size: 20, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// Responsive Wrapper Widget
// ============================================================

Widget responsiveWrapper({
  required Widget child,
  double maxWidth = 600,
  EdgeInsetsGeometry? padding,
}) {
  return LayoutBuilder(
    builder: (context, constraints) {
      final width = constraints.maxWidth;
      if (width <= maxWidth) {
        return Padding(
          padding: padding ?? const EdgeInsets.symmetric(horizontal: 16),
          child: child,
        );
      }
      return Center(
        child: Container(
          width: maxWidth,
          padding: padding ?? const EdgeInsets.symmetric(horizontal: 24),
          child: child,
        ),
      );
    },
  );
}

// ============================================================
// Points and Wallet Card
// ============================================================

class PointsCard extends StatelessWidget {
  final int points;
  final double walletBalance;
  final VoidCallback onRedeem;
  final VoidCallback onRefreshWallet;

  const PointsCard({
    super.key,
    required this.points,
    required this.walletBalance,
    required this.onRedeem,
    required this.onRefreshWallet,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green.shade400, Colors.green.shade600],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            blurRadius: 15,
            color: Colors.black26,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "My Wallet",
                style: TextStyle(fontSize: 13, color: Colors.white70),
              ),
              GestureDetector(
                onTap: onRefreshWallet,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    Icons.refresh,
                    size: 16,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              SvgPicture.asset('assets/icons/coin.svg', height: 40, width: 40),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "$points",
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const Text(
                    "Points",
                    style: TextStyle(fontSize: 11, color: Colors.white70),
                  ),
                ],
              ),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    "₹${walletBalance.toStringAsFixed(2)}",
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const Text(
                    "Balance",
                    style: TextStyle(fontSize: 11, color: Colors.white70),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: onRedeem,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 10,
                      horizontal: 16,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(
                      child: Text(
                        "Redeem Points",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    final coinVm = Get.find<CoinViewModel>();
                    coinVm.loadCoinData();
                    Get.to(() => const CoinTransactionsView());
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 10,
                      horizontal: 16,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(
                      child: Text(
                        "View History",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ============================================================
// Refer and Earn Card
// ============================================================

Widget referEarnCard({
  required String image,
  required String code,
  required VoidCallback onCopy,
}) {
  Future<void> shareApp(String code) async {
    try {
      final playStoreLink =
          'https://play.google.com/store/apps/details?id=com.book_your_turf.app&referral_code=$code';
      final customSchemeLink = 'book_your_turf://refer/$code';

      print('📤 Sharing referral code: $code');
      print('🔗 Play Store Link: $playStoreLink');
      print('🔗 Custom Scheme Link: $customSchemeLink');

      final byteData = await rootBundle.load('assets/images/share.png');
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/share.jpg');
      await file.writeAsBytes(byteData.buffer.asUint8List());

      final message = '''
🔥 Book Your Turf App!

🎁 Use my referral code: $code

👉 Click here to download the app:
$playStoreLink

📱 If you already have the app, 
$customSchemeLink

✨ Get ₹100 bonus on your first booking!
🏏⚽🏸 Book Cricket, Football, Badminton & more!

Download now and start playing! 🚀
''';

      await SharePlus.instance.share(
        ShareParams(text: message, files: [XFile(file.path)]),
      );

      print('✅ Share completed successfully');

    } catch (e) {
      print('❌ Error sharing: $e');
      final playStoreLink =
          'https://play.google.com/store/apps/details?id=com.book_your_turf.app&referral_code=$code';
      final message = '''
🔥 Book Your Turf App!

🎁 Use my referral code: $code

👉 Download: $playStoreLink

Get ₹100 bonus on your first booking!
''';
      await SharePlus.instance.share(ShareParams(text: message));
    }
  }

  return LayoutBuilder(
    builder: (context, constraints) {
      bool isTablet = constraints.maxWidth > 600;
      Widget card = Container(
        margin: EdgeInsets.symmetric(
          horizontal: isTablet ? 0 : 16,
          vertical: 10,
        ),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [BoxShadow(blurRadius: 10, color: Colors.black12)],
        ),
        child: Column(
          children: [
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SvgPicture.asset(
                    image,
                    height: 55,
                    width: 55,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Text(
                        "REFER & EARN!",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        "Invite your friends and you both get 10 points",
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SvgPicture.asset(
                    'assets/icons/gift.svg',
                    height: 55,
                    width: 55,
                    fit: BoxFit.cover,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              height: 55,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      code,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: onCopy,
                    icon: const Icon(Icons.copy, size: 20, color: Colors.grey),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                InkWell(
                  onTap: () => shareApp(code),
                  child: Container(
                    height: 40,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(
                      child: Text(
                        'Invite Now',
                        style: TextStyle(
                          color: AppColors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
      if (isTablet) return Center(child: SizedBox(width: 600, child: card));
      return card;
    },
  );
}