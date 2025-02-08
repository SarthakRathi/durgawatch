// lib/stage_sms_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:telephony/telephony.dart';

class StageSmsService {
  static final Telephony telephony = Telephony.instance;

  /// Sends an automatic SMS to all emergency contacts.
  ///
  /// [stageNumber] is 2 or 3.
  /// [lat, lng] is the user’s current location.
  /// [userUid] is the UID of the user who triggered the stage.
  static Future<void> sendStageSMS({
    required int stageNumber,
    required double lat,
    required double lng,
    required String userUid,
  }) async {
    try {
      final contactsSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(userUid)
          .collection('contacts')
          .get();

      if (contactsSnap.docs.isEmpty) {
        print('No emergency contacts found. SMS not sent.');
        return;
      }

      final phoneNumbers = <String>[];
      for (var doc in contactsSnap.docs) {
        final contactUid = doc.id;
        final contactUserSnap = await FirebaseFirestore.instance
            .collection('users')
            .doc(contactUid)
            .get();
        if (contactUserSnap.exists) {
          final contactData = contactUserSnap.data()!;
          final phone = contactData['phone'] as String?;
          if (phone != null && phone.isNotEmpty) {
            phoneNumbers.add(phone);
          }
        }
      }
      if (phoneNumbers.isEmpty) {
        print('No phone numbers. Cannot send Stage $stageNumber SMS.');
        return;
      }

      // Request SEND_SMS permission (Android only).
      final granted = await telephony.requestSmsPermissions ?? false;
      if (!granted) {
        print('SEND_SMS permission denied. SMS not sent.');
        return;
      }

      final stageText = (stageNumber == 2)
          ? 'Stage 2 ALERT (Approx location)'
          : 'Stage 3 ALERT (Precise location)';

      final mapLink = 'https://maps.google.com/?q=$lat,$lng';

      final message = 'DurgaWatch $stageText!\n'
          'I need help now.\n'
          'Location: $mapLink';

      // Send the SMS to each phone number
      for (final phoneNumber in phoneNumbers) {
        await telephony.sendSms(
          to: phoneNumber,
          message: message,
        );
        print('SMS sent to $phoneNumber');
      }

      print('Stage $stageNumber SMS sent to all contacts.');
    } catch (e) {
      print('Error sending Stage $stageNumber SMS: $e');
    }
  }
}
