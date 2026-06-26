// views/device_management_view.dart
// ✅ User App - Complete Device Management Screen

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../services/device_manager.dart';
import '../services/shared_prefs_helper.dart';
import '../routes/app_routes.dart';

class DeviceManagementView extends StatefulWidget {
  const DeviceManagementView({Key? key}) : super(key: key);

  @override
  State<DeviceManagementView> createState() => _DeviceManagementViewState();
}

class _DeviceManagementViewState extends State<DeviceManagementView> {
  final DeviceManager _deviceManager = Get.find<DeviceManager>();
  bool _isMounted = false;
  String _currentDeviceId = 'Loading...';

  @override
  void initState() {
    super.initState();
    _isMounted = true;
    _loadDeviceId();
    _loadDevices();
  }

  @override
  void dispose() {
    _isMounted = false;
    super.dispose();
  }

  Future<void> _loadDeviceId() async {
    try {
      final deviceId = await _deviceManager.getDeviceId();
      if (_isMounted) {
        setState(() {
          _currentDeviceId = deviceId;
        });
      }
      print('📱 Current Device ID: $deviceId');
    } catch (e) {
      print('❌ Error loading device ID: $e');
    }
  }

  Future<void> _loadDevices() async {
    if (!_isMounted) return;
    print('🔄 Loading devices...');
    try {
      await _deviceManager.fetchDevices();
      if (_isMounted) {
        setState(() {});
      }
      print('✅ Devices loaded: ${_deviceManager.devices.length}');
    } catch (e) {
      print('❌ Error loading devices: $e');
    }
  }

  void _showSnackBar(String message, Color color) {
    if (!_isMounted) return;
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: color,
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      print('⚠️ Could not show snackbar: $e');
    }
  }

  // ✅ LOGOUT DEVICE DIALOG
  Future<void> _showLogoutDeviceDialog(DeviceInfo device) async {
    if (!_isMounted) return;

    final isCurrentDevice = await _isCurrentDevice(device);
    print('🔴 Logout clicked for: ${device.deviceName} (ID: ${device.id})');
    print('🔴 Is current device: $isCurrentDevice');

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            _buildDeviceIcon(device.platform, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                isCurrentDevice ? 'Logout This Device?' : 'Logout Device?',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              device.deviceName,
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: device.platform.toLowerCase() == 'android'
                    ? Colors.green.shade50
                    : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${device.platform.toUpperCase()} • ${device.osVersion}',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
              ),
            ),
            if (device.location != null && device.location!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.location_on, size: 14, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      device.location!,
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            Divider(color: Colors.grey.shade200),
            const SizedBox(height: 12),
            Text(
              isCurrentDevice
                  ? '⚠️ WARNING: Logging out this device will log you out of THIS app. You will need to login again.'
                  : 'This device will be logged out and will no longer receive notifications from your account.',
              style: TextStyle(
                color: isCurrentDevice ? Colors.red.shade700 : Colors.grey.shade600,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.fingerprint, size: 14, color: Colors.green.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'ID: ${device.deviceId}',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.green.shade700,
                        fontFamily: 'monospace',
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              print('❌ User cancelled logout');
              Navigator.pop(dialogContext);
            },
            child: const Text('Cancel', style: TextStyle(fontSize: 15)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              print('✅ User confirmed logout');

              // Show loading
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (loadingContext) => AlertDialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Logging out ${device.deviceName}...',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Please wait',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              );

              bool success = false;
              try {
                success = await _deviceManager.logoutDevice(device.id);
                print('🔴 Logout result: $success');
              } catch (e) {
                print('❌ Logout exception: $e');
                success = false;
              }

              // Pop loading
              if (mounted) {
                try {
                  Navigator.of(context).pop();
                } catch (e) {
                  print('⚠️ Could not pop loading: $e');
                }
              }

              if (!mounted) return;

              if (success) {
                print('✅ Logout successful');

                if (isCurrentDevice) {
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (context) => AlertDialog(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      title: const Row(
                        children: [
                          Icon(Icons.check_circle, color: Colors.green),
                          SizedBox(width: 8),
                          Text('Logged Out'),
                        ],
                      ),
                      content: const Text(
                        'This device has been logged out successfully. You will be redirected to the login screen.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () async {
                            try {
                              Navigator.pop(context);
                              await SharedPrefsHelper.clearAll();
                              if (mounted) {
                                Get.offAllNamed(AppRoutes.login);
                              }
                            } catch (e) {
                              print('❌ Error during logout: $e');
                            }
                          },
                          child: const Text('OK'),
                        ),
                      ],
                    ),
                  );
                } else {
                  try {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('${device.deviceName} has been logged out'),
                        backgroundColor: Colors.green,
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  } catch (e) {
                    print('⚠️ Could not show snackbar: $e');
                  }
                  await _loadDevices();
                }
              } else if (mounted) {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    title: const Row(
                      children: [
                        Icon(Icons.error, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Failed'),
                      ],
                    ),
                    content: const Text(
                      'Failed to logout device. Please try again.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('OK'),
                      ),
                    ],
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: isCurrentDevice ? Colors.red : Colors.green,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(
              isCurrentDevice ? 'Logout This Device' : 'Logout',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  // ✅ LOGOUT ALL OTHER DEVICES
  Future<void> _showLogoutAllOtherDevicesDialog() async {
    if (!_isMounted) return;

    final devices = _deviceManager.devices;
    final currentDeviceId = await _deviceManager.getDeviceId();
    final otherDevicesList = devices.where((d) => d.deviceId != currentDeviceId).toList();

    print('🔴 Logout All Others - Current ID: $currentDeviceId');
    print('🔴 Other devices: ${otherDevicesList.length}');

    if (otherDevicesList.isEmpty) {
      _showSnackBar('No other devices found', Colors.orange);
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.logout, color: Colors.orange, size: 28),
            SizedBox(width: 12),
            Text('Logout All Other Devices?', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This will logout ${otherDevicesList.length} other device${otherDevicesList.length > 1 ? 's' : ''}.',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 12),
            ...otherDevicesList.map((device) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  _buildDeviceIcon(device.platform, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      device.deviceName,
                      style: const TextStyle(fontSize: 14),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            )),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.orange.shade700, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'They will no longer receive notifications from your account.',
                      style: TextStyle(fontSize: 12, color: Colors.orange.shade700),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);

              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => AlertDialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Logging out all devices...',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'This may take a few seconds',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              );

              final count = await _deviceManager.logoutAllOtherDevices();

              if (mounted) {
                try {
                  Navigator.of(context).pop();
                } catch (e) {
                  print('⚠️ Could not pop loading: $e');
                }
              }

              if (!mounted) return;

              try {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Logged out $count device${count > 1 ? 's' : ''}'),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                print('⚠️ Could not show snackbar: $e');
              }
              await _loadDevices();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Logout All Others', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<bool> _isCurrentDevice(DeviceInfo device) async {
    try {
      final currentDeviceId = await _deviceManager.getDeviceId();
      return device.deviceId == currentDeviceId;
    } catch (e) {
      print('❌ Error checking current device: $e');
      return false;
    }
  }

  Widget _buildDeviceIcon(String platform, {double size = 28}) {
    switch (platform.toLowerCase()) {
      case 'android':
        return Icon(Icons.android, color: Colors.green, size: size);
      case 'ios':
        return Icon(Icons.apple, color: Colors.grey.shade700, size: size);
      default:
        return Icon(Icons.devices, color: Colors.blue, size: size);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Devices'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _loadDevices,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
          Obx(() {
            if (_deviceManager.devices.length > 1) {
              return IconButton(
                onPressed: _showLogoutAllOtherDevicesDialog,
                icon: const Icon(Icons.logout),
                tooltip: 'Logout All Others',
              );
            }
            return const SizedBox.shrink();
          }),
        ],
      ),
      body: Obx(() {
        // ✅ Loading state
        if (_deviceManager.isLoading.value && _deviceManager.devices.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Loading devices...'),
              ],
            ),
          );
        }

        // ✅ Empty state
        if (_deviceManager.devices.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.offline_pin_outlined, size: 64, color: Colors.grey.shade400),
                const SizedBox(height: 16),
                Text(
                  'No devices found',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                ),
                const SizedBox(height: 8),
                Text(
                  'Your current device will appear here after login',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: _loadDevices,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          );
        }

        // ✅ Device list
        return RefreshIndicator(
          onRefresh: _loadDevices,
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _deviceManager.devices.length,
            itemBuilder: (context, index) {
              final device = _deviceManager.devices[index];
              return FutureBuilder<bool>(
                future: _isCurrentDevice(device),
                builder: (context, snapshot) {
                  final isCurrent = snapshot.data ?? false;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: isCurrent
                            ? Border.all(color: Colors.green, width: 2)
                            : null,
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        leading: _buildDeviceIcon(device.platform),
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                device.deviceName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (isCurrent)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade100,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Text(
                                  'Current',
                                  style: TextStyle(
                                    color: Colors.green.shade700,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: device.platform.toLowerCase() == 'android'
                                        ? Colors.green.shade50
                                        : Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    device.platform.toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w500,
                                      color: device.platform.toLowerCase() == 'android'
                                          ? Colors.green.shade700
                                          : Colors.grey.shade700,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    device.osVersion,
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (device.location != null && device.location!.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Icon(Icons.location_on, size: 12, color: Colors.grey.shade500),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      device.location!,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade600,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Icon(Icons.schedule, size: 12, color: Colors.grey.shade500),
                                const SizedBox(width: 4),
                                Text(
                                  // ✅ Uses formattedDate getter
                                  'Added ${device.formattedDate}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade500,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    // ✅ Uses activeStatusColor getter
                                    color: device.activeStatusColor,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  // ✅ Uses activeStatusText getter
                                  device.activeStatusText,
                                  style: TextStyle(
                                    fontSize: 11,
                                    // ✅ Uses activeStatusColor getter
                                    color: device.activeStatusColor,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Icon(Icons.fingerprint, size: 12, color: Colors.grey.shade400),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    'ID: ${device.deviceId.substring(0, device.deviceId.length > 8 ? 8 : device.deviceId.length)}...',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey.shade400,
                                      fontFamily: 'monospace',
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        trailing: isCurrent
                            ? IconButton(
                          icon: const Icon(Icons.info_outline, color: Colors.grey),
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Current Device'),
                                content: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Device: ${device.deviceName}'),
                                    const SizedBox(height: 8),
                                    Text('Platform: ${device.platform.toUpperCase()}'),
                                    const SizedBox(height: 4),
                                    Text('OS Version: ${device.osVersion}'),
                                    if (device.location != null && device.location!.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text('Location: ${device.location}'),
                                    ],
                                    const SizedBox(height: 8),
                                    // ✅ Uses activeStatusText getter
                                    Text('Status: ${device.activeStatusText}'),
                                    const SizedBox(height: 8),
                                    // ✅ Uses formattedDate getter
                                    Text('Added: ${device.formattedDate}'),
                                    const SizedBox(height: 8),
                                    Divider(),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Icon(Icons.fingerprint, size: 14, color: Colors.grey),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            'Device ID: ${device.deviceId}',
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: Colors.grey.shade600,
                                              fontFamily: 'monospace',
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text('OK'),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      Navigator.pop(context);
                                      Clipboard.setData(ClipboardData(text: device.deviceId));
                                      _showSnackBar('Device ID copied!', Colors.green);
                                    },
                                    child: const Text('Copy ID'),
                                  ),
                                ],
                              ),
                            );
                          },
                          tooltip: 'Device Info',
                        )
                            : IconButton(
                          icon: const Icon(Icons.logout, color: Colors.red),
                          onPressed: () => _showLogoutDeviceDialog(device),
                          tooltip: 'Logout device',
                        ),
                        onTap: () {
                          if (!isCurrent) {
                            _showLogoutDeviceDialog(device);
                          }
                        },
                      ),
                    ),
                  );
                },
              );
            },
          ),
        );
      }),
    );
  }
}