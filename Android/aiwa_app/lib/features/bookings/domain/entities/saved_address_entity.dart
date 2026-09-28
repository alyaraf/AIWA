/// AccountController SavedAddressDto (GET /account/addresses).
// ponytail: lives in bookings until phase 6 builds features/addresses; move
// it there then.
class SavedAddressEntity {
  final String id;
  final String label;
  final String addressLine;
  final bool isDefault;

  const SavedAddressEntity({
    required this.id,
    required this.label,
    required this.addressLine,
    this.isDefault = false,
  });

  factory SavedAddressEntity.fromJson(Map<String, dynamic> json) =>
      SavedAddressEntity(
        id: json['id'].toString(),
        label: json['label'] as String? ?? '',
        addressLine: json['addressLine'] as String? ?? '',
        isDefault: json['defaultAddress'] as bool? ?? false,
      );
}
