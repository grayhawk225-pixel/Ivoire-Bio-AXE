import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SavedAccount {
  final String uid;
  final String email;
  final String password;
  final String role;
  final String identifier; // Ex: Numéro de tel ou nom pour l'affichage

  SavedAccount({
    required this.uid,
    required this.email,
    required this.password,
    required this.role,
    required this.identifier,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'password': password,
      'role': role,
      'identifier': identifier,
    };
  }

  factory SavedAccount.fromMap(Map<String, dynamic> map) {
    return SavedAccount(
      uid: map['uid'] ?? '',
      email: map['email'] ?? '',
      password: map['password'] ?? '',
      role: map['role'] ?? '',
      identifier: map['identifier'] ?? '',
    );
  }
}

// Déplacé en bas pour plus de clarté

/// Notifier pour gérer l'état de transition lors d'un changement de compte.
class SwitchingAccountNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void update(bool value) {
    state = value;
  }
}

/// Provider pour suivre l'état de transition lors d'un changement de compte.
/// Permet d'éviter le "flash" de l'écran de login dans AuthWrapper.
final isSwitchingAccountProvider = NotifierProvider<SwitchingAccountNotifier, bool>(() {
  return SwitchingAccountNotifier();
});

class MultiAccountNotifier extends AsyncNotifier<List<SavedAccount>> {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  static const String _accountsKey = 'bioaxe_saved_accounts';

  @override
  Future<List<SavedAccount>> build() async {
    return _loadAccounts();
  }

  Future<List<SavedAccount>> _loadAccounts() async {
    try {
      final data = await _storage.read(key: _accountsKey);
      if (data != null) {
        final List<dynamic> jsonList = jsonDecode(data);
        return jsonList.map((e) => SavedAccount.fromMap(e as Map<String, dynamic>)).toList();
      }
    } catch (e) {
      print('Erreur lors du chargement des comptes sauvegardés : $e');
    }
    return [];
  }

  Future<void> _saveToStorage(List<SavedAccount> accounts) async {
    try {
      final jsonList = accounts.map((e) => e.toMap()).toList();
      await _storage.write(key: _accountsKey, value: jsonEncode(jsonList));
    } catch (e) {
      print('Erreur de sauvegarde sécurisée : $e');
    }
  }

  Future<void> saveAccount(SavedAccount account) async {
    // S'assurer que le chargement initial (build) est terminé avant de modifier
    final currentAccounts = await future;
    
    final newList = currentAccounts.where((acc) => acc.uid != account.uid).toList();
    newList.add(account);
    state = AsyncValue.data(newList);
    await _saveToStorage(newList);
  }

  Future<void> removeAccount(String uid) async {
    final currentAccounts = await future;
    final newList = currentAccounts.where((acc) => acc.uid != uid).toList();
    state = AsyncValue.data(newList);
    await _saveToStorage(newList);
  }
}

final multiAccountProvider = AsyncNotifierProvider<MultiAccountNotifier, List<SavedAccount>>(() {
  return MultiAccountNotifier();
});
