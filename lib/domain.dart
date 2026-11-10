import 'package:flutter/foundation.dart';

class CareService {
  final String id, name, description, unit;
  final int samplePrice;
  const CareService(
    this.id,
    this.name,
    this.description,
    this.unit,
    this.samplePrice,
  );
}

const sampleServices = [
  CareService(
    'daily',
    'Wash & Fold',
    'Freshly washed, neatly folded.',
    'kg',
    85,
  ),
  CareService(
    'pressed',
    'Wash & Iron',
    'A crisp finish for your daily wardrobe.',
    'kg',
    120,
  ),
  CareService(
    'delicate',
    'Dry cleaning',
    'Thoughtful care for delicate favourites.',
    'item',
    180,
  ),
  CareService(
    'shoes',
    'Shoe cleaning',
    'A fresh start for your favourite pair.',
    'pair',
    299,
  ),
  CareService('iron', 'Steam Iron', 'Pressed and ready to wear.', 'item', 25),
  CareService(
    'linen',
    'Home linen',
    'Care for your household fabrics.',
    'item',
    150,
  ),
];

class PickupDraft {
  final CareService service;
  final List<CareService> additionalServices;
  List<CareService> get services => [service, ...additionalServices];
  final String address, postalCode, window;
  final DateTime date;
  const PickupDraft({
    required this.service,
    this.additionalServices = const [],
    required this.address,
    required this.postalCode,
    required this.window,
    required this.date,
  });
  String? validate(DateTime now) {
    if (address.trim().length < 10) return 'Enter a complete pickup address.';
    if (!RegExp(r'^[1-9]\d{5}$').hasMatch(postalCode.trim())) {
      return 'Enter a valid six-digit postal code.';
    }
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(date.year, date.month, date.day);
    if (!day.isAfter(today)) return 'Choose a pickup date after today.';
    if (!sampleWindows.contains(window)) return 'Choose a pickup window.';
    return null;
  }
}

const sampleWindows = ['9 AM – 12 PM', '12 PM – 3 PM', '3 PM – 6 PM'];

class PreviewOrder {
  final String id;
  final PickupDraft pickup;
  const PreviewOrder(this.id, this.pickup);
}

/// Preview-only state. No customer data is transmitted or persisted.
class PreviewBookings extends ChangeNotifier {
  final List<PreviewOrder> _orders = [];
  final Map<String, PreviewOrder> _requests = {};
  List<PreviewOrder> get orders => List.unmodifiable(_orders);

  void clear() {
    _orders.clear();
    _requests.clear();
    notifyListeners();
  }

  PreviewOrder create(PickupDraft draft, String requestId, DateTime now) {
    final prior = _requests[requestId];
    if (prior != null) return prior;
    final error = draft.validate(now);
    if (error != null) throw ArgumentError(error);
    final order = PreviewOrder(
      'PREVIEW-${(_orders.length + 1).toString().padLeft(3, '0')}',
      draft,
    );
    _orders.insert(0, order);
    _requests[requestId] = order;
    notifyListeners();
    return order;
  }
}
