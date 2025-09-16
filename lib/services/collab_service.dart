import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';
import '../models/collab_model.dart';

class CollaborationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Create collaboration request from craft request
  Future<String> createCollaborationRequest(CollaborationRequest request) async {
  try {
    // Convert the request to a map but handle timestamps properly
    final requestMap = request.toMap();
    
    // Create the collaboration project
    final docRef = await _firestore
        .collection('collaboration_projects')
        .add(requestMap);

    // Update the original craft request to mark it as opened for collaboration
    await _firestore
        .collection('craft_requests')
        .doc(request.originalRequestId)
        .update({
      'isOpenForCollaboration': true,
      'collaborationProjectId': docRef.id,
      'leadArtisanId': request.leadArtisanId,
      'collaborationStatus': 'open',
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Create a notification for potential collaborators (optional)
    await _createCollaborationAnnouncementNotification(request, docRef.id);

    return docRef.id;
  } catch (e) {
    throw Exception('Failed to create collaboration request: $e');
  }
}

  // Get open collaboration requests for browsing
  Stream<List<CollaborationRequest>> getOpenCollaborationRequests() {
    return _firestore
        .collection('collaboration_projects')
        .where('status', isEqualTo: 'open')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => CollaborationRequest.fromMap({
                  ...doc.data(),
                  'id': doc.id,
                }))
            .toList());
  }

  // Get collaboration requests where current user is lead artisan
  Stream<List<CollaborationRequest>> getMyLeadCollaborations() {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      return Stream.value([]);
    }

    return _firestore
        .collection('collaboration_projects')
        .where('leadArtisanId', isEqualTo: currentUser.uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => CollaborationRequest.fromMap({
                  ...doc.data(),
                  'id': doc.id,
                }))
            .toList());
  }

  // Get collaboration requests where current user is a collaborator
  Stream<List<CollaborationRequest>> getMyCollaborations() {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      return Stream.value([]);
    }

    return _firestore
        .collection('collaboration_projects')
        .where('collaboratorIds', arrayContains: currentUser.uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => CollaborationRequest.fromMap({
                  ...doc.data(),
                  'id': doc.id,
                }))
            .toList());
  }

  // Apply for a collaboration role
  Future<void> applyForRole(CollaborationApplication application) async {
  try {
    // Check if user already applied for this role
    final existingApplications = await _firestore
        .collection('collaboration_projects')
        .doc(application.collaborationRequestId)
        .collection('applications')
        .where('artisanId', isEqualTo: application.artisanId)
        .where('roleId', isEqualTo: application.roleId)
        .get();

    if (existingApplications.docs.isNotEmpty) {
      throw Exception('You have already applied for this role');
    }

    // Convert application to map
    final applicationMap = application.toMap();

    // Add the application
    await _firestore
        .collection('collaboration_projects')
        .doc(application.collaborationRequestId)
        .collection('applications')
        .add(applicationMap);

    // Create notification for lead artisan
    await _createApplicationNotification(application);
  } catch (e) {
    throw Exception('Failed to apply for role: $e');
  }
}

  // Get applications for a collaboration project
  Stream<List<CollaborationApplication>> getCollaborationApplications(
      String collaborationId) {
    return _firestore
        .collection('collaboration_projects')
        .doc(collaborationId)
        .collection('applications')
        .orderBy('appliedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => CollaborationApplication.fromMap({
                  ...doc.data(),
                  'id': doc.id,
                }))
            .toList());
  }

  // Accept or reject an application
  Future<void> updateApplicationStatus(
      String collaborationId, String applicationId, String status,
      {String? rejectionReason}) async {
    try {
      final updateData = <String, dynamic>{
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (rejectionReason != null) {
        updateData['rejectionReason'] = rejectionReason;
      }

      await _firestore
          .collection('collaboration_projects')
          .doc(collaborationId)
          .collection('applications')
          .doc(applicationId)
          .update(updateData);

      // If accepted, add artisan to collaborators
      if (status == 'accepted') {
        final applicationDoc = await _firestore
            .collection('collaboration_projects')
            .doc(collaborationId)
            .collection('applications')
            .doc(applicationId)
            .get();

        if (applicationDoc.exists) {
          final application = CollaborationApplication.fromMap({
            ...applicationDoc.data()!,
            'id': applicationDoc.id,
          });

          await _addCollaborator(collaborationId, application);
        }
      }

      // Create notification for applicant
      await _createApplicationStatusNotification(
          collaborationId, applicationId, status);
    } catch (e) {
      throw Exception('Failed to update application status: $e');
    }
  }

  // Add collaborator to project
  Future<void> _addCollaborator(
      String collaborationId, CollaborationApplication application) async {
    await _firestore
        .collection('collaboration_projects')
        .doc(collaborationId)
        .update({
      'collaboratorIds': FieldValue.arrayUnion([application.artisanId]),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Update the role to add the artisan
    final projectDoc = await _firestore
        .collection('collaboration_projects')
        .doc(collaborationId)
        .get();

    if (projectDoc.exists) {
      final projectData = projectDoc.data()!;
      final roles =
          List<Map<String, dynamic>>.from(projectData['requiredRoles'] ?? []);

      for (var role in roles) {
        if (role['id'] == application.roleId) {
          final assignedArtisans =
              List<String>.from(role['assignedArtisanIds'] ?? []);
          if (!assignedArtisans.contains(application.artisanId)) {
            assignedArtisans.add(application.artisanId);
            role['assignedArtisanIds'] = assignedArtisans;

            // Update role status if filled
            if (assignedArtisans.length >= (role['maxArtisans'] ?? 1)) {
              role['status'] = 'filled';
            }
          }
          break;
        }
      }

      await _firestore
          .collection('collaboration_projects')
          .doc(collaborationId)
          .update({'requiredRoles': roles});
    }
  }

  // Create notification for new application
  Future<void> _createApplicationNotification(
      CollaborationApplication application) async {
    try {
      // Get lead artisan ID from collaboration project
      final projectDoc = await _firestore
          .collection('collaboration_projects')
          .doc(application.collaborationRequestId)
          .get();

      if (projectDoc.exists) {
        final leadArtisanId = projectDoc.data()!['leadArtisanId'];

        await _firestore.collection('notifications').add({
          'userId': leadArtisanId,
          'title': 'New Collaboration Application',
          'message':
              '${application.artisanName} applied for a role in your project',
          'type': 'collaboration_application',
          'data': {
            'collaborationId': application.collaborationRequestId,
            'applicationId': application.id,
            'artisanId': application.artisanId,
          },
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      print('Error creating application notification: $e');
    }
  }

  // Create notification for application status update
  Future<void> _createApplicationStatusNotification(
      String collaborationId, String applicationId, String status) async {
    try {
      final applicationDoc = await _firestore
          .collection('collaboration_projects')
          .doc(collaborationId)
          .collection('applications')
          .doc(applicationId)
          .get();

      if (applicationDoc.exists) {
        final application = CollaborationApplication.fromMap({
          ...applicationDoc.data()!,
          'id': applicationDoc.id,
        });

        await _firestore.collection('notifications').add({
          'userId': application.artisanId,
          'title': 'Application ${status.toUpperCase()}',
          'message': status == 'accepted'
              ? 'Congratulations! Your application was accepted.'
              : 'Your application was not selected this time.',
          'type': 'collaboration_status',
          'data': {
            'collaborationId': collaborationId,
            'applicationId': applicationId,
            'status': status,
          },
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      print('Error creating status notification: $e');
    }
  }

  // Get collaboration by ID
  Future<CollaborationRequest?> getCollaborationById(String id) async {
    try {
      final doc =
          await _firestore.collection('collaboration_projects').doc(id).get();

      if (doc.exists) {
        return CollaborationRequest.fromMap({
          ...doc.data()!,
          'id': doc.id,
        });
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get collaboration: $e');
    }
  }

  // Update collaboration status
  Future<void> updateCollaborationStatus(String id, String status) async {
    try {
      await _firestore.collection('collaboration_projects').doc(id).update({
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to update collaboration status: $e');
    }
  }

  // Check if current user can create collaboration from craft request
  Future<bool> canCreateCollaboration(String craftRequestId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return false;

      final requestDoc = await _firestore
          .collection('craft_requests')
          .doc(craftRequestId)
          .get();

      if (!requestDoc.exists) return false;

      final requestData = requestDoc.data()!;

      // Check if user has an accepted quotation for this request
      final acceptedQuotation = requestData['acceptedQuotation'];
      if (acceptedQuotation == null) return false;

      return acceptedQuotation['artisanId'] == currentUser.uid;
    } catch (e) {
      return false;
    }
  }

  // Add this new method to notify potential collaborators:
  Future<void> _createCollaborationAnnouncementNotification(
      CollaborationRequest request, String collaborationId) async {
    try {
      // This is optional - you can create notifications for artisans in similar categories
      // or skip this if you don't want to send notifications

      // For now, we'll just log the creation
      print(
          'Collaboration project created: $collaborationId for ${request.title}');

      // You could query for artisans in similar categories and send them notifications
      // But for now, we'll make it discoverable through the collaboration management screen
    } catch (e) {
      print('Error creating collaboration announcement: $e');
    }
  }
}
