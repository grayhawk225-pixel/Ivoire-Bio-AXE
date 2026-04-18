import 'package:cloud_firestore/cloud_firestore.dart';

enum UserRole {
  restaurateur,
  collecteur,
  acheteur,
  admin,
}

class MobileMoneyAccount {
  final String number;
  final String operatorName;

  MobileMoneyAccount({required this.number, required this.operatorName});

  Map<String, dynamic> toMap() => {'number': number, 'operatorName': operatorName};

  factory MobileMoneyAccount.fromMap(Map<String, dynamic> map) {
    return MobileMoneyAccount(
      number: map['number'] ?? '',
      operatorName: map['operatorName'] ?? '',
    );
  }
}

class AppUser {
  final String id;
  final String email;
  final UserRole role;
  final DateTime createdAt;
  final String phoneNumber;
  final String alternativePhone;
  final String fullName;
  final String city;
  final String commune;
  final String bio;
  final double balance;
  
  // Champs spécifiques Restaurateur
  final String? restaurantName;
  final GeoPoint? location;

  // Champs spécifiques Collecteur
  final String? vehicleType;
  final String? idCardUrl;
  final bool? collecteurApproved;
  final String? emergencyContact;

  // Champs spécifiques Acheteur
  final String? profession; // Eleveur, Jardinier
  final String? deliveryAddress;

  // Comptes Mobile Money consolidés (max 4)
  final List<MobileMoneyAccount> mobileMoneyAccounts;

  // Notification Push
  final String? fcmToken;

  // Real-time tracking
  final GeoPoint? currentLocation;
  final DateTime? lastLocationUpdate;

  AppUser({
    required this.id,
    required this.email,
    required this.role,
    required this.createdAt,
    this.phoneNumber = '',
    this.alternativePhone = '',
    this.fullName = '',
    this.city = '',
    this.commune = '',
    this.bio = '',
    this.balance = 0.0,
    this.restaurantName,
    this.location,
    this.vehicleType,
    this.idCardUrl,
    this.collecteurApproved,
    this.emergencyContact,
    this.profession,
    this.deliveryAddress,
    this.mobileMoneyAccounts = const [],
    this.fcmToken,
    this.currentLocation,
    this.lastLocationUpdate,
  });

  factory AppUser.fromMap(Map<String, dynamic> data, String documentId) {
    List<MobileMoneyAccount> mmAccounts = [];
    if (data['mobileMoneyAccounts'] != null) {
      mmAccounts = (data['mobileMoneyAccounts'] as List)
          .map((e) => MobileMoneyAccount.fromMap(e as Map<String, dynamic>))
          .toList();
    } else {
      // Rétrocompatibilité avec l'ancien format
      if (data['mobileMoneyNumber'] != null && data['mobileMoneyOperator'] != null) {
        mmAccounts.add(MobileMoneyAccount(
          number: data['mobileMoneyNumber'],
          operatorName: data['mobileMoneyOperator'],
        ));
      } else if (data['payoutMobileNumber'] != null && data['payoutOperator'] != null) {
        mmAccounts.add(MobileMoneyAccount(
          number: data['payoutMobileNumber'],
          operatorName: data['payoutOperator'],
        ));
      }
    }

    return AppUser(
      id: documentId,
      email: data['email'] ?? '',
      role: UserRole.values.firstWhere(
        (e) => e.toString() == 'UserRole.${data['role']}',
        orElse: () => UserRole.acheteur,
      ),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      phoneNumber: data['phoneNumber'] ?? '',
      alternativePhone: data['alternativePhone'] ?? '',
      fullName: data['fullName'] ?? '',
      city: data['city'] ?? '',
      commune: data['commune'] ?? '',
      bio: data['bio'] ?? '',
      balance: (data['balance'] ?? 0).toDouble(),
      restaurantName: data['restaurantName'],
      location: data['location'],
      vehicleType: data['vehicleType'],
      idCardUrl: data['idCardUrl'],
      collecteurApproved: data['collecteurApproved'],
      emergencyContact: data['emergencyContact'],
      profession: data['profession'],
      deliveryAddress: data['deliveryAddress'],
      mobileMoneyAccounts: mmAccounts,
      fcmToken: data['fcmToken'],
      currentLocation: data['currentLocation'],
      lastLocationUpdate: (data['lastLocationUpdate'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'role': role.toString().split('.').last,
      'createdAt': Timestamp.fromDate(createdAt),
      'phoneNumber': phoneNumber,
      'alternativePhone': alternativePhone,
      'fullName': fullName,
      'city': city,
      'commune': commune,
      'bio': bio,
      'balance': balance,
      'restaurantName': restaurantName,
      'location': location,
      'vehicleType': vehicleType,
      'idCardUrl': idCardUrl,
      'collecteurApproved': collecteurApproved,
      'emergencyContact': emergencyContact,
      'profession': profession,
      'deliveryAddress': deliveryAddress,
      'mobileMoneyAccounts': mobileMoneyAccounts.map((e) => e.toMap()).toList(),
      'fcmToken': fcmToken,
      'currentLocation': currentLocation,
      'lastLocationUpdate': lastLocationUpdate != null ? Timestamp.fromDate(lastLocationUpdate!) : null,
    };
  }

  AppUser copyWith({
    String? id,
    String? email,
    UserRole? role,
    DateTime? createdAt,
    String? phoneNumber,
    String? alternativePhone,
    String? fullName,
    String? city,
    String? commune,
    String? bio,
    double? balance,
    String? restaurantName,
    GeoPoint? location,
    String? vehicleType,
    String? idCardUrl,
    String? profession,
    String? deliveryAddress,
    String? emergencyContact,
    List<MobileMoneyAccount>? mobileMoneyAccounts,
    GeoPoint? currentLocation,
    DateTime? lastLocationUpdate,
  }) {
    return AppUser(
      id: id ?? this.id,
      email: email ?? this.email,
      role: role ?? this.role,
      createdAt: createdAt ?? this.createdAt,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      alternativePhone: alternativePhone ?? this.alternativePhone,
      fullName: fullName ?? this.fullName,
      city: city ?? this.city,
      commune: commune ?? this.commune,
      bio: bio ?? this.bio,
      balance: balance ?? this.balance,
      restaurantName: restaurantName ?? this.restaurantName,
      location: location ?? this.location,
      vehicleType: vehicleType ?? this.vehicleType,
      idCardUrl: idCardUrl ?? this.idCardUrl,
      profession: profession ?? this.profession,
      deliveryAddress: deliveryAddress ?? this.deliveryAddress,
      emergencyContact: emergencyContact ?? this.emergencyContact,
      mobileMoneyAccounts: mobileMoneyAccounts ?? this.mobileMoneyAccounts,
      fcmToken: fcmToken ?? this.fcmToken,
      currentLocation: currentLocation ?? this.currentLocation,
      lastLocationUpdate: lastLocationUpdate ?? this.lastLocationUpdate,
    );
  }

}

