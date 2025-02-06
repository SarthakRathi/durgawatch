// lib/police_view_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PoliceViewScreen extends StatelessWidget {
  const PoliceViewScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Police View'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('threats')
            .where('isActive', isEqualTo: true)
            .where('stageNumber', whereIn: [2, 3]).snapshots(),
        builder: (ctx, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
                child: Text('No active Stage 2/3 threats found.'));
          }

          final threatDocs = snapshot.data!.docs;

          return ListView.builder(
            itemCount: threatDocs.length,
            itemBuilder: (ctx, index) {
              final doc = threatDocs[index];
              final data = doc.data() as Map<String, dynamic>;
              final userId = data['userId'] ?? doc.id;
              final stageNum = data['stageNumber'] ?? '?';
              final userName = data['userName'] ?? 'Unknown';

              return Card(
                margin: const EdgeInsets.all(12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 5,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Stage $stageNum Threat',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: stageNum == 3 ? Colors.red : Colors.orange,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text('User: $userName'),
                      const SizedBox(height: 8),
                      // show user details + profile photo
                      _buildUserDetails(userId),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerRight,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            // Navigate to map with this user's uid
                            Navigator.pushNamed(
                              context,
                              '/map',
                              arguments: userId,
                            );
                          },
                          icon: const Icon(Icons.location_on),
                          label: const Text('Check Location'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blueGrey,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildUserDetails(String userId) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(userId).get(),
      builder: (ctx, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Text('Loading user details...',
              style: TextStyle(color: Colors.grey));
        }
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const Text('No user details found.');
        }

        final userData = snapshot.data!.data() as Map<String, dynamic>;
        final email = userData['email'] ?? 'No Email';
        final phone = userData['phone'] ?? 'No Phone';
        final address = userData['address'] ?? 'No Address';
        final photoUrl = userData['photoUrl'] ?? '';

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Show the photo if we have a url, else an icon
            CircleAvatar(
              radius: 24,
              backgroundColor: Colors.grey[300],
              backgroundImage:
                  photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
              child: (photoUrl.isEmpty)
                  ? const Icon(Icons.person, size: 24, color: Colors.grey)
                  : null,
            ),
            const SizedBox(width: 12),
            // The user contact details in a column
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Email: $email'),
                  Text('Phone: $phone'),
                  Text('Address: $address'),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
