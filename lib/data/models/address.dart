/// Address model for location information
class Address {
  final String? village;
  final String? cityDistrict;
  final String? city;
  final String? state;
  final String? region;
  final String? country;
  final String? countryCode;

  const Address({
    this.village,
    this.cityDistrict,
    this.city,
    this.state,
    this.region,
    this.country,
    this.countryCode,
  });

  factory Address.fromJson(Map<String, dynamic> json) {
    return Address(
      village: json['village'] as String?,
      cityDistrict: json['city_district'] as String?,
      city: json['city'] as String?,
      state: json['state'] as String?,
      region: json['region'] as String?,
      country: json['country'] as String?,
      countryCode: json['country_code'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'village': village,
      'city_district': cityDistrict,
      'city': city,
      'state': state,
      'region': region,
      'country': country,
      'country_code': countryCode,
    };
  }

  /// Get formatted location string (e.g., "Pondok Cina, Depok")
  String get formattedLocation {
    final parts = <String>[];
    if (village != null && village!.isNotEmpty) {
      parts.add(village!);
    }
    if (city != null && city!.isNotEmpty) {
      parts.add(city!);
    }
    return parts.join(', ');
  }

  /// Get short location (village only or city if no village)
  String get shortLocation {
    return village ?? city ?? '';
  }
}
