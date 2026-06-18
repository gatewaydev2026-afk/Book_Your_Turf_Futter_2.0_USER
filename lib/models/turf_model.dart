// models/turf_model.dart
import 'dart:convert';

class TurfModel {
  final int id;
  final String name;
  final String address;
  final String gameType;
  final String description;
  final String? achievements;
  final int maxPersons;
  final int courts;
  final Map<String, dynamic>? facilities;
  final String openTime;
  final String closeTime;
  final double? latitude;
  final double? longitude;
  final String state;
  final String district;
  final String pincode;
  final List<String> images;
  final String turfCode;
  final bool isFavorite;
  final bool isVerified;
  final String type;
  final String status;
  final bool isBookable;
  final String? phoneNumber;

  // Advance payment rules
  final String advanceType;
  final String advanceValue;
  final int minSlots;

  TurfModel({
    required this.id,
    required this.name,
    required this.address,
    required this.gameType,
    required this.description,
    this.achievements,
    required this.maxPersons,
    required this.courts,
    this.facilities,
    required this.openTime,
    required this.closeTime,
    this.latitude,
    this.longitude,
    required this.state,
    required this.district,
    required this.pincode,
    required this.images,
    required this.turfCode,
    this.isFavorite = false,
    this.isVerified = false,
    this.type = 'real',
    this.status = '',
    this.isBookable = true,
    this.phoneNumber,
    this.advanceType = 'percentage',
    this.advanceValue = '0',
    this.minSlots = 1,
  });

  factory TurfModel.fromJson(Map<String, dynamic> json) {
    print('\n╔════════════════════════════════════════════════════════════╗');
    print('║                 TURF MODEL PARSING START                    ║');
    print('╚════════════════════════════════════════════════════════════╝');

    print('\n📦 RAW JSON DATA RECEIVED:');
    print('${jsonEncode(json)}\n');

    print('🔍 PARSING TURF: ${json['name']}');
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

    // ========== CHECK EACH FIELD ==========
    print('\n📌 BASIC FIELDS:');
    print('   id: ${json['id']}');
    print('   name: ${json['name']}');
    print('   game_type: ${json['game_type']}');
    print('   address: ${json['address']}');

    print('\n📌 ADVANCE RULES FIELDS (CRITICAL):');
    print('   advance_type: "${json['advance_type']}"');
    print('   advance_value: "${json['advance_value']}"');
    print('   min_slots: ${json['min_slots']}');
    print('   commission_type: ${json['commission_type']}');
    print('   commission_value: ${json['commission_value']}');

    // Check if fields exist
    print('\n📌 FIELD EXISTENCE CHECK:');
    print('   advance_type exists? ${json.containsKey('advance_type')}');
    print('   advance_value exists? ${json.containsKey('advance_value')}');
    print('   min_slots exists? ${json.containsKey('min_slots')}');

    // Parse advance fields - DIRECT from API
    String advanceType = json['advance_type']?.toString() ?? 'percentage';
    String advanceValue = json['advance_value']?.toString() ?? '0';
    int minSlots = json['min_slots'] ?? 1;

    print('\n📌 PARSED ADVANCE VALUES:');
    print('   advanceType: "$advanceType"');
    print('   advanceValue: "$advanceValue"');
    print('   minSlots: $minSlots');

    // Parse images
    List<String> imageList = [];
    if (json['images'] != null) {
      if (json['images'] is String) {
        imageList = [json['images'] as String];
      } else if (json['images'] is List) {
        imageList = List<String>.from(json['images']);
      }
    }
    print('\n📌 IMAGES: ${imageList.length} images');

    // Parse times
    String openTime = _parseTimeFromApi(json['open_time'] ?? json['opening_time'], defaultTime: '06:00');
    String closeTime = _parseTimeFromApi(json['close_time'] ?? json['closing_time'], defaultTime: '23:00');
    print('\n📌 TIMES: open=$openTime, close=$closeTime');

    // Parse facilities
    Map<String, dynamic>? facilitiesMap;
    if (json['facilities'] != null && json['facilities'] is Map) {
      facilitiesMap = Map<String, dynamic>.from(json['facilities']);
      print('\n📌 FACILITIES: ${facilitiesMap.keys.join(', ')}');
    }

    final turf = TurfModel(
      id: json['id'] ?? 0,
      name: json['name'] ?? json['pane_type'] ?? 'Unknown Turf',
      address: json['address'] ?? '',
      gameType: json['pane_type'] ?? json['game_type'] ?? '',
      description: json['description'] ?? '',
      achievements: json['achievement'] ?? json['achievements'],
      maxPersons: json['max_persons'] ?? 0,
      courts: json['counts'] ?? json['courts'] ?? 1,
      facilities: facilitiesMap,
      openTime: openTime,
      closeTime: closeTime,
      latitude: json['latitude'] != null ? double.tryParse(json['latitude'].toString()) : null,
      longitude: json['longitude'] != null ? double.tryParse(json['longitude'].toString()) : null,
      state: json['state'] ?? '',
      district: json['district'] ?? '',
      pincode: json['pincode']?.toString() ?? '',
      images: imageList,
      turfCode: json['turf_code'] ?? '',
      isFavorite: json['is_favorite'] ?? false,
      isVerified: (json['type'] ?? 'real') == 'real' && (json['status'] ?? '') == 'Approved',
      type: json['type'] ?? 'real',
      status: json['status'] ?? '',
      isBookable: json['is_bookable'] ?? (json['type'] ?? 'real') == 'real',
      phoneNumber: json['phone_number']?.toString(),
      advanceType: advanceType,
      advanceValue: advanceValue,
      minSlots: minSlots,
    );

    print('\n╔════════════════════════════════════════════════════════════╗');
    print('║                 TURF MODEL PARSING COMPLETE                 ║');
    print('╚════════════════════════════════════════════════════════════╝');
    print('\n✅ FINAL TURF VALUES:');
    print('   Name: ${turf.name}');
    print('   advanceType: ${turf.advanceType}');
    print('   advanceValue: ${turf.advanceValue}');
    print('   minSlots: ${turf.minSlots}');
    print('   getAdvanceDisplayText(): ${turf.getAdvanceDisplayText()}');
    print('   getMinSlotsDisplayText(): ${turf.getMinSlotsDisplayText()}');
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

    return turf;
  }

  static String _parseTimeFromApi(dynamic timeValue, {required String defaultTime}) {
    if (timeValue == null) return defaultTime;
    String timeStr = timeValue.toString().trim();
    if (timeStr.isEmpty || timeStr == 'null' || timeStr == 'NULL') return defaultTime;
    if (timeStr.contains(':')) {
      final parts = timeStr.split(':');
      if (parts.length >= 2) {
        int hour = 0, minute = 0;
        try { hour = int.parse(parts[0].padLeft(2, '0')); } catch (e) { hour = 0; }
        String minuteStr = parts[1];
        if (minuteStr.contains(',')) minuteStr = minuteStr.split(',').first;
        if (minuteStr.contains('.')) minuteStr = minuteStr.split('.').first;
        if (minuteStr.length > 2) minuteStr = minuteStr.substring(0, 2);
        try { minute = int.parse(minuteStr); } catch (e) { minute = 0; }
        if (hour >= 0 && hour <= 23 && minute >= 0 && minute <= 59) {
          return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
        }
      }
    }
    final match = RegExp(r'(\d{1,2}):(\d{2})').firstMatch(timeStr);
    if (match != null) {
      return '${match.group(1)!.padLeft(2, '0')}:${match.group(2)}';
    }
    return defaultTime;
  }

  bool get showVerifiedBadge => type == 'real' && status == 'Approved';
  bool get hasValidTimes => openTime.isNotEmpty && closeTime.isNotEmpty;

  String getAdvanceDisplayText() {
    print('\n🔍 getAdvanceDisplayText() CALLED');
    print('   advanceType: $advanceType');
    print('   advanceValue: $advanceValue');

    double value = double.tryParse(advanceValue) ?? 0;
    print('   parsed value: $value');

    if (advanceType == 'fixed') {
      if (value <= 0) {
        print('   returning: "Pay at venue (No advance)"');
        return 'Pay at venue (No advance)';
      }
      String result = 'Advance: ₹${value.toStringAsFixed(0)} per slot';
      print('   returning: "$result"');
      return result;
    } else {
      if (value <= 0) {
        print('   returning: "Pay at venue (No advance)"');
        return 'Pay at venue (No advance)';
      }
      String result = 'Advance: ${value.toStringAsFixed(0)}% of total';
      print('   returning: "$result"');
      return result;
    }
  }

  String getMinSlotsDisplayText() {
    print('\n🔍 getMinSlotsDisplayText() CALLED');
    print('   minSlots: $minSlots');
    String result = 'Minimum ${minSlots} slot${minSlots > 1 ? 's' : ''} required';
    print('   returning: "$result"');
    return result;
  }

  void debugPrintAll() {
    print('\n╔════════════════════════════════════════════════════════════╗');
    print('║                 TURF MODEL DEBUG OUTPUT                     ║');
    print('╚════════════════════════════════════════════════════════════╝');
    print('   id: $id');
    print('   name: $name');
    print('   advanceType: $advanceType');
    print('   advanceValue: $advanceValue');
    print('   minSlots: $minSlots');
    print('   getAdvanceDisplayText(): ${getAdvanceDisplayText()}');
    print('   getMinSlotsDisplayText(): ${getMinSlotsDisplayText()}');
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
  }
}