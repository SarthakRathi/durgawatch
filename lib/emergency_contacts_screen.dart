import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class EmergencyContactsScreen extends StatefulWidget {
  const EmergencyContactsScreen({super.key});

  @override
  State<EmergencyContactsScreen> createState() =>
      _EmergencyContactsScreenState();
}

class _EmergencyContactsScreenState extends State<EmergencyContactsScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animationController;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  /// Show a dialog to add or edit a contact.
  /// If `isPhone = false`, we treat [initialValue] as email and do a user lookup.
  /// If `isPhone = true`, we treat [initialValue] as phone number (no user lookup).
  void _showAddContactDialog({
    String? docId,
    bool isPhone = false,
    String? initialValue,
  }) {
    final ctrl = TextEditingController(text: initialValue ?? '');

    showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            docId == null
                ? 'Add ${isPhone ? 'Phone' : 'Email'} Contact'
                : 'Edit ${isPhone ? 'Phone' : 'Email'} Contact',
          ),
          content: TextField(
            controller: ctrl,
            keyboardType:
                isPhone ? TextInputType.phone : TextInputType.emailAddress,
            decoration: InputDecoration(
              labelText: isPhone ? 'Phone number' : 'Email',
              hintText:
                  isPhone ? 'e.g. +1 123 456 7890' : 'e.g. name@example.com',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final textVal = ctrl.text.trim();
                if (textVal.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please enter a valid value.'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                Navigator.pop(ctx); // Close the dialog

                // Now handle the save logic
                try {
                  final currentUser = FirebaseAuth.instance.currentUser;
                  if (currentUser == null) return;

                  final contactsRef = FirebaseFirestore.instance
                      .collection('users')
                      .doc(currentUser.uid)
                      .collection('contacts');

                  // If this contact is a PHONE contact, just store phone.
                  if (isPhone) {
                    // If adding new (docId == null), generate new doc
                    if (docId == null) {
                      await contactsRef.add({
                        'type': 'phone',
                        'phone': textVal,
                        'createdAt': FieldValue.serverTimestamp(),
                      });
                    } else {
                      // editing existing doc
                      await contactsRef.doc(docId).update({
                        'type': 'phone',
                        'phone': textVal,
                      });
                    }
                  } else {
                    // EMAIL logic:
                    // 1) Look up user doc with that email (lowercased if needed)
                    final query = await FirebaseFirestore.instance
                        .collection('users')
                        .where('email', isEqualTo: textVal)
                        .limit(1)
                        .get();

                    if (query.docs.isEmpty) {
                      // no user found => store anyway as a normal "unregistered" email contact,
                      // or show an error. It's up to you. If you want to store,
                      // just remove the user doc logic:
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('No user found with that email.'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return; // stop saving
                    }

                    final targetDoc = query.docs.first;
                    final bUid = targetDoc.id; // their user UID

                    if (docId == null) {
                      await contactsRef.doc(bUid).set({
                        'type': 'email',
                        'email': textVal,
                        'uid': bUid,
                        'createdAt': FieldValue.serverTimestamp(),
                      });
                    } else {
                      await contactsRef.doc(docId).update({
                        'type': 'email',
                        'email': textVal,
                        'uid': bUid,
                      });
                    }
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to save contact: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteContact(String docId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('contacts')
          .doc(docId)
          .delete();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete contact: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('No user is logged in.')),
      );
    }

    // query user’s own subcollection
    final contactsQuery = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('contacts')
        .orderBy('createdAt', descending: true);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Emergency Contacts',
          style: TextStyle(color: Colors.black),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.black),
      ),

      // Two options for floatingActionButton:
      //  1) use a PopupMenuButton
      //  2) add multiple FABs using a SpeedDial package
      // For simplicity, let's add a single FAB that shows a menu:
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () {
          // Show a bottom sheet or a simple dialog to choose:
          showModalBottomSheet(
            context: context,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            builder: (ctx) {
              return SizedBox(
                height: 140,
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.phone),
                      title: const Text('Add Phone Contact'),
                      onTap: () {
                        Navigator.pop(ctx);
                        _showAddContactDialog(isPhone: true);
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.email),
                      title: const Text('Add Email Contact'),
                      onTap: () {
                        Navigator.pop(ctx);
                        _showAddContactDialog(isPhone: false);
                      },
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),

      body: Container(
        // Gradient background (optional)
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Theme.of(context).primaryColor.withOpacity(0.1),
              Colors.white,
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: StreamBuilder<QuerySnapshot>(
                stream: contactsQuery.snapshots(),
                builder: (ctx, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: Text('No contacts found.'));
                  }
                  final docs = snapshot.data!.docs;
                  if (docs.isEmpty) {
                    return const Center(
                      child: Text('No contacts. Add one!'),
                    );
                  }

                  return ListView.builder(
                    itemCount: docs.length,
                    itemBuilder: (ctx, index) {
                      final doc = docs[index];
                      final docId = doc.id;
                      final data = doc.data() as Map<String, dynamic>;

                      final contactType = data['type'] ?? 'unknown';
                      final email = data['email'] as String?;
                      final phone = data['phone'] as String?;
                      final uid = data['uid'] as String?; // For email contacts

                      // Build display text
                      String mainText = 'N/A';
                      String subtitle = '';
                      if (contactType == 'phone' && phone != null) {
                        mainText = phone;
                        subtitle = '(Phone)';
                      } else if (contactType == 'email' && email != null) {
                        mainText = email;
                        subtitle = '(Email)';
                        if (uid != null) {
                          subtitle += ' - UID: $uid';
                        }
                      }

                      return Card(
                        elevation: 4,
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: ListTile(
                          title: Text(mainText),
                          subtitle: Text(subtitle),
                          trailing: PopupMenuButton<String>(
                            onSelected: (value) {
                              if (value == 'edit') {
                                if (contactType == 'phone') {
                                  _showAddContactDialog(
                                    docId: docId,
                                    isPhone: true,
                                    initialValue: phone,
                                  );
                                } else {
                                  _showAddContactDialog(
                                    docId: docId,
                                    isPhone: false,
                                    initialValue: email,
                                  );
                                }
                              } else if (value == 'delete') {
                                _deleteContact(docId);
                              }
                            },
                            itemBuilder: (ctx) => [
                              const PopupMenuItem(
                                value: 'edit',
                                child: Text('Edit'),
                              ),
                              const PopupMenuItem(
                                value: 'delete',
                                child: Text('Delete'),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
