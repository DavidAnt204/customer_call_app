import 'package:flutter/material.dart';
import 'package:flutter_contacts_service/flutter_contacts_service.dart';
import 'package:permission_handler/permission_handler.dart';

class ContactListPage extends StatefulWidget {
  const ContactListPage({super.key});

  @override
  State<ContactListPage> createState() => _ContactListPageState();
}

class _ContactListPageState extends State<ContactListPage> {
  List<ContactInfo> _contacts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  Future<void> _loadContacts() async {
    final status = await Permission.contacts.request();
    if (status.isGranted) {
      List<ContactInfo> contacts =
          await FlutterContactsService.getContacts(withThumbnails: false);
      setState(() {
        _contacts = contacts;
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _isLoading
        ? const Center(child: CircularProgressIndicator())
        : _contacts.isEmpty
            ? const Center(child: Text("No contacts found"))
            : ListView.builder(
                itemCount: _contacts.length,
                itemBuilder: (context, index) {
                  final contact = _contacts[index];
                  final phone = contact.phones!.isNotEmpty
                      ? contact.phones!.first.value
                      : 'No number';

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.blue.shade100,
                      child: Text(
                        contact.displayName?.substring(0, 1).toUpperCase() ??
                            '?',
                        style: const TextStyle(color: Colors.black),
                      ),
                    ),
                    title: Text(contact.displayName ?? 'No Name'),
                    subtitle: Text(phone!),
                  );
                },
              );
  }
}
