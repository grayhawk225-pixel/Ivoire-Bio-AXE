import 'dart:convert';
import 'package:http/http.dart' as http;

const String firestoreBaseUrl =
    'https://firestore.googleapis.com/v1/projects/ivoire-bio-axe/databases/(default)/documents';

void main() async {
  // Get all users
  final response = await http.get(Uri.parse('$firestoreBaseUrl/users'));
  if (response.statusCode == 200) {
    final data = jsonDecode(response.body);
    final documents = data['documents'] as List<dynamic>?;
    if (documents != null) {
      for (var doc in documents) {
        final fields = doc['fields'];
        if (fields != null && fields['role']?['stringValue'] == 'collecteur') {
          // Update balance
          final name = doc['name'];
          fields['balance'] = {'doubleValue': 25000.0};
          
          await http.patch(
            Uri.parse('https://firestore.googleapis.com/v1/$name'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'fields': fields}),
          );
          print('✅ Solde de 25000 F ajouté pour le profil: $name');
        }
      }
    }
  }
}
