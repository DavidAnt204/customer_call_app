// contact_service.dart
class Contact {
  final String name;
  final String number;

  Contact({required this.name, required this.number});
}

class ContactService {
  // Simulated data source (replace with real contacts or API)
  static final List<Contact> _contacts = [
    Contact(name: 'Alice Smith', number: '1234567890'),
    Contact(name: 'Bob Johnson', number: '9876543210'),
    Contact(name: 'Charlie Brown', number: '1122334455'),
    Contact(name: 'David Lee', number: '5556667777'),
    Contact(name: 'Eve Adams', number: '1010101010'),
  ];

  /// Returns all contacts
  List<Contact> getAllContacts() => List.unmodifiable(_contacts);

  /// Returns filtered contacts by matching name or number with [query]
  List<Contact> filterContacts(String query) {
    final lower = query.toLowerCase();
    return _contacts.where((contact) {
      return contact.name.toLowerCase().contains(lower) ||
          contact.number.contains(query);
    }).toList();
  }
}
