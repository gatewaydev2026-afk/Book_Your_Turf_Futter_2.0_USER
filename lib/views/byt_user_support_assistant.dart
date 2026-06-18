import 'dart:async';

/// Single-file user support assistant for book_your_turf.
///
/// Drop this into a Flutter project and connect [UserSupportRepository]
/// to Firebase/Firestore or Cloud Functions.
///
/// Example:
/// ```dart
/// final assistant = book_your_turfUserSupportAssistant(
///   repository: InMemoryUserSupportRepository.demo(),
/// );
///
/// final session = assistant.startSession(
///   userId: 'user-123',
///   location: 'Coimbatore',
/// );
///
/// final response = await assistant.sendMessage(
///   session: session,
///   message: 'How to book',
/// );
/// ```
///
/// Firebase example:
/// ```dart
/// final assistant = book_your_turfUserSupportAssistant.firebase(
///   firestore: FirebaseFirestore.instance,
/// );
/// ```

double _asDouble(Object? value) {
  if (value is num) {
    return value.toDouble();
  }
  if (value is String) {
    return double.tryParse(value) ?? 0;
  }
  return 0;
}

List<String> _asStringList(Object? value) {
  if (value is Iterable) {
    return value.map((entry) => entry.toString()).toList();
  }
  return const <String>[];
}

Map<String, dynamic> _asStringMap(Object? value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return value.map(
      (key, entry) => MapEntry(key.toString(), entry),
    );
  }
  return const <String, dynamic>{};
}

String _normalizeValue(String value) {
  return value.trim().toLowerCase();
}

enum SupportResponseKind {
  staticAnswer,
  needsInput,
  actionResult,
  actionError,
  authRequired,
  scopeGuardrail,
  fallback,
}

class SupportCallToAction {
  const SupportCallToAction({
    required this.label,
    required this.intent,
    this.deepLinkTarget,
  });

  final String label;
  final String intent;
  final String? deepLinkTarget;

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'label': label,
      'intent': intent,
      if (deepLinkTarget != null) 'deep_link_target': deepLinkTarget,
    };
  }
}

class SupportAssistantResponse {
  const SupportAssistantResponse({
    required this.kind,
    required this.intent,
    required this.message,
    this.missingEntities = const <String>[],
    this.suggestedActions = const <String>[],
    this.deepLinkTarget,
    this.supportCallToAction,
    this.data = const <String, dynamic>{},
  });

  final SupportResponseKind kind;
  final String intent;
  final String message;
  final List<String> missingEntities;
  final List<String> suggestedActions;
  final String? deepLinkTarget;
  final SupportCallToAction? supportCallToAction;
  final Map<String, dynamic> data;

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'kind': kind.name,
      'intent': intent,
      'message': message,
      'missing_entities': missingEntities,
      'suggested_actions': suggestedActions,
      if (deepLinkTarget != null) 'deep_link_target': deepLinkTarget,
      if (supportCallToAction != null)
        'support_cta': supportCallToAction!.toMap(),
      if (data.isNotEmpty) 'data': data,
    };
  }
}

class SupportAssistantSession {
  SupportAssistantSession({
    required this.id,
    required this.userId,
    this.location,
  });

  final String id;
  final String userId;
  String? location;
  String? pendingIntent;
  final Map<String, dynamic> collectedEntities = <String, dynamic>{};
  final Map<String, dynamic> context = <String, dynamic>{};

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'user_id': userId,
      if (location != null) 'location': location,
      if (pendingIntent != null) 'pending_intent': pendingIntent,
      'collected_entities': Map<String, dynamic>.from(collectedEntities),
      'context': Map<String, dynamic>.from(context),
    };
  }
}

class SupportVenue {
  const SupportVenue({
    required this.id,
    required this.name,
    required this.location,
    required this.sports,
    required this.basePrice,
  });

  final String id;
  final String name;
  final String location;
  final List<String> sports;
  final double basePrice;

  factory SupportVenue.fromMap(Map<String, dynamic> map) {
    return SupportVenue(
      id: (map['id'] ?? map['_documentId'] ?? '').toString(),
      name: (map['name'] ?? '').toString(),
      location: (map['location'] ?? '').toString(),
      sports: _asStringList(map['sports']),
      basePrice: _asDouble(map['basePrice']),
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'location': location,
      'sports': sports,
      'basePrice': basePrice,
    };
  }
}

class SupportBooking {
  const SupportBooking({
    required this.id,
    required this.userId,
    required this.turfId,
    required this.date,
    required this.slots,
    required this.sport,
    required this.paymentMode,
    required this.status,
    required this.amount,
  });

  final String id;
  final String userId;
  final String turfId;
  final String date;
  final List<String> slots;
  final String sport;
  final String paymentMode;
  final String status;
  final double amount;

  factory SupportBooking.fromMap(Map<String, dynamic> map) {
    return SupportBooking(
      id: (map['id'] ?? map['_documentId'] ?? '').toString(),
      userId: (map['userId'] ?? '').toString(),
      turfId: (map['turfId'] ?? '').toString(),
      date: (map['date'] ?? '').toString(),
      slots: _asStringList(map['slots']),
      sport: (map['sport'] ?? '').toString(),
      paymentMode: (map['paymentMode'] ?? '').toString(),
      status: (map['status'] ?? '').toString(),
      amount: _asDouble(map['amount']),
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'userId': userId,
      'turfId': turfId,
      'date': date,
      'slots': slots,
      'sport': sport,
      'paymentMode': paymentMode,
      'status': status,
      'amount': amount,
    };
  }
}

class SupportRefund {
  const SupportRefund({
    required this.id,
    required this.bookingId,
    required this.userId,
    required this.status,
    required this.amount,
  });

  final String id;
  final String bookingId;
  final String userId;
  final double amount;
  final String status;

  factory SupportRefund.fromMap(Map<String, dynamic> map) {
    return SupportRefund(
      id: (map['id'] ?? map['_documentId'] ?? '').toString(),
      bookingId: (map['bookingId'] ?? '').toString(),
      userId: (map['userId'] ?? '').toString(),
      status: (map['status'] ?? '').toString(),
      amount: _asDouble(map['amount']),
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'bookingId': bookingId,
      'userId': userId,
      'status': status,
      'amount': amount,
    };
  }
}

class SupportKnowledgeBase {
  const SupportKnowledgeBase({
    required this.description,
    required this.targetUsers,
    required this.supportedSports,
    required this.userFeatures,
    required this.paymentOptions,
    required this.bookingHowTo,
    required this.cancelBookingHowTo,
    required this.bookingPolicy,
    required this.refundPolicy,
    required this.supportChannels,
    required this.officialLinks,
  });

  final String description;
  final List<String> targetUsers;
  final List<String> supportedSports;
  final List<String> userFeatures;
  final List<String> paymentOptions;
  final String bookingHowTo;
  final String cancelBookingHowTo;
  final Map<String, String> bookingPolicy;
  final Map<String, String> refundPolicy;
  final Map<String, String> supportChannels;
  final Map<String, String> officialLinks;

  factory SupportKnowledgeBase.book_your_turf() {
    return const SupportKnowledgeBase(
      description:
          'book_your_turf is a digital booking platform for players and teams. '
          'It helps users discover nearby venues, check slot availability, '
          'compare pricing, complete bookings, and get support for refunds or cancellations.',
      targetUsers: <String>[
        'Players',
        'Teams',
        'Weekend players',
        'College and school teams',
        'Office tournaments',
        'Sports enthusiasts',
      ],
      supportedSports: <String>[
        'Football',
        'Cricket',
        'Box Cricket',
        'Badminton',
        'Pickleball',
      ],
      userFeatures: <String>[
        'Nearby venue discovery',
        'Real-time slot availability',
        'Transparent pricing',
        'Instant booking confirmation',
        'Online payment',
        'Pay at venue',
        'Booking history',
        'Cancellation and refund support',
        'Offers and discounts',
      ],
      paymentOptions: <String>[
        'Online payment',
        'Pay at venue',
        'UPI',
        'Debit and credit cards',
        'Netbanking',
      ],
      bookingHowTo:
          '1. Open the Slot Management tab.\n'
          '2. Select your venue, sport, court, and date.\n'
          '3. Tap an available time slot.\n'
          '4. Choose Confirm Booking.\n'
          '5. Enter customer details and payment mode.\n'
          '6. Save to confirm the booking.',
      cancelBookingHowTo:
          '1. Open the Slot Management screen.\n'
          '2. Select the date and court for the booking.\n'
          '3. Tap the booked slot.\n'
          '4. Choose Unbook Slot or Cancel Booking.\n'
          '5. Confirm the cancellation.\n'
          '6. The slot becomes available again.',
      bookingPolicy: <String, String>{
        'Confirmation':
            'Bookings are confirmed based on advance or full payment.',
        'Arrival':
            'Users should arrive 10 to 15 minutes before the booked slot time.',
        'Slot Timing':
            'Playtime starts and ends as per the allotted schedule.',
      },
      refundPolicy: <String, String>{
        'Cancellation Window':
            'Users can cancel up to 6 hours before slot start time.',
        'Cancellation Charge': '5% cancellation charge applies.',
        'Late Cancellation':
            'No refund for cancellations after the allowed window or for no-shows.',
        'Refund Timeline':
            'Refunds are processed within 7 to 10 business days.',
      },
      supportChannels: <String, String>{
        'Support Phone': '+91 9566001173',
        'Support Email': 'support@book_your_turf.net',
        'Customer Care': '+91 9940663099',
      },
      officialLinks: <String, String>{
        'Website': 'https://book_your_turf.net/',
        'Android':
            'https://play.google.com/store/apps/details?id=com.book_your_turf.app',
        'iPhone/iPad':
            'https://apps.apple.com/in/app/book_your_turf/id6756934347',
        'Privacy Policy': 'https://book_your_turf.net/privacy',
        'Terms': 'https://book_your_turf.net/terms',
      },
    );
  }
}

abstract class UserSupportRepository {
  Future<List<SupportVenue>> searchVenues({
    required String location,
    required String sport,
    required String date,
    required String time,
  });

  Future<Map<String, dynamic>> checkAvailability({
    required String turfId,
    required String date,
    required String slot,
  });

  Future<SupportBooking> createBooking({
    required String userId,
    required String turfId,
    required String date,
    required List<String> slots,
    required String sport,
    required String paymentMode,
  });

  Future<SupportBooking?> findBooking({
    required String bookingId,
    required String userId,
  });

  Future<SupportBooking?> cancelBooking({
    required String bookingId,
    required String userId,
    required String reason,
  });

  Future<SupportRefund?> getRefund({
    required String bookingId,
    required String userId,
  });

  Future<String> createSupportTicket({
    required String userId,
    required String issueType,
    required String message,
    String? bookingId,
  });
}

class FirestoreSupportCollections {
  const FirestoreSupportCollections({
    this.venues = 'venues',
    this.bookings = 'bookings',
    this.refunds = 'refunds',
    this.supportTickets = 'supportTickets',
  });

  final String venues;
  final String bookings;
  final String refunds;
  final String supportTickets;
}

/// Firebase-friendly repository that keeps the assistant in one file.
///
/// This uses dynamic access so the file stays dependency-light until you plug it
/// into a Flutter app. Pass `FirebaseFirestore.instance` as `firestore`.
///
/// Expected document shape:
/// - `venues/{venueId}`: `name`, `location`, `sports`, `basePrice`
/// - `bookings/{bookingId}`: `userId`, `turfId`, `date`, `slots`,
///   `sport`, `paymentMode`, `status`, `amount`
/// - `refunds/{refundId}`: `bookingId`, `userId`, `status`, `amount`
/// - `supportTickets/{ticketId}`: `userId`, `issueType`, `message`,
///   `bookingId`, `status`, `createdAt`
class FirestoreUserSupportRepository implements UserSupportRepository {
  FirestoreUserSupportRepository({
    required dynamic firestore,
    this.collections = const FirestoreSupportCollections(),
  }) : _firestore = firestore;

  final dynamic _firestore;
  final FirestoreSupportCollections collections;

  @override
  Future<List<SupportVenue>> searchVenues({
    required String location,
    required String sport,
    required String date,
    required String time,
  }) async {
    final snapshot = await _firestore.collection(collections.venues).get();
    final normalizedLocation = _normalizeValue(location);
    final normalizedSport = _normalizeValue(sport);

    return _documentsFromSnapshot(snapshot)
        .map(SupportVenue.fromMap)
        .where((venue) {
          return _normalizeValue(venue.location) == normalizedLocation &&
              venue.sports.any(
                (entry) => _normalizeValue(entry) == normalizedSport,
              );
        })
        .toList();
  }

  @override
  Future<Map<String, dynamic>> checkAvailability({
    required String turfId,
    required String date,
    required String slot,
  }) async {
    final snapshot = await _firestore
        .collection(collections.bookings)
        .where('turfId', isEqualTo: turfId)
        .get();
    final bookings = _documentsFromSnapshot(snapshot).map(SupportBooking.fromMap);

    final isBooked = bookings.any((booking) {
      return booking.date == date &&
          booking.slots.contains(slot) &&
          booking.status != 'CANCELLED';
    });

    return <String, dynamic>{
      'turfId': turfId,
      'date': date,
      'slot': slot,
      'available': !isBooked,
    };
  }

  @override
  Future<SupportBooking> createBooking({
    required String userId,
    required String turfId,
    required String date,
    required List<String> slots,
    required String sport,
    required String paymentMode,
  }) async {
    final venueDocument = await _getDocument(
      collection: collections.venues,
      documentId: turfId,
    );
    if (venueDocument == null) {
      throw StateError('unknown_turf');
    }

    for (final slot in slots) {
      final availability = await checkAvailability(
        turfId: turfId,
        date: date,
        slot: slot,
      );
      if (availability['available'] != true) {
        throw StateError('slot_unavailable');
      }
    }

    final venue = SupportVenue.fromMap(venueDocument);
    final document = _firestore.collection(collections.bookings).doc();
    final booking = SupportBooking(
      id: document.id.toString(),
      userId: userId,
      turfId: turfId,
      date: date,
      slots: List<String>.from(slots),
      sport: sport,
      paymentMode: paymentMode,
      status: 'CONFIRMED',
      amount: venue.basePrice * slots.length,
    );

    await document.set(<String, dynamic>{
      ...booking.toMap(),
      'createdAt': DateTime.now().toUtc().toIso8601String(),
    });
    return booking;
  }

  @override
  Future<SupportBooking?> findBooking({
    required String bookingId,
    required String userId,
  }) async {
    final direct = await _getDocument(
      collection: collections.bookings,
      documentId: bookingId,
    );
    if (direct != null) {
      final booking = SupportBooking.fromMap(direct);
      if (booking.userId == userId) {
        return booking;
      }
    }

    final snapshot = await _firestore
        .collection(collections.bookings)
        .where('userId', isEqualTo: userId)
        .get();

    for (final document in _documentsFromSnapshot(snapshot)) {
      final booking = SupportBooking.fromMap(document);
      if (booking.id == bookingId) {
        return booking;
      }
    }
    return null;
  }

  @override
  Future<SupportBooking?> cancelBooking({
    required String bookingId,
    required String userId,
    required String reason,
  }) async {
    final document = await _findBookingDocument(
      bookingId: bookingId,
      userId: userId,
    );
    if (document == null) {
      return null;
    }

    final documentId = (document['_documentId'] ?? document['id']).toString();
    await _firestore.collection(collections.bookings).doc(documentId).update(
      <String, dynamic>{
        'status': 'CANCELLED',
        'cancelReason': reason,
        'cancelledAt': DateTime.now().toUtc().toIso8601String(),
      },
    );

    return SupportBooking.fromMap(
      <String, dynamic>{
        ...document,
        'status': 'CANCELLED',
      },
    );
  }

  @override
  Future<SupportRefund?> getRefund({
    required String bookingId,
    required String userId,
  }) async {
    final snapshot = await _firestore
        .collection(collections.refunds)
        .where('userId', isEqualTo: userId)
        .get();

    for (final document in _documentsFromSnapshot(snapshot)) {
      final refund = SupportRefund.fromMap(document);
      if (refund.bookingId == bookingId) {
        return refund;
      }
    }
    return null;
  }

  @override
  Future<String> createSupportTicket({
    required String userId,
    required String issueType,
    required String message,
    String? bookingId,
  }) async {
    final document = _firestore.collection(collections.supportTickets).doc();
    await document.set(<String, dynamic>{
      'id': document.id,
      'userId': userId,
      'issueType': issueType,
      'message': message,
      'bookingId': bookingId,
      'status': 'OPEN',
      'createdAt': DateTime.now().toUtc().toIso8601String(),
    });
    return document.id.toString();
  }

  Future<Map<String, dynamic>?> _getDocument({
    required String collection,
    required String documentId,
  }) async {
    final document = await _firestore.collection(collection).doc(documentId).get();
    if (document.exists != true) {
      return null;
    }
    return _documentToMap(document);
  }

  Future<Map<String, dynamic>?> _findBookingDocument({
    required String bookingId,
    required String userId,
  }) async {
    final direct = await _getDocument(
      collection: collections.bookings,
      documentId: bookingId,
    );
    if (direct != null &&
        (direct['userId']?.toString() ?? '') == userId) {
      return direct;
    }

    final snapshot = await _firestore
        .collection(collections.bookings)
        .where('userId', isEqualTo: userId)
        .get();
    for (final document in _documentsFromSnapshot(snapshot)) {
      final resolvedId = (document['id'] ?? document['_documentId']).toString();
      if (resolvedId == bookingId) {
        return document;
      }
    }
    return null;
  }

  List<Map<String, dynamic>> _documentsFromSnapshot(dynamic snapshot) {
    final docs = snapshot.docs;
    if (docs is! Iterable) {
      return const <Map<String, dynamic>>[];
    }

    final documents = <Map<String, dynamic>>[];
    for (final document in docs) {
      documents.add(_documentToMap(document));
    }
    return documents;
  }

  Map<String, dynamic> _documentToMap(dynamic document) {
    final data = _asStringMap(document.data());
    final documentId = document.id.toString();
    return <String, dynamic>{
      '_documentId': documentId,
      'id': (data['id'] ?? documentId).toString(),
      ...data,
    };
  }
}

/// Simple demo repository for local prototyping and tests.
class InMemoryUserSupportRepository implements UserSupportRepository {
  InMemoryUserSupportRepository({
    required List<SupportVenue> venues,
    required List<SupportBooking> bookings,
    required List<SupportRefund> refunds,
  })  : _venues = List<SupportVenue>.from(venues),
        _bookings = List<SupportBooking>.from(bookings),
        _refunds = List<SupportRefund>.from(refunds);

  factory InMemoryUserSupportRepository.demo() {
    return InMemoryUserSupportRepository(
      venues: const <SupportVenue>[
        SupportVenue(
          id: 'turf-101',
          name: 'BYT Arena',
          location: 'Coimbatore',
          sports: <String>['Cricket', 'Box Cricket'],
          basePrice: 1200,
        ),
        SupportVenue(
          id: 'turf-102',
          name: 'Smash Court',
          location: 'Coimbatore',
          sports: <String>['Badminton', 'Pickleball'],
          basePrice: 800,
        ),
        SupportVenue(
          id: 'turf-103',
          name: 'Goal Street',
          location: 'Chennai',
          sports: <String>['Football'],
          basePrice: 1500,
        ),
      ],
      bookings: const <SupportBooking>[
        SupportBooking(
          id: 'booking-9001',
          userId: 'user-123',
          turfId: 'turf-101',
          date: '2026-05-03',
          slots: <String>['19:00'],
          sport: 'Cricket',
          paymentMode: 'ONLINE',
          status: 'CONFIRMED',
          amount: 1200,
        ),
      ],
      refunds: const <SupportRefund>[
        SupportRefund(
          id: 'refund-5001',
          bookingId: 'booking-8500',
          userId: 'user-123',
          status: 'PROCESSING',
          amount: 900,
        ),
      ],
    );
  }

  final List<SupportVenue> _venues;
  final List<SupportBooking> _bookings;
  final List<SupportRefund> _refunds;

  @override
  Future<List<SupportVenue>> searchVenues({
    required String location,
    required String sport,
    required String date,
    required String time,
  }) async {
    final lowerLocation = location.toLowerCase();
    final lowerSport = sport.toLowerCase();
    return _venues.where((venue) {
      return venue.location.toLowerCase() == lowerLocation &&
          venue.sports.any((entry) => entry.toLowerCase() == lowerSport);
    }).toList();
  }

  @override
  Future<Map<String, dynamic>> checkAvailability({
    required String turfId,
    required String date,
    required String slot,
  }) async {
    final isBooked = _bookings.any(
      (booking) =>
          booking.turfId == turfId &&
          booking.date == date &&
          booking.slots.contains(slot) &&
          booking.status != 'CANCELLED',
    );
    return <String, dynamic>{
      'turfId': turfId,
      'date': date,
      'slot': slot,
      'available': !isBooked,
    };
  }

  @override
  Future<SupportBooking> createBooking({
    required String userId,
    required String turfId,
    required String date,
    required List<String> slots,
    required String sport,
    required String paymentMode,
  }) async {
    final venue = _venues.firstWhere((entry) => entry.id == turfId);
    final hasConflict = _bookings.any((booking) {
      if (booking.turfId != turfId ||
          booking.date != date ||
          booking.status == 'CANCELLED') {
        return false;
      }
      return booking.slots.any(slots.contains);
    });
    if (hasConflict) {
      throw StateError('slot_unavailable');
    }

    final booking = SupportBooking(
      id: 'booking-${9000 + _bookings.length + 1}',
      userId: userId,
      turfId: turfId,
      date: date,
      slots: slots,
      sport: sport,
      paymentMode: paymentMode,
      status: 'CONFIRMED',
      amount: venue.basePrice * slots.length,
    );
    _bookings.add(booking);
    return booking;
  }

  @override
  Future<SupportBooking?> findBooking({
    required String bookingId,
    required String userId,
  }) async {
    try {
      return _bookings.firstWhere(
        (booking) => booking.id == bookingId && booking.userId == userId,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<SupportBooking?> cancelBooking({
    required String bookingId,
    required String userId,
    required String reason,
  }) async {
    final booking = await findBooking(bookingId: bookingId, userId: userId);
    if (booking == null) {
      return null;
    }

    final index = _bookings.indexWhere((entry) => entry.id == booking.id);
    final cancelled = SupportBooking(
      id: booking.id,
      userId: booking.userId,
      turfId: booking.turfId,
      date: booking.date,
      slots: booking.slots,
      sport: booking.sport,
      paymentMode: booking.paymentMode,
      status: 'CANCELLED',
      amount: booking.amount,
    );
    _bookings[index] = cancelled;
    return cancelled;
  }

  @override
  Future<SupportRefund?> getRefund({
    required String bookingId,
    required String userId,
  }) async {
    try {
      return _refunds.firstWhere(
        (refund) => refund.bookingId == bookingId && refund.userId == userId,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<String> createSupportTicket({
    required String userId,
    required String issueType,
    required String message,
    String? bookingId,
  }) async {
    return 'ticket-${DateTime.now().millisecondsSinceEpoch}';
  }
}

class book_your_turfUserSupportAssistant {
  book_your_turfUserSupportAssistant({
    required UserSupportRepository repository,
    SupportKnowledgeBase? knowledgeBase,
    DateTime Function()? clock,
  })  : _repository = repository,
        _knowledgeBase = knowledgeBase ?? SupportKnowledgeBase.book_your_turf(),
        _clock = clock ?? DateTime.now;

  factory book_your_turfUserSupportAssistant.demo({
    SupportKnowledgeBase? knowledgeBase,
    DateTime Function()? clock,
  }) {
    return book_your_turfUserSupportAssistant(
      repository: InMemoryUserSupportRepository.demo(),
      knowledgeBase: knowledgeBase,
      clock: clock,
    );
  }

  factory book_your_turfUserSupportAssistant.firebase({
    required dynamic firestore,
    FirestoreSupportCollections collections =
        const FirestoreSupportCollections(),
    SupportKnowledgeBase? knowledgeBase,
    DateTime Function()? clock,
  }) {
    return book_your_turfUserSupportAssistant(
      repository: FirestoreUserSupportRepository(
        firestore: firestore,
        collections: collections,
      ),
      knowledgeBase: knowledgeBase,
      clock: clock,
    );
  }

  final UserSupportRepository _repository;
  final SupportKnowledgeBase _knowledgeBase;
  final DateTime Function() _clock;
  int _sessionCounter = 0;

  SupportAssistantSession startSession({
    required String userId,
    String? location,
  }) {
    _sessionCounter += 1;
    return SupportAssistantSession(
      id: 'support-session-$_sessionCounter',
      userId: userId,
      location: location,
    );
  }

  Future<SupportAssistantResponse> sendMessage({
    required SupportAssistantSession session,
    required String message,
  }) async {
    final trimmed = message.trim();
    if (trimmed.isEmpty) {
      return const SupportAssistantResponse(
        kind: SupportResponseKind.fallback,
        intent: 'empty_message',
        message: 'Please type your question so I can help.',
        suggestedActions: <String>[
          'How to book',
          'Find a nearby turf',
        ],
      );
    }

    if (_looksLikeBusinessSideQuery(trimmed)) {
      return const SupportAssistantResponse(
        kind: SupportResponseKind.scopeGuardrail,
        intent: 'user_scope_guardrail',
        message:
            'I am the book_your_turf user support assistant. I can help with booking, refunds, cancellations, app usage, and support questions, but not owner, partner, or admin operations.',
        suggestedActions: <String>[
          'How to book',
          'Contact support',
        ],
      );
    }

    final intent = session.pendingIntent ?? _matchIntent(trimmed);
    final entities = <String, dynamic>{
      ...session.collectedEntities,
      ..._extractEntities(trimmed, session),
    };

    session.collectedEntities
      ..clear()
      ..addAll(entities);

    switch (intent) {
      case 'app_intro':
        session.pendingIntent = null;
        return _staticResponse(
          intent: intent,
          message:
              'book_your_turf helps players and teams find nearby venues, check slot availability, compare pricing, and complete bookings with support for refunds and cancellations.\n\nBuilt for: ${_knowledgeBase.targetUsers.join(', ')}',
          suggestedActions: const <String>[
            'How to book',
            'Find a nearby turf',
            'Contact support',
          ],
        );
      case 'booking_how_to':
        session.pendingIntent = null;
        return _guidedResponse(
          intent: intent,
          message: _knowledgeBase.bookingHowTo,
          deepLinkTarget: 'slot_management',
          suggestedActions: const <String>[
            'Find a nearby turf',
            'Check cancellation policy',
          ],
        );
      case 'cancel_booking_how_to':
        session.pendingIntent = null;
        return _guidedResponse(
          intent: intent,
          message:
              '${_knowledgeBase.cancelBookingHowTo}\n\nRefund Policy:\n${_formatMap(_knowledgeBase.refundPolicy)}',
          deepLinkTarget: 'slot_management',
          suggestedActions: const <String>[
            'Share booking ID',
            'Check refund status',
          ],
        );
      case 'booking_policy_info':
        session.pendingIntent = null;
        return _staticResponse(
          intent: intent,
          message:
              'Booking Policy:\n${_formatMap(_knowledgeBase.bookingPolicy)}\n\nRefund Policy:\n${_formatMap(_knowledgeBase.refundPolicy)}',
          suggestedActions: const <String>[
            'How to cancel my booking',
            'Check refund status',
          ],
        );
      case 'contact_support':
        session.pendingIntent = null;
        return _staticResponse(
          intent: intent,
          message:
              'Support Channels:\n${_formatMap(_knowledgeBase.supportChannels)}',
          deepLinkTarget: 'support',
          supportCallToAction: const SupportCallToAction(
            label: 'Open support',
            intent: 'contact_support',
            deepLinkTarget: 'support',
          ),
        );
      case 'app_download':
        session.pendingIntent = null;
        return _staticResponse(
          intent: intent,
          message:
              'Official Links:\n${_formatMap(_knowledgeBase.officialLinks)}',
          suggestedActions: const <String>[
            'Privacy policy',
            'How to book',
          ],
        );
      case 'privacy_question':
        session.pendingIntent = null;
        return _staticResponse(
          intent: intent,
          message:
              'For privacy and data-use details, please use the official privacy policy:\n${_knowledgeBase.officialLinks['Privacy Policy']}',
          suggestedActions: const <String>['Contact support'],
        );
      case 'find_turf':
        return _handleFindTurf(session: session, entities: entities);
      case 'check_availability':
        return _handleCheckAvailability(session: session, entities: entities);
      case 'book_slot':
        return _handleBookSlot(session: session, entities: entities);
      case 'cancel_booking':
        return _handleCancelBooking(session: session, entities: entities);
      case 'refund_help':
        return _handleRefundHelp(session: session, entities: entities);
      case 'complaint':
        return _handleComplaint(session: session, entities: entities, rawMessage: trimmed);
      default:
        session.pendingIntent = null;
        return const SupportAssistantResponse(
          kind: SupportResponseKind.fallback,
          intent: 'fallback',
          message:
              'I can help with booking steps, nearby venues, cancellations, refund questions, support, and app usage. Try asking "How to book" or "How to cancel my booking".',
          suggestedActions: <String>[
            'How to book',
            'How to cancel my booking',
            'Contact support',
          ],
          supportCallToAction: SupportCallToAction(
            label: 'Contact support',
            intent: 'contact_support',
            deepLinkTarget: 'support',
          ),
        );
    }
  }

  Future<SupportAssistantResponse> _handleFindTurf({
    required SupportAssistantSession session,
    required Map<String, dynamic> entities,
  }) async {
    final missing = <String>[
      if (entities['sport'] == null) 'sport',
      if (entities['location'] == null) 'location',
      if (entities['date'] == null) 'date',
      if (entities['time'] == null) 'time',
    ];

    if (missing.isNotEmpty) {
      session.pendingIntent = 'find_turf';
      return SupportAssistantResponse(
        kind: SupportResponseKind.needsInput,
        intent: 'find_turf',
        message: _buildMissingPrompt(missing),
        missingEntities: missing,
        suggestedActions: _buildSuggestedActionsForMissing(missing),
      );
    }

    session.pendingIntent = null;
    final venues = await _repository.searchVenues(
      location: entities['location'] as String,
      sport: entities['sport'] as String,
      date: entities['date'] as String,
      time: entities['time'] as String,
    );

    if (venues.isEmpty) {
      return SupportAssistantResponse(
        kind: SupportResponseKind.actionResult,
        intent: 'find_turf',
        message:
            'I could not find a ${entities['sport']} venue in ${entities['location']} for ${entities['date']} at ${entities['time']}. Try another time or nearby area.',
        suggestedActions: const <String>[
          'Try another time',
          'Share another location',
        ],
      );
    }

    session.context['lastTurfId'] = venues.first.id;
    return SupportAssistantResponse(
      kind: SupportResponseKind.actionResult,
      intent: 'find_turf',
      message:
          'I found ${venues.length} option(s). The first one is ${venues.first.name} in ${venues.first.location}.',
      deepLinkTarget: 'venue_results',
      suggestedActions: const <String>[
        'Check slot availability',
        'Book this slot',
      ],
      data: <String, dynamic>{
        'venues': venues.map((venue) => venue.toMap()).toList(),
      },
    );
  }

  Future<SupportAssistantResponse> _handleCheckAvailability({
    required SupportAssistantSession session,
    required Map<String, dynamic> entities,
  }) async {
    final turfId =
        entities['turf_id'] as String? ?? session.context['lastTurfId'] as String?;
    final missing = <String>[
      if (turfId == null) 'turf_id',
      if (entities['date'] == null) 'date',
      if (entities['slot'] == null) 'slot',
    ];

    if (missing.isNotEmpty) {
      session.pendingIntent = 'check_availability';
      return SupportAssistantResponse(
        kind: SupportResponseKind.needsInput,
        intent: 'check_availability',
        message: _buildMissingPrompt(missing),
        missingEntities: missing,
        suggestedActions: _buildSuggestedActionsForMissing(missing),
      );
    }

    session.pendingIntent = null;
    final availability = await _repository.checkAvailability(
      turfId: turfId!,
      date: entities['date'] as String,
      slot: entities['slot'] as String,
    );

    return SupportAssistantResponse(
      kind: SupportResponseKind.actionResult,
      intent: 'check_availability',
      message: availability['available'] == true
          ? 'Yes, that slot is currently available.'
          : 'That slot is not available right now.',
      suggestedActions: availability['available'] == true
          ? const <String>['Book this slot']
          : const <String>['Try another time'],
      data: availability,
    );
  }

  Future<SupportAssistantResponse> _handleBookSlot({
    required SupportAssistantSession session,
    required Map<String, dynamic> entities,
  }) async {
    final turfId =
        entities['turf_id'] as String? ?? session.context['lastTurfId'] as String?;
    final missing = <String>[
      if (turfId == null) 'turf_id',
      if (entities['date'] == null) 'date',
      if (entities['slots'] == null) 'slots',
      if (entities['sport'] == null) 'sport',
      if (entities['payment_mode'] == null) 'payment_mode',
    ];

    if (missing.isNotEmpty) {
      session.pendingIntent = 'book_slot';
      return SupportAssistantResponse(
        kind: SupportResponseKind.needsInput,
        intent: 'book_slot',
        message: _buildMissingPrompt(missing),
        missingEntities: missing,
        deepLinkTarget: 'slot_management',
        suggestedActions: _buildSuggestedActionsForMissing(missing),
      );
    }

    session.pendingIntent = null;
    late final SupportBooking booking;
    try {
      booking = await _repository.createBooking(
        userId: session.userId,
        turfId: turfId!,
        date: entities['date'] as String,
        slots: (entities['slots'] as List<String>),
        sport: entities['sport'] as String,
        paymentMode: entities['payment_mode'] as String,
      );
    } on StateError catch (error) {
      if (error.message == 'slot_unavailable') {
        return const SupportAssistantResponse(
          kind: SupportResponseKind.actionError,
          intent: 'book_slot',
          message:
              'That slot is no longer available. Please try another time or check a different venue.',
          suggestedActions: <String>['Try another time', 'Find a nearby turf'],
        );
      }
      if (error.message == 'unknown_turf') {
        return const SupportAssistantResponse(
          kind: SupportResponseKind.actionError,
          intent: 'book_slot',
          message:
              'I could not match that venue in the current data source. Please choose the venue again from the app results.',
          suggestedActions: <String>['Find a nearby turf'],
        );
      }
      rethrow;
    }
    session.context['lastBookingId'] = booking.id;

    return SupportAssistantResponse(
      kind: SupportResponseKind.actionResult,
      intent: 'book_slot',
      message:
          'Your booking ${booking.id} is confirmed for ${booking.date} at ${booking.slots.join(', ')}.',
      deepLinkTarget: 'booking_confirmation',
      suggestedActions: const <String>[
        'Check refund status',
        'How to cancel my booking',
      ],
      data: <String, dynamic>{'booking': booking.toMap()},
    );
  }

  Future<SupportAssistantResponse> _handleCancelBooking({
    required SupportAssistantSession session,
    required Map<String, dynamic> entities,
  }) async {
    final bookingId = entities['booking_id'] as String?;
    final missing = <String>[
      if (bookingId == null) 'booking_id',
      if (entities['reason'] == null) 'reason',
    ];

    if (missing.isNotEmpty) {
      session.pendingIntent = 'cancel_booking';
      return SupportAssistantResponse(
        kind: SupportResponseKind.needsInput,
        intent: 'cancel_booking',
        message: _buildMissingPrompt(missing),
        missingEntities: missing,
        deepLinkTarget: 'booking_history',
        suggestedActions: _buildSuggestedActionsForMissing(missing),
      );
    }

    session.pendingIntent = null;
    final booking = await _repository.cancelBooking(
      bookingId: bookingId!,
      userId: session.userId,
      reason: entities['reason'] as String,
    );

    if (booking == null) {
      if (_looksLikeAppBookingId(bookingId)) {
        return SupportAssistantResponse(
          kind: SupportResponseKind.actionError,
          intent: 'cancel_booking',
          message:
              'I recognized booking ID $bookingId, but I could not find it in the current data source. If your real bookings are in Firebase, connect this assistant repository to your booking collection.',
          supportCallToAction: const SupportCallToAction(
            label: 'Contact support',
            intent: 'complaint',
            deepLinkTarget: 'support',
          ),
        );
      }

      return const SupportAssistantResponse(
        kind: SupportResponseKind.actionError,
        intent: 'cancel_booking',
        message: 'I could not find that booking for cancellation.',
        supportCallToAction: SupportCallToAction(
          label: 'Contact support',
          intent: 'complaint',
          deepLinkTarget: 'support',
        ),
      );
    }

    return SupportAssistantResponse(
      kind: SupportResponseKind.actionResult,
      intent: 'cancel_booking',
      message:
          'Booking ${booking.id} has been cancelled. Refund rules will depend on payment mode and cancellation timing.',
      deepLinkTarget: 'booking_history',
      suggestedActions: const <String>['Check refund status'],
      data: <String, dynamic>{'booking': booking.toMap()},
    );
  }

  Future<SupportAssistantResponse> _handleRefundHelp({
    required SupportAssistantSession session,
    required Map<String, dynamic> entities,
  }) async {
    final bookingId =
        entities['booking_id'] as String? ?? session.context['lastBookingId'] as String?;
    if (bookingId == null) {
      session.pendingIntent = 'refund_help';
      return const SupportAssistantResponse(
        kind: SupportResponseKind.needsInput,
        intent: 'refund_help',
        message: 'Please share the booking ID so I can check the refund status.',
        missingEntities: <String>['booking_id'],
        suggestedActions: <String>['Share booking ID'],
      );
    }

    session.pendingIntent = null;
    final refund = await _repository.getRefund(
      bookingId: bookingId,
      userId: session.userId,
    );

    if (refund == null) {
      return SupportAssistantResponse(
        kind: SupportResponseKind.actionResult,
        intent: 'refund_help',
        message:
            'I could not find an active refund for booking $bookingId. If money was deducted and the booking failed, I can help create a support ticket next.',
        supportCallToAction: const SupportCallToAction(
          label: 'Create support ticket',
          intent: 'complaint',
          deepLinkTarget: 'support',
        ),
      );
    }

    return SupportAssistantResponse(
      kind: SupportResponseKind.actionResult,
      intent: 'refund_help',
      message:
          'Refund ${refund.id} is currently ${refund.status}. Expected policy timeline is 7 to 10 business days.',
      supportCallToAction: const SupportCallToAction(
        label: 'Contact support',
        intent: 'contact_support',
        deepLinkTarget: 'support',
      ),
      data: <String, dynamic>{'refund': refund.toMap()},
    );
  }

  Future<SupportAssistantResponse> _handleComplaint({
    required SupportAssistantSession session,
    required Map<String, dynamic> entities,
    required String rawMessage,
  }) async {
    final ticketId = await _repository.createSupportTicket(
      userId: session.userId,
      issueType: (entities['issue_type'] as String?) ?? 'OTHER',
      message: rawMessage,
      bookingId: entities['booking_id'] as String?,
    );

    session.pendingIntent = null;
    return SupportAssistantResponse(
      kind: SupportResponseKind.actionResult,
      intent: 'complaint',
      message:
          'I have logged this for support follow-up. Your support ticket ID is $ticketId.',
      deepLinkTarget: 'support',
      suggestedActions: const <String>['Contact support'],
      data: <String, dynamic>{'ticketId': ticketId},
    );
  }

  SupportAssistantResponse _staticResponse({
    required String intent,
    required String message,
    String? deepLinkTarget,
    List<String> suggestedActions = const <String>[],
    SupportCallToAction? supportCallToAction,
  }) {
    return SupportAssistantResponse(
      kind: SupportResponseKind.staticAnswer,
      intent: intent,
      message: message,
      deepLinkTarget: deepLinkTarget,
      suggestedActions: suggestedActions,
      supportCallToAction: supportCallToAction,
    );
  }

  SupportAssistantResponse _guidedResponse({
    required String intent,
    required String message,
    String? deepLinkTarget,
    List<String> suggestedActions = const <String>[],
    SupportCallToAction? supportCallToAction,
  }) {
    return SupportAssistantResponse(
      kind: SupportResponseKind.staticAnswer,
      intent: intent,
      message:
          'Here is the easiest way to do that in the app:\n\n$message\n\nIf you get stuck on any step, tell me what screen you are on and I will guide you from there.',
      deepLinkTarget: deepLinkTarget,
      suggestedActions: suggestedActions,
      supportCallToAction: supportCallToAction,
    );
  }

  String _matchIntent(String message) {
    final lower = message.toLowerCase();

    if (_containsAny(lower, <String>['how to cancel', 'cancel booking', 'unbook'])) {
      return lower.contains('how') || lower.contains('where')
          ? 'cancel_booking_how_to'
          : 'cancel_booking';
    }
    if (_containsAny(lower, <String>['how to book', 'how do i book', 'book a slot'])) {
      return 'booking_how_to';
    }
    if (_containsAny(lower, <String>['what is book_your_turf', 'tell me about book your turf', 'how does this app work'])) {
      return 'app_intro';
    }
    if (_containsAny(lower, <String>['cancellation policy', 'refund timeline', 'refund policy'])) {
      return 'booking_policy_info';
    }
    if (_containsAny(lower, <String>['contact support', 'support number', 'support email'])) {
      return 'contact_support';
    }
    if (_containsAny(lower, <String>['download app', 'ios app', 'android app', 'app link'])) {
      return 'app_download';
    }
    if (_containsAny(lower, <String>['privacy', 'data'])) {
      return 'privacy_question';
    }
    if (_containsAny(lower, <String>['find', 'nearby', 'court in', 'turf in'])) {
      return 'find_turf';
    }
    if (_containsAny(lower, <String>['availability', 'slot available'])) {
      return 'check_availability';
    }
    if (_containsAny(lower, <String>['book ', 'reserve ', 'confirm booking'])) {
      return 'book_slot';
    }
    if (_containsAny(lower, <String>['refund status', 'where is my refund', 'refund help'])) {
      return 'refund_help';
    }
    if (_containsAny(lower, <String>['complaint', 'support ticket', 'payment deducted', 'bad experience'])) {
      return 'complaint';
    }

    return 'fallback';
  }

  Map<String, dynamic> _extractEntities(
    String message,
    SupportAssistantSession session,
  ) {
    final sport = _findSport(message);
    final location = _findLocation(message) ?? session.location;
    final date = _findDate(message);
    final time = _findTime(message);
    final bookingId = _findBookingId(message);
    final reason = _findReason(message);

    if (location != null) {
      session.location = location;
    }

    return <String, dynamic>{
      if (sport != null) 'sport': sport,
      if (location != null) 'location': location,
      if (date != null) 'date': date,
      if (time != null) ...<String, dynamic>{
        'time': time,
        'slot': time,
        'slots': <String>[time],
      },
      if (bookingId != null) 'booking_id': bookingId,
      if (_findTurfId(message) != null) 'turf_id': _findTurfId(message),
      if (_findPaymentMode(message) != null)
        'payment_mode': _findPaymentMode(message),
      if (_findIssueType(message) != null) 'issue_type': _findIssueType(message),
      if (reason != null) 'reason': reason,
    };
  }

  String? _findSport(String message) {
    final collapsed = _collapse(message);
    for (final sport in _knowledgeBase.supportedSports) {
      if (collapsed.contains(_collapse(sport))) {
        return sport;
      }
    }
    return null;
  }

  String? _findLocation(String message) {
    final match = RegExp(r'\b(?:in|near|at)\s+([a-z][a-z\s]{1,40})', caseSensitive: false)
        .firstMatch(message);
    if (match == null) {
      return null;
    }
    final raw = match.group(1) ?? '';
    return raw
        .replaceAll(
          RegExp(r'\b(today|tomorrow|tommorrow|tonight|at \d.*|for \d.*)\b.*', caseSensitive: false),
          '',
        )
        .trim();
  }

  String? _findDate(String message) {
    final lower = message.toLowerCase();
    if (lower.contains('today')) {
      return _formatDate(_clock());
    }
    if (lower.contains('tomorrow') || _containsTomorrowTypo(lower)) {
      return _formatDate(_clock().add(const Duration(days: 1)));
    }

    final match =
        RegExp(r'\b(20\d{2}-\d{2}-\d{2})\b').firstMatch(message);
    return match?.group(1);
  }

  String? _findTime(String message) {
    final match =
        RegExp(r'\b(\d{1,2})(?::(\d{2}))?\s*(am|pm)\b', caseSensitive: false)
            .firstMatch(message);
    if (match == null) {
      return null;
    }
    var hour = int.parse(match.group(1)!);
    final minute = match.group(2) ?? '00';
    final meridiem = match.group(3)!.toLowerCase();
    if (meridiem == 'pm' && hour != 12) {
      hour += 12;
    }
    if (meridiem == 'am' && hour == 12) {
      hour = 0;
    }
    return '${hour.toString().padLeft(2, '0')}:$minute';
  }

  String? _findPaymentMode(String message) {
    final lower = message.toLowerCase();
    if (_containsAny(lower, <String>['pay at venue', 'cash', 'pay later'])) {
      return 'PAY_AT_VENUE';
    }
    if (_containsAny(lower, <String>['online', 'upi', 'card'])) {
      return 'ONLINE';
    }
    return null;
  }

  String? _findIssueType(String message) {
    final lower = message.toLowerCase();
    if (lower.contains('payment')) {
      return 'PAYMENT';
    }
    if (lower.contains('refund')) {
      return 'REFUND';
    }
    if (_containsAny(lower, <String>['booking', 'slot', 'reservation'])) {
      return 'BOOKING';
    }
    return null;
  }

  String? _findBookingId(String message) {
    final standard =
        RegExp(r'\bbooking-\d+\b', caseSensitive: false).firstMatch(message);
    if (standard != null) {
      return standard.group(0);
    }

    final appStyle = RegExp(
      r'\b(BYT(?:[A-Z])?(?:[_-][A-Z]+)*[_-]?\d{8,})\b',
      caseSensitive: false,
    ).firstMatch(message);
    return appStyle?.group(1)?.toUpperCase();
  }

  String? _findTurfId(String message) {
    return RegExp(r'\bturf-\d+\b', caseSensitive: false)
        .firstMatch(message)
        ?.group(0)
        ?.toLowerCase();
  }

  String? _findReason(String message) {
    final trimmed = message.trim();
    if (trimmed.length < 5) {
      return null;
    }
    if (_findBookingId(trimmed) != null) {
      return null;
    }
    if (RegExp(r'^(how\s+to\s+)?cancel(?:\s+my|\s+the|\s+a)?\s+booking[\s?.!]*$', caseSensitive: false)
        .hasMatch(trimmed)) {
      return null;
    }
    return trimmed;
  }

  String _buildMissingPrompt(List<String> missing) {
    final prompts = <String>[];
    if (missing.contains('sport')) {
      prompts.add('Which sport are you looking for?');
    }
    if (missing.contains('location')) {
      prompts.add('Which city or area should I use?');
    }
    if (missing.contains('date')) {
      prompts.add('Which date should I use?');
    }
    if (missing.contains('time')) {
      prompts.add('What time should I use?');
    }
    if (missing.contains('slot')) {
      prompts.add('Which slot should I check?');
    }
    if (missing.contains('slots')) {
      prompts.add('Which slot time should I use?');
    }
    if (missing.contains('turf_id')) {
      prompts.add('Which turf or venue should I use?');
    }
    if (missing.contains('payment_mode')) {
      prompts.add('How would you like to pay: online or at the venue?');
    }
    if (missing.contains('booking_id')) {
      prompts.add('Please share the booking ID.');
    }
    if (missing.contains('reason')) {
      prompts.add('Please share the reason for this request.');
    }
    return prompts.join(' ');
  }

  List<String> _buildSuggestedActionsForMissing(List<String> missing) {
    final actions = <String>[];
    if (missing.contains('sport')) {
      actions.add('Share sport');
    }
    if (missing.contains('location')) {
      actions.add('Share location');
    }
    if (missing.contains('date')) {
      actions.add('Share date');
    }
    if (missing.contains('time') || missing.contains('slot')) {
      actions.add('Share time');
    }
    if (missing.contains('payment_mode')) {
      actions.add('Choose payment mode');
    }
    if (missing.contains('booking_id')) {
      actions.add('Share booking ID');
    }
    if (missing.contains('reason')) {
      actions.add('Share reason');
    }
    return actions;
  }

  bool _looksLikeBusinessSideQuery(String message) {
    return RegExp(
      r'\b(owner|partner|channel partner|admin|commission|settlement|revenue|earnings|audit log|banner)\b',
      caseSensitive: false,
    ).hasMatch(message);
  }

  bool _looksLikeAppBookingId(String value) {
    return RegExp(
      r'^BYT(?:[A-Z])?(?:[_-][A-Z]+)*[_-]?\d{8,}$',
      caseSensitive: false,
    ).hasMatch(value);
  }

  bool _containsTomorrowTypo(String text) {
    final words = text.split(RegExp(r'[^a-z]+')).where((entry) => entry.isNotEmpty);
    return words.any((word) => word.startsWith('tom') && word.endsWith('row'));
  }

  bool _containsAny(String text, List<String> patterns) {
    for (final pattern in patterns) {
      if (text.contains(pattern)) {
        return true;
      }
    }
    return false;
  }

  String _collapse(String value) {
    return value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  String _formatMap(Map<String, String> values) {
    return values.entries.map((entry) => '- ${entry.key}: ${entry.value}').join('\n');
  }

  String _formatDate(DateTime value) {
    final year = value.year.toString().padLeft(4, '0');
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }
}
