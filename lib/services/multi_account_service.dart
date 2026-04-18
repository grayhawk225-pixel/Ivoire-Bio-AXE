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

final multiAccountProvider = NotifierProvider<MultiAccountNotifier, List<SavedAccount>>(() {
  return MultiAccountNotifier();
});

class MultiAccountNotifier extends Notifier<List<SavedAccount>> {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  static const String _accountsKey = 'bioaxe_saved_accounts';

  @override
  List<SavedAccount> build() {
    _loadAccounts();
    return [];
  }

  Future<void> _loadAccounts() async {
    try {
      final data = await _storage.read(key: _accountsKey);
      if (data != null) {
        final List<dynamic> jsonList = jsonDecode(data);
        state = jsonList.map((e) => SavedAccount.fromMap(e as Map<String, dynamic>)).toList();
      }
    } catch (e) {
      print('Erreur lors du chargement des comptes sauvegardés : $e');
    }
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
    // Retirer s'il existe déjà pour éviter les doublons puis ajouter à la fin
    final newList = state.where((acc) => acc.uid != account.uid).toList();
    newList.add(account);
    state = newList;
    await _saveToStorage(newList);
  }

  Future<void> removeAccount(String uid) async {
    final newList = state.where((acc) => acc.uid != uid).toList();
    state = newList;
    await _saveToStorage(newList);
  }
  
  SavedAccount? getAccountByUid(String uid) {
    try {
      return state.firstWhere((acc) => acc.uid == uid);
    } catch (e) {
      return null;
    }
  }
}
