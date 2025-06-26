import 'package:flutter/material.dart';
import 'package:flutter_direct_call_plus/flutter_direct_call.dart';
import 'package:permission_handler/permission_handler.dart';

import '../services/contact_service.dart';

class CallDialerPage extends StatefulWidget {
  @override
  State<CallDialerPage> createState() => _CallDialerPageState();
}

class _CallDialerPageState extends State<CallDialerPage> {
  String _typedNumber = '';
  final ContactService _contactService = ContactService();
  List<Contact> get _filteredContacts =>
      _typedNumber.isEmpty ? [] : _contactService.filterContacts(_typedNumber);

  void _appendNumber(String num) {
    setState(() {
      _typedNumber += num;
    });
  }

  void _deleteNumber() {
    if (_typedNumber.isNotEmpty) {
      setState(() {
        _typedNumber = _typedNumber.substring(0, _typedNumber.length - 1);
      });
    }
  }

  void _showCallConfirmation(String number) {
    setState(() {
      _typedNumber = number;
      _makeCall();
    });
    // showDialog(
    //   context: context,
    //   builder: (context) => AlertDialog(
    //     title: Text("Call $number?"),
    //     actions: [
    //       TextButton(
    //         onPressed: () => Navigator.pop(context),
    //         child: Text("Cancel"),
    //       ),
    //       TextButton(
    //         onPressed: () async {
    //           Navigator.pop(context);
    //           final uri = Uri.parse('tel:$number');
    //           // if (await canLaunchUrl(uri)) {
    //           //   await launchUrl(uri);
    //           // }
    //         },
    //         child: Text("Call"),
    //       ),
    //     ],
    //   ),
    // );
  }

  Future<void> _makeCall() async {
    if (_typedNumber.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter phone number')),
      );
      return;
    }
    // await FlutterPhoneDirectCaller.callNumber(_typedNumber);
    PermissionStatus status = await Permission.phone.request();
    if (status.isGranted) {
     await FlutterDirectCall.makeDirectCall(_typedNumber);
    } else {
      print("Permission denied");
    }

    // final confirmed = await showDialog<bool>(
    //   context: context,
    //   builder: (context) => AlertDialog(
    //     title: const Text('Confirm Call'),
    //     content: Text('Do you want to call $_typedNumber?'),
    //     actions: [
    //       TextButton(
    //         child: const Text('Cancel'),
    //         onPressed: () => Navigator.pop(context, false),
    //       ),
    //       ElevatedButton(
    //         child: const Text('Call'),
    //         onPressed: () => Navigator.pop(context, true),
    //       ),
    //     ],
    //   ),
    // );
    //
    // if (confirmed == true) {
    //   FlutterPhoneDirectCaller.callNumber(_typedNumber);
    // final uri = Uri.parse('tel:$_typedNumber');
    // if (await canLaunchUrl(uri)) {
    //   await launchUrl(uri);
    // }
    // }
  }

  Widget _buildDialButton(String value, {String? letters}) {
    return Expanded(
      child: GestureDetector(
        onTap: () => _appendNumber(value),
        child: Container(
          margin: const EdgeInsets.all(8),
          height: 80,
          width: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.grey.shade400, width: 1.5),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(value,
                    style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w500,
                    )),
                if (letters != null)
                  Text(letters,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      )),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const numberStyle = TextStyle(
      fontSize: 36,
      fontWeight: FontWeight.bold,
      letterSpacing: 2,
    );

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Display number with delete icon
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _typedNumber,
                      textAlign: TextAlign.center,
                      style: numberStyle,
                    ),
                  ),
                  if (_typedNumber.isNotEmpty) ...[
                    IconButton(
                      icon: Icon(Icons.clear_all, color: Colors.grey[700]),
                      tooltip: 'Clear All',
                      onPressed: () => setState(() => _typedNumber = ''),
                    ),
                    IconButton(
                      icon: Icon(Icons.backspace, color: Colors.grey[700]),
                      onPressed: _deleteNumber,
                    ),
                  ]
                ],
              ),
            ),

            // Filtered contacts list
            SingleChildScrollView(
              child: SizedBox(
                height: MediaQuery.of(context).size.height * .2,
                child: _filteredContacts.isNotEmpty
                    ? ListView.builder(
                        itemCount: _filteredContacts.length,
                        itemBuilder: (context, index) {
                          final contact = _filteredContacts[index];
                          return ListTile(
                            leading: CircleAvatar(
                              child: Text(contact.name[0]),
                            ),
                            title: Text(contact.name),
                            subtitle: Text(contact.number),
                            trailing: IconButton(
                              icon: Icon(Icons.call, color: Colors.green),
                              onPressed: () =>
                                  _showCallConfirmation(contact.number),
                            ),
                          );
                        },
                      )
                    : SizedBox(),
              ),
            ),

            // Spacer if no contacts
            // if (_filteredContacts.isEmpty) const Spacer(),

            // Dialpad
            Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Row(
                  children: [
                    _buildDialButton("1"),
                    _buildDialButton("2", letters: "ABC"),
                    _buildDialButton("3", letters: "DEF"),
                  ],
                ),
                Row(
                  children: [
                    _buildDialButton("4", letters: "GHI"),
                    _buildDialButton("5", letters: "JKL"),
                    _buildDialButton("6", letters: "MNO"),
                  ],
                ),
                Row(
                  children: [
                    _buildDialButton("7", letters: "PQRS"),
                    _buildDialButton("8", letters: "TUV"),
                    _buildDialButton("9", letters: "WXYZ"),
                  ],
                ),
                Row(
                  children: [
                    _buildDialButton("*"),
                    _buildDialButton("0", letters: "+"),
                    _buildDialButton("#"),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Call button
            GestureDetector(
              onTap: _makeCall,
              child: Container(
                height: 70,
                width: 70,
                margin: const EdgeInsets.only(bottom: 30),
                decoration: BoxDecoration(
                  color: Colors.green.shade500,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.call, color: Colors.white, size: 30),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
