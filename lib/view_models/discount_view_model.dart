// lib/view_models/discount_view_model.dart
// ✅ Complete as per API documentation
// ✅ Full Payment Discount Support

import 'dart:convert';
import 'package:get/get.dart';
import 'package:dio/dio.dart';
import '../models/discount_model.dart';
import '../models/slot_model.dart';
import '../services/shared_prefs_helper.dart';
import '../routes/app_routes.dart';

class DiscountViewModel extends GetxController {
  final adminDiscounts = <DiscountModel>[].obs;
  final partnerDiscounts = <DiscountModel>[].obs;
  final allDiscounts = <DiscountModel>[].obs;

  final selectedAdminDiscountId = Rx<int?>(null);
  final selectedPartnerDiscountId = Rx<int?>(null);

  final isLoading = false.obs;
  final errorMessage = ''.obs;

  static String? _lastCacheKey;
  static List<DiscountModel>? _cachedAdminDiscounts;
  static List<DiscountModel>? _cachedPartnerDiscounts;
  static DateTime? _lastFetchTime;
  static const _cacheDuration = Duration(seconds: 30);

  @override
  void onInit() {
    super.onInit();
    print('📋 DiscountViewModel initialized');
  }

  Future<Map<String, List<DiscountModel>>> fetchApplicableDiscounts({
    required int turfId,
    required DateTime date,
    required List<SlotModel> slots,
    required double totalAmount,
    bool forceRefresh = false,
  }) async {
    final token = SharedPrefsHelper.getToken();
    if (token == null || token.isEmpty) {
      print('🚫 No token, skipping discounts fetch');
      return {'admin': [], 'partner': []};
    }

    if (!SharedPrefsHelper.isTokenValid()) {
      print('⚠️ Token expired, redirecting to login');
      await SharedPrefsHelper.clearToken();
      Get.offAllNamed(AppRoutes.login);
      return {'admin': [], 'partner': []};
    }

    final slotsHash = slots.map((s) => '${s.startTime}_${s.endTime}').join(',');
    final cacheKey = '$turfId-${date.toIso8601String()}-$slotsHash-$totalAmount';

    if (!forceRefresh && _lastCacheKey == cacheKey &&
        _cachedAdminDiscounts != null && _cachedPartnerDiscounts != null) {
      if (_lastFetchTime != null) {
        final age = DateTime.now().difference(_lastFetchTime!);
        if (age < _cacheDuration) {
          print('⏭️ Discounts cached (${age.inSeconds}s old) - using cache');
          adminDiscounts.value = _cachedAdminDiscounts!;
          partnerDiscounts.value = _cachedPartnerDiscounts!;
          allDiscounts.value = [..._cachedAdminDiscounts!, ..._cachedPartnerDiscounts!];
          return {
            'admin': _cachedAdminDiscounts!,
            'partner': _cachedPartnerDiscounts!,
          };
        }
      }
    }

    if (forceRefresh) {
      print('🔄 Force refresh - clearing discount cache');
      _lastCacheKey = null;
      _cachedAdminDiscounts = null;
      _cachedPartnerDiscounts = null;
      _lastFetchTime = null;
    }

    _lastCacheKey = cacheKey;
    isLoading.value = true;
    errorMessage.value = '';

    try {
      final slotsJson = slots.map((slot) => ({
        'start_time': slot.startTime,
      })).toList();

      final dio = Get.find<Dio>();

      print('📡 Fetching discounts with params:');
      print('   turf_id: $turfId');
      print('   date: ${date.toIso8601String().split('T').first}');
      print('   slots: $slotsJson');
      print('   amount: ${totalAmount.toStringAsFixed(2)}');

      final response = await dio.get(
        '/user/applicable-discounts/',
        queryParameters: {
          'turf_id': turfId,
          'date': date.toIso8601String().split('T').first,
          'slots': jsonEncode(slotsJson),
          'amount': totalAmount.toStringAsFixed(2),
        },
      );

      print('📥 Discount API Response: ${response.data}');

      if (response.data['result'] == 'success') {
        final data = response.data['data'];

        final adminList = (data['admin_discounts'] as List?)?.map((json) =>
            DiscountModel.fromJson(json)
        ).toList() ?? [];

        final partnerList = (data['partner_discounts'] as List?)?.map((json) =>
            DiscountModel.fromJson(json)
        ).toList() ?? [];

        // ✅ Log full payment discounts found
        final fullAdminDiscounts = adminList.where((d) => d.applicablePaymentType == 'full').toList();
        final fullPartnerDiscounts = partnerList.where((d) => d.applicablePaymentType == 'full').toList();

        print('🔥 Full Payment Admin Discounts: ${fullAdminDiscounts.length}');
        for (var d in fullAdminDiscounts) {
          print('   ✅ ${d.name}');
        }
        print('🔥 Full Payment Partner Discounts: ${fullPartnerDiscounts.length}');
        for (var d in fullPartnerDiscounts) {
          print('   ✅ ${d.name}');
        }

        _cachedAdminDiscounts = adminList;
        _cachedPartnerDiscounts = partnerList;
        _lastFetchTime = DateTime.now();

        adminDiscounts.value = adminList;
        partnerDiscounts.value = partnerList;
        allDiscounts.value = [...adminList, ...partnerList];

        print('✅ Fetched ${adminList.length} admin discounts and ${partnerList.length} partner discounts');

        if (adminList.isNotEmpty) {
          for (var d in adminList) {
            print('   Admin: ${d.name}: ${d.getDisplayText()} (${d.source}) - ${d.applicablePaymentType ?? "both"} - ${d.discountApplicationType ?? "overall"}');
          }
        }
        if (partnerList.isNotEmpty) {
          for (var d in partnerList) {
            print('   Partner: ${d.name}: ${d.getDisplayText()} (${d.source}) - ${d.applicablePaymentType ?? "both"} - ${d.discountApplicationType ?? "overall"}');
          }
        }

        // ✅ NO AUTO-SELECTION
        selectedAdminDiscountId.value = null;
        selectedPartnerDiscountId.value = null;

        return {
          'admin': adminList,
          'partner': partnerList,
        };
      } else {
        final msg = response.data['message'] ?? 'Failed to fetch discounts';
        errorMessage.value = msg;
        print('❌ API error: $msg');
        return {'admin': [], 'partner': []};
      }
    } on DioException catch (e) {
      print('❌ Error fetching discounts: $e');
      if (e.response?.statusCode == 401) {
        print('⚠️ Token expired during API call, redirecting to login');
        await SharedPrefsHelper.clearToken();
        Get.offAllNamed(AppRoutes.login);
      }
      errorMessage.value = 'Could not load discounts';
      return {'admin': [], 'partner': []};
    } finally {
      isLoading.value = false;
    }
  }

  void selectAdminDiscount(int? discountId) {
    selectedAdminDiscountId.value = discountId;
    print('✅ Selected admin discount ID: $discountId');
  }

  void selectPartnerDiscount(int? discountId) {
    selectedPartnerDiscountId.value = discountId;
    print('✅ Selected partner discount ID: $discountId');
  }

  DiscountModel? get selectedAdminDiscount {
    if (selectedAdminDiscountId.value == null) return null;
    try {
      return adminDiscounts.firstWhere((d) => d.id == selectedAdminDiscountId.value);
    } catch (e) {
      return null;
    }
  }

  DiscountModel? get selectedPartnerDiscount {
    if (selectedPartnerDiscountId.value == null) return null;
    try {
      return partnerDiscounts.firstWhere((d) => d.id == selectedPartnerDiscountId.value);
    } catch (e) {
      return null;
    }
  }

  double get totalDiscountAmount {
    double total = 0;
    final admin = selectedAdminDiscount;
    final partner = selectedPartnerDiscount;
    if (admin?.calculatedDiscount != null) total += admin!.calculatedDiscount!;
    if (partner?.calculatedDiscount != null) total += partner!.calculatedDiscount!;
    return total;
  }

  double get overallDiscountAmount {
    double total = 0;
    final admin = selectedAdminDiscount;
    final partner = selectedPartnerDiscount;
    if (admin != null &&
        admin.discountApplicationType == 'overall' &&
        admin.calculatedDiscount != null) {
      total += admin.calculatedDiscount!;
    }
    if (partner != null &&
        partner.discountApplicationType == 'overall' &&
        partner.calculatedDiscount != null) {
      total += partner.calculatedDiscount!;
    }
    return total;
  }

  double get payableDiscountAmount {
    double total = 0;
    final admin = selectedAdminDiscount;
    final partner = selectedPartnerDiscount;
    if (admin != null &&
        admin.discountApplicationType == 'payable' &&
        admin.calculatedDiscount != null) {
      total += admin.calculatedDiscount!;
    }
    if (partner != null &&
        partner.discountApplicationType == 'payable' &&
        partner.calculatedDiscount != null) {
      total += partner.calculatedDiscount!;
    }
    return total;
  }

  bool get hasSelectedDiscount {
    return selectedAdminDiscountId.value != null || selectedPartnerDiscountId.value != null;
  }

  void clearAllSelections() {
    selectedAdminDiscountId.value = null;
    selectedPartnerDiscountId.value = null;
    print('✅ Cleared all discount selections');
  }

  void toggleAdminDiscount(int discountId) {
    if (selectedAdminDiscountId.value == discountId) {
      selectAdminDiscount(null);
    } else {
      selectAdminDiscount(discountId);
    }
  }

  void togglePartnerDiscount(int discountId) {
    if (selectedPartnerDiscountId.value == discountId) {
      selectPartnerDiscount(null);
    } else {
      selectPartnerDiscount(discountId);
    }
  }

  List<DiscountModel> getDiscountsForPaymentType(String paymentType, {String source = 'all'}) {
    List<DiscountModel> discounts = [];
    if (source == 'admin' || source == 'all') {
      discounts.addAll(adminDiscounts.where((d) => d.isApplicableForPaymentType(paymentType)));
    }
    if (source == 'partner' || source == 'all') {
      discounts.addAll(partnerDiscounts.where((d) => d.isApplicableForPaymentType(paymentType)));
    }
    return discounts;
  }

  static void resetCache() {
    _lastCacheKey = null;
    _cachedAdminDiscounts = null;
    _cachedPartnerDiscounts = null;
    _lastFetchTime = null;
  }

  @override
  void onClose() {
    super.onClose();
  }
}