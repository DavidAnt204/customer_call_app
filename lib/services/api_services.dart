import 'dart:convert';
import 'package:call_log/call_log.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

DateFormat dateFormat = DateFormat("yyyy-MM-dd HH:mm:ss");

Map<String, dynamic> callLogEntryToJson(CallLogEntry entry) {
  return {
    "name": entry.name,
    "number": entry.number,
    "duration": entry.duration,
    "timestamp": entry.timestamp,
    "callType": entry.callType.toString(), // convert enum to string
    "formattedNumber": entry.formattedNumber,
    "phoneAccountId": entry.phoneAccountId,
    // add more fields if needed
  };
}

Future<bool> saveCallHistory({
  required String staffId,
  required String leadId,
  required Map<String, dynamic> callHistory,
}) async {
  try {
    final url = Uri.parse('https://crm.vasaantham.com/api/save_call_history');
    String currentDateTime = dateFormat.format(DateTime.now());
    print('API call URL: $url');

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        "staffid": int.parse(staffId),
        "lead_id": int.parse(leadId),
        "call_history": callHistory,
        // "created_at": currentDateTime,
      }),
    );

    print('Response status: ${response.statusCode}');
    print('Response body: ${response.body}');

    return response.statusCode == 200 || response.statusCode == 201;
  } catch (e) {
    print('Error calling API: $e');
    return false;
  }
}
