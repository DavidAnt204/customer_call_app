import 'package:flutter/material.dart';
import 'package:flutter_contacts_service/flutter_contacts_service.dart';
import 'package:flutter_direct_call_plus/flutter_direct_call.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

import '../screens/calling_screen.dart';

class DialerBottomSheet extends StatefulWidget {
  const DialerBottomSheet({super.key});

  @override
  State<DialerBottomSheet> createState() => _DialerBottomSheetState();
}

class _DialerBottomSheetState extends State<DialerBottomSheet> {
  String _phoneNumber = '';
  List<ContactInfo> _allContacts = [];
  List<ContactInfo> _filteredContacts = [];

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  Future<void> _loadContacts() async {
    final permission = await Permission.contacts.request();
    if (permission.isGranted) {
      final contacts =
          await FlutterContactsService.getContacts(withThumbnails: true);
      setState(() {
        _allContacts = contacts;
        _filteredContacts = contacts;
      });
    }
  }

  void _onDigitTap(String digit) {
    setState(() {
      _phoneNumber += digit;
      _filterContacts();
    });
  }

  void _onBackspace() {
    if (_phoneNumber.isNotEmpty) {
      setState(() {
        _phoneNumber = _phoneNumber.substring(0, _phoneNumber.length - 1);
        _filterContacts();
      });
    }
  }

  void _filterContacts() {
    setState(() {
      _filteredContacts = _allContacts.where((c) {
        return (c.phones ?? [])
            .any((p) => (p.value ?? '').contains(_phoneNumber));
      }).toList();
    });
  }

  Future<void> startCall(BuildContext context, String number) async {
    // Show calling screen
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CallingScreen(phoneNumber: number),
      ),
    );

    // Wait for user to see UI
    await Future.delayed(const Duration(seconds: 2));

    // Then make actual call
    await FlutterDirectCall.makeDirectCall(number);
  }


  Future<void> _makeCall() async {
    if (_phoneNumber.isEmpty) return;
    PermissionStatus status = await Permission.phone.request();
    if (status.isGranted) {
      await startCall(context, _phoneNumber);
      // await FlutterDirectCall.makeDirectCall(_phoneNumber);
    } else {
      print("Permission denied");
      const SnackBar(content: Text('Could not make the call'));
    }
    // final uri = Uri(scheme: 'tel', path: _phoneNumber);
    // if (await canLaunchUrl(uri)) {
    //   await launchUrl(uri);
    // } else {
    //   ScaffoldMessenger.of(context).showSnackBar(
    //     const SnackBar(content: Text('Could not make the call')),
    //   );
    // }
  }

  @override
  Widget build(BuildContext context) {
    const keys = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '*', '0', '#'];
    const dialLetters = {
      '1': '',
      '2': 'ABC',
      '3': 'DEF',
      '4': 'GHI',
      '5': 'JKL',
      '6': 'MNO',
      '7': 'PQRS',
      '8': 'TUV',
      '9': 'WXYZ',
      '0': '+',
      '*': '',
      '#': ''
    };

    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.92,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Column(
          children: [
            // Drag Handle
            Container(
              width: 40,
              height: 5,
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: Colors.grey[400],
                borderRadius: BorderRadius.circular(10),
              ),
            ),

            // Dialed number & backspace
            Row(
              children: [
                Expanded(
                  child: Text(
                    _phoneNumber,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 28, fontWeight: FontWeight.w500),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.backspace_outlined),
                  onPressed: _onBackspace,
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Contact suggestions
            Expanded(
              child: ListView.separated(
                itemCount: _filteredContacts.length,
                separatorBuilder: (_, __) => const Divider(),
                itemBuilder: (_, i) {
                  final c = _filteredContacts[i];
                  final number = (c.phones?.isNotEmpty ?? false)
                      ? (c.phones!.first.value ?? '')
                      : 'No number';
                  return ListTile(
                    title: Text(c.displayName ?? 'Unknown'),
                    subtitle: Text(number),
                    leading: CircleAvatar(
                      child: Text(
                        (c.displayName?.substring(0, 1) ?? '?').toUpperCase(),
                      ),
                    ),
                    onTap: () {
                      setState(() {
                        _phoneNumber = number;
                        _filterContacts();
                      });
                    },
                  );
                },
              ),
            ),

            const Divider(),

            // Dial pad
            // Dial pad
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
              children: keys.map((key) {
                return GestureDetector(
                  onTap: () => _onDigitTap(key),
                  child: Container(
                    margin: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.grey[200],
                    ),
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          key,
                          style: const TextStyle(
                              fontSize: 24, fontWeight: FontWeight.bold),
                        ),
                        if (dialLetters[key]!.isNotEmpty)
                          Text(
                            dialLetters[key]!,
                            style: const TextStyle(
                                fontSize: 10, color: Colors.grey),
                          ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),

            // Call button
            const SizedBox(height: 10),
            ElevatedButton.icon(
              onPressed: _makeCall,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              ),
              icon: const Icon(Icons.call, size: 24),
              label: const Text(
                'CALL',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
