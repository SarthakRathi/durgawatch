import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:telephony/telephony.dart';
import 'package:url_launcher/url_launcher.dart';

/// Local enum to represent possible coverage states
enum MobileServiceState {
  inService,
  outOfService,
  emergencyOnly,
  powerOff,
  unknown,
}

class StageSmsService {
  static final Telephony telephony = Telephony.instance;

  /// Main entry point to send Stage 2/3 SMS:
  static Future<void> sendStageSMS({
    required int stageNumber,
    required double lat,
    required double lng,
    required String userUid,
  }) async {
    try {
      // 1) Check coverage
      final coverageOk = await _isCoverageAvailable();
      if (!coverageOk) {
        print('No coverage => fallback to dialer...');
        await _launchEmergencyDialer();
        return; // stop here
      }

      // 2) Gather phone numbers from Firestore (both phone-type & email-type contacts)
      final phoneNumbers = await _collectPhoneNumbers(userUid);
      if (phoneNumbers.isEmpty) {
        print('No valid phone numbers. SMS not sent.');
        return;
      }

      // 3) Request SEND_SMS permission (Android only).
      final granted = await telephony.requestSmsPermissions ?? false;
      if (!granted) {
        print('SMS permission denied. Not sending text messages.');
        return;
      }

      // 4) Build & send the SMS
      final stageText = (stageNumber == 2)
          ? 'Stage 2 ALERT (Approx location)'
          : 'Stage 3 ALERT (Precise location)';
      final mapLink = 'https://maps.google.com/?q=$lat,$lng';

      final message = 'DurgaWatch $stageText!\n'
          'I need help now.\n'
          'Location: $mapLink';

      for (final phoneNumber in phoneNumbers) {
        await telephony.sendSms(to: phoneNumber, message: message);
        print('SMS sent to $phoneNumber');
      }

      print('Stage $stageNumber SMS sent to all contacts.');
    } catch (e) {
      print('Error sending Stage $stageNumber SMS: $e');
      // Optional: fallback to dialer
      // await _launchEmergencyDialer();
    }
  }

  /// Collect all phone numbers from the user’s /contacts subcollection.
  /// - If the contact doc has `"type":"phone"`, read `doc['phone']` directly.
  /// - If `"type":"email"`, read `doc['uid']` => /users/{thatUid} => fetch phone from there.
  static Future<List<String>> _collectPhoneNumbers(String userUid) async {
    final results = <String>[];

    final contactsSnap = await FirebaseFirestore.instance
        .collection('users')
        .doc(userUid)
        .collection('contacts')
        .get();

    if (contactsSnap.docs.isEmpty) return results; // empty list

    for (var doc in contactsSnap.docs) {
      final data = doc.data();
      final contactType = data['type'] as String? ?? 'unknown';

      if (contactType == 'phone') {
        // 1) Direct phone contact, e.g.: {type:'phone', phone:'+1234567890'}
        final phone = data['phone'] as String?;
        if (phone != null && phone.isNotEmpty) {
          results.add(phone);
        }
      } else if (contactType == 'email') {
        // 2) Email contact, e.g.: {type:'email', email:'user@...', uid:'someUID'}
        final contactUid = data['uid'] as String?;
        if (contactUid == null || contactUid.isEmpty) {
          continue;
        }
        // We look up /users/{contactUid}
        final userSnap = await FirebaseFirestore.instance
            .collection('users')
            .doc(contactUid)
            .get();
        if (userSnap.exists) {
          final userData = userSnap.data()!;
          final phone = userData['phone'] as String?;
          if (phone != null && phone.isNotEmpty) {
            results.add(phone);
          }
        }
      }
    }

    return results;
  }

  /// Returns true if we are "in service" (normal coverage).
  static Future<bool> _isCoverageAvailable() async {
    try {
      final serviceState = await telephony.serviceState;
      if (serviceState == null) {
        print('serviceState is null => no coverage');
        return false;
      }

      // Convert it to an int index
      final rawValue = serviceState.index; // 0..3
      final stateEnum = _mapIntToMobileServiceState(rawValue);
      print('serviceState = $serviceState (raw=$rawValue) => $stateEnum');

      return (stateEnum == MobileServiceState.inService);
    } catch (e) {
      print('Error checking coverage: $e');
      return false;
    }
  }

  static MobileServiceState _mapIntToMobileServiceState(int state) {
    switch (state) {
      case 0:
        return MobileServiceState.inService;
      case 1:
        return MobileServiceState.outOfService;
      case 2:
        return MobileServiceState.emergencyOnly;
      case 3:
        return MobileServiceState.powerOff;
      default:
        return MobileServiceState.unknown;
    }
  }

  /// Actually attempt to open the dialer with "tel:112".
  static Future<void> _launchEmergencyDialer() async {
    print('Trying to open dialer with tel:112...');
    final uri = Uri(scheme: 'tel', path: '112');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
      print('Dialer launched successfully.');
    } else {
      print('Could not launch dialer for "112"');
    }
  }
}
