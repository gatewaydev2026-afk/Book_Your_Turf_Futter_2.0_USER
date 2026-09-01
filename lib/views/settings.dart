import 'dart:io';
import 'package:book_your_turf/view_models/profile_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:get/get.dart';
import 'package:system_media_picker/system_media_picker.dart';

class EditProfileView extends GetView<ProfileViewModel> {
  EditProfileView({Key? key}) : super(key: key);

  final TextEditingController nameController = TextEditingController();
  final Rx<File?> selectedImage = Rx<File?>(null);

  // ✅ SystemMediaPicker - No permissions required
  final SystemMediaPicker _picker = SystemMediaPicker();

  @override
  Widget build(BuildContext context) {
    // Initialize controller with current name
    nameController.text = controller.name.value;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        backgroundColor: Colors.white,
        elevation: 1,
        centerTitle: false,
        actions: [
          Obx(() => TextButton(
            onPressed: controller.isUpdating.value ? null : _updateProfile,
            child: Text(
              'Save',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: controller.isUpdating.value ? Colors.grey : Colors.green,
              ),
            ),
          )),
        ],
      ),
      body: Obx(() => Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // Profile Image Section
                Center(
                  child: GestureDetector(
                    onTap: _showImagePickerOptions,
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.green.shade300,
                          width: 3,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: Obx(() {
                          if (selectedImage.value != null) {
                            return Image.file(
                              selectedImage.value!,
                              fit: BoxFit.cover,
                            );
                          } else if (controller.profileImageUrl.value.isNotEmpty) {
                            return Image.network(
                              controller.profileImageUrl.value,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return _buildDefaultAvatar();
                              },
                            );
                          } else {
                            return _buildDefaultAvatar();
                          }
                        }),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                TextButton.icon(
                  onPressed: _showImagePickerOptions,
                  icon: const Icon(Icons.camera_alt, size: 18),
                  label: const Text('Change Photo'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.green,
                  ),
                ),
                const SizedBox(height: 30),

                // Name Field
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: 'Full Name',
                      labelStyle: TextStyle(color: Colors.grey.shade600),
                      prefixIcon: const Icon(Icons.person_outline, color: Colors.green),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.all(16),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Email Field (Read-only)
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: TextField(
                    controller: TextEditingController(text: controller.email.value),
                    readOnly: true,
                    decoration: InputDecoration(
                      labelText: 'Email',
                      labelStyle: TextStyle(color: Colors.grey.shade600),
                      prefixIcon: const Icon(Icons.email_outlined, color: Colors.grey),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.all(16),
                      suffixIcon: const Icon(Icons.lock_outline, size: 18, color: Colors.grey),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Phone Field (Read-only)
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: TextField(
                    controller: TextEditingController(text: controller.phone.value),
                    readOnly: true,
                    decoration: InputDecoration(
                      labelText: 'Phone Number',
                      labelStyle: TextStyle(color: Colors.grey.shade600),
                      prefixIcon: const Icon(Icons.phone_outlined, color: Colors.grey),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.all(16),
                      suffixIcon: const Icon(Icons.lock_outline, size: 18, color: Colors.grey),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Info Note
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Email and phone number cannot be changed. Contact support for assistance.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (controller.isUpdating.value)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      )),
    );
  }

  Widget _buildDefaultAvatar() {
    return Container(
      color: Colors.grey.shade200,
      child: Icon(
        Icons.person,
        size: 60,
        color: Colors.grey.shade600,
      ),
    );
  }

  void _showImagePickerOptions() {
    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Choose Profile Picture',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            // ✅ Only Gallery option (Camera removed to avoid permissions)
            _buildImagePickerOption(
              icon: Icons.photo_library,
              label: 'Gallery',
              onTap: _pickImage,
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () => Get.back(),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePickerOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 30, color: Colors.green),
          ),
          const SizedBox(height: 8),
          Text(label),
        ],
      ),
    );
  }

  Future<void> _pickImage() async {
    Get.back();
    try {
      // ✅ Using system_media_picker - No permissions needed
      final List<PickedMedia> images = await _picker.pickImages(limit: 1);

      if (images.isNotEmpty) {
        final PickedMedia image = images.first;
        selectedImage.value = File(image.path);
        print('Image picked: ${image.path}');
      } else {
        print('No image selected');
      }
    } catch (e) {
      print('Error picking image: $e');
      Get.snackbar(
        'Error',
        'Failed to pick image',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  Future<void> _updateProfile() async {
    if (nameController.text.trim().isEmpty) {
      Get.snackbar(
        'Error',
        'Name cannot be empty',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }

    final success = await controller.updateProfile(
      name: nameController.text.trim(),
      profileImageFile: selectedImage.value,
    );

    if (success) {
      Get.back();
    }
  }
}