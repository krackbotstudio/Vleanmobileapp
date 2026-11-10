import 'package:flutter_test/flutter_test.dart';
import 'package:vclean_laundry/domain.dart';

void main() {
  final now = DateTime(2026, 11, 5, 14);
  PickupDraft pickup({String postal = '500001', DateTime? date}) => PickupDraft(
    service: sampleServices.first,
    address: 'Sample flat 10, Example Street',
    postalCode: postal,
    window: sampleWindows.first,
    date: date ?? DateTime(2026, 11, 6),
  );
  test('rejects malformed postal codes and past or same-day pickup dates', () {
    expect(pickup(postal: '000000').validate(now), isNotNull);
    expect(pickup(postal: 'abcdef').validate(now), isNotNull);
    expect(pickup(date: now).validate(now), isNotNull);
    expect(pickup(date: DateTime(2026, 11, 4)).validate(now), isNotNull);
    expect(pickup().validate(now), isNull);
  });
  test('repeated preview request creates one order', () {
    final repository = PreviewBookings();
    final first = repository.create(pickup(), 'request-a', now);
    final retry = repository.create(pickup(), 'request-a', now);
    expect(retry, same(first));
    expect(repository.orders, hasLength(1));
    repository.create(pickup(), 'request-b', now);
    expect(repository.orders, hasLength(2));
    repository.dispose();
  });
}
