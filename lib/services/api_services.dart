import 'dart:convert';
import 'dart:typed_data';
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

class PunchService {
  static Future<Map<String, dynamic>> punchIn({
    required String userId,
    required String location,
    required Uint8List imageBytes,
  }) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('https://crm.vasaantham.com/api/punch_in'),
      );

      request.fields['user_id'] = userId;
      request.fields['punch_in_location'] = location;

      request.files.add(
        http.MultipartFile.fromBytes(
          'punch_in_image',
          imageBytes,
          filename: 'selfie_${DateTime.now().millisecondsSinceEpoch}.jpg',
        ),
      );

      print(
          'Sending Punch In request... ${request.fields} ${request.files.first.filename}');
      final streamedResponse = await request.send();

      final respStr = await streamedResponse.stream.bytesToString();
      print('Status: ${streamedResponse.statusCode}');
      print('Response: $respStr');

      return {
        'statusCode': streamedResponse.statusCode,
        'body': respStr,
      };
    } catch (e) {
      print('Punch In Error: $e');
      return {
        'statusCode': 500,
        'body': '{"error":"$e"}',
      };
    }
  }

  static Future<Map<String, dynamic>> punchOut({
    required String userId,
    required String location,
    required Uint8List imageBytes,
  }) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('https://crm.vasaantham.com/api/punch_out'),
      );

      request.fields['user_id'] = userId;
      request.fields['punch_out_location'] = location;

      request.files.add(
        http.MultipartFile.fromBytes(
          'punch_out_image',
          imageBytes,
          filename: 'selfie_${DateTime.now().millisecondsSinceEpoch}.jpg',
        ),
      );

      print(
          'Sending Punch In request... ${request.fields} ${request.files.first.filename}');
      final streamedResponse = await request.send();

      final respStr = await streamedResponse.stream.bytesToString();
      print('Status: ${streamedResponse.statusCode}');
      print('Response: $respStr');

      return {
        'statusCode': streamedResponse.statusCode,
        'body': respStr,
      };
    } catch (e) {
      print('Punch In Error: $e');
      return {
        'statusCode': 500,
        'body': '{"error":"$e"}',
      };
    }
  }
}

class Attendance {
  final String userId;
  final String attendanceDate;
  final String punchIn;
  final String punchInLocation;
  final String punchInImage;
  final String punchOut;
  final String punchOutLocation;
  final String punchOutImage;

  Attendance({
    required this.userId,
    required this.attendanceDate,
    required this.punchIn,
    required this.punchInLocation,
    required this.punchInImage,
    required this.punchOut,
    required this.punchOutLocation,
    required this.punchOutImage,
  });

  factory Attendance.fromJson(Map<String, dynamic> json) {
    return Attendance(
      userId: json['user_id'] ?? '',
      attendanceDate: json['attendance_date'] ?? '',
      punchIn: json['punch_in'] ?? '',
      punchInLocation: json['punch_in_location'] ?? '',
      punchInImage: json['punch_in_image'] ?? '',
      punchOut: json['punch_out'] ?? '',
      punchOutLocation: json['punch_out_location'] ?? '',
      punchOutImage: json['punch_out_image'] ?? '',
    );
  }
}

class AttendanceService {
  final String baseUrl = 'https://crm.vasaantham.com/api';

  Future<Attendance?> getTodayAttendance(String userId) async {
    final url = Uri.parse('$baseUrl/attendance_today/$userId');

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print(data);
        return Attendance.fromJson(data);
      } else {
        print("Error: ${response.statusCode}");
        return null;
      }
    } catch (e) {
      print("Exception: $e");
      return null;
    }
  }
}

class LeadService {
  static const String baseUrl = 'https://crm.vasaantham.com/api';

  Future<Map<String, dynamic>> saveLead({
    required int source,
    required int status,
    required int assigned,
    required String phoneNumber,
    required String name,
  }) async {
    final url = Uri.parse('$baseUrl/save_lead');

    if (phoneNumber.startsWith('+91')) {
      phoneNumber = phoneNumber.substring(3); // removes first 3 chars '+91'
    }

    final payload = {
      "source": source,
      "status": status,
      "assigned": assigned,
      "phonenumber": phoneNumber,
      "name": name
    };

    print('payload ${payload}');

    try {
      final response = await http.post(
        url,
        headers: {
          "Content-Type": "application/json",
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body);
      } else {
        throw Exception(
          'Failed to save lead: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      print('HTTP error: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getSources() async {
    final response = await http.get(Uri.parse('https://crm.vasaantham.com/api/get_sources'));

    if (response.statusCode == 200) {
      List<dynamic> data = jsonDecode(response.body);
      return data.map((item) => {
        'id': item['id'],
        'text': item['name'],
      }).toList();
    } else {
      throw Exception('Failed to load sources');
    }
  }

  // Fetch Lead Statuses
  Future<List<Map<String, dynamic>>> getStatuses() async {
    final response = await http.get(Uri.parse('https://crm.vasaantham.com/api/get_all_lead_statuses'));

    if (response.statusCode == 200) {
      List<dynamic> data = jsonDecode(response.body);
      return data.map((item) => {
        'id': item['id'],
        'text': item['name'],
      }).toList();
    } else {
      throw Exception('Failed to load statuses');
    }
  }

  // Fetch lead data using the leadId
  Future<Map<String, dynamic>> getLeadData(String leadId) async {
    final url = Uri.parse('$baseUrl/get_lead/$leadId'); // API endpoint

    try {
      final response = await http.get(url);

      // Check if the response is successful
      if (response.statusCode == 200) {
        // Decode the JSON response to a map
        final Map<String, dynamic> leadData = json.decode(response.body);
        return leadData; // Return the fetched lead data
      } else {
        // If the server returns an error, throw an exception
        throw Exception('Failed to load lead data');
      }
    } catch (e) {
      // Catch any error that occurs during the request
      throw Exception('Error fetching lead data: $e');
    }
  }

  // Update the lead using PATCH request
  Future<Map<String, dynamic>> updateLead({
    required String leadId,
    required int source,
    required int status,
    required int assigned,
    required String phoneNumber,
    required String name,
  }) async {
    // Prepare the request body
    final Map<String, dynamic> body = {
      'source': source,
      'status': status,
      'assigned': assigned,
      'phonenumber': phoneNumber,
      'name': name,
    };

    try {
      // Debugging: Check URL and body
      print('Updating lead with ID: $leadId');
      print('Request body: $body');
      print('${baseUrl}/update_lead/$leadId');

      // Send the PATCH request
      final response = await http.patch(
        Uri.parse('${baseUrl}/update_lead/$leadId'),  // Ensure the leadId is properly inserted
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode(body),
      );

      // Check if response status is OK
      if (response.statusCode == 200) {
        // If successful, return the decoded JSON response
        return json.decode(response.body);
      } else {
        // Debugging: Check for error in response
        print('Error response: ${response.body}');
        throw Exception('Failed to update lead: ${response.body}');
      }
    } catch (e) {
      // Print error details for debugging
      print('Error: $e');
      throw Exception('Error updating lead: $e');
    }
  }
}
