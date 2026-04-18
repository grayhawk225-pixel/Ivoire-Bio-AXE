import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  final baseUrl = "https://sandbox-api.fedapay.com/v1";
  final key = "sk_sandbox_pb1JPxfGFD5Z20LTTmBBiqRl";

  // Simulate FedaPayService.sendPayout
  final amount = 500.0;
  final currency = "XOF";
  final mode = "mtn_ci"; // Using typical CI mode
  final email = "collecteur@bioaxe.test";
  final phone = "0702030405";

  print('Création Payout...');
  final response = await http.post(
    Uri.parse('$baseUrl/payouts'),
    headers: {
      'Authorization': 'Bearer $key',
      'Content-Type': 'application/json',
    },
    body: jsonEncode({
      "amount": amount.toInt(),
      "currency": {"iso": currency},
      "mode": mode,
      "customer": {
        "firstname": "Collecteur",
        "lastname": "BioAxe",
        "email": email,
        "phone_number": {"number": phone, "country": "CI"}
      }
    }),
  );

  print('STATUS: ${response.statusCode}');
  print('BODY: ${response.body}');
  
  if (response.statusCode == 200 || response.statusCode == 201) {
    final data = jsonDecode(response.body);
    final id = data['v1/payout']?['id']?.toString();
    print('Payout ID: $id');
    
    if (id != null) {
      print('Sending Payout...');
      final sendResp = await http.put(
        Uri.parse('$baseUrl/payouts/$id/send'),
        headers: {'Authorization': 'Bearer $key'},
      );
      print('SEND STATUS: ${sendResp.statusCode}');
      print('SEND BODY: ${sendResp.body}');
    }
  }
}
