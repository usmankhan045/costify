import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../../core/constants/app_constants.dart';
import '../../core/exceptions/app_exceptions.dart';
import '../../core/services/notification_service.dart';
import '../models/project_model.dart';
import '../models/invitation_model.dart';

/// Repository for project operations
class ProjectRepository {
  final FirebaseFirestore _firestore;
  final Uuid _uuid;

  ProjectRepository({
    FirebaseFirestore? firestore,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _uuid = const Uuid();

  /// Projects collection reference
  CollectionReference<Map<String, dynamic>> get _projectsCollection =>
      _firestore.collection(AppConstants.projectsCollection);

  /// Invitations collection reference
  CollectionReference<Map<String, dynamic>> get _invitationsCollection =>
      _firestore.collection(AppConstants.invitationsCollection);

  /// Create a new project
  Future<ProjectModel> createProject({
    required String name,
    String? description,
    required double budget,
    required String adminId,
    required String adminName,
    required DateTime startDate,
    DateTime? endDate,
    String? imageUrl,
  }) async {
    try {
      final docRef = _projectsCollection.doc();
      final now = DateTime.now();

      final project = ProjectModel(
        id: docRef.id,
        name: name,
        description: description,
        budget: budget,
        adminId: adminId,
        adminName: adminName,
        startDate: startDate,
        endDate: endDate,
        createdAt: now,
        updatedAt: now,
        imageUrl: imageUrl,
      );

      await docRef.set(project.toMap());

      // Add project ID to admin's projectIds list
      await _firestore.collection(AppConstants.usersCollection).doc(adminId).update({
        'projectIds': FieldValue.arrayUnion([docRef.id]),
        'updatedAt': Timestamp.now(),
      });

      return project;
    } catch (e) {
      throw DatabaseException.unknown(e);
    }
  }

  /// Get project by ID
  Future<ProjectModel?> getProjectById(String projectId) async {
    try {
      final doc = await _projectsCollection.doc(projectId).get();
      if (!doc.exists) return null;
      return ProjectModel.fromFirestore(doc);
    } catch (e) {
      throw DatabaseException.unknown(e);
    }
  }

  /// Stream of single project by ID (for real-time updates)
  Stream<ProjectModel?> streamProjectById(String projectId) {
    return _projectsCollection.doc(projectId).snapshots().map((doc) {
      if (!doc.exists) return null;
      try {
        return ProjectModel.fromFirestore(doc);
      } catch (e) {
        print('Error parsing project document: $e');
        return null;
      }
    }).handleError((error) {
      print('Error in project stream: $error');
      return null;
    });
  }

  /// Get projects for user (admin or member)
  Future<List<ProjectModel>> getProjectsForUser(String userId) async {
    try {
      // Get user's projectIds from their user document
      final userDoc = await _firestore.collection(AppConstants.usersCollection).doc(userId).get();
      final projectIds = List<String>.from(userDoc.data()?['projectIds'] ?? []);
      
      if (projectIds.isEmpty) {
        // Also check if user is admin of any project (fallback)
        final adminQuery = await _projectsCollection
            .where('adminId', isEqualTo: userId)
            .orderBy('updatedAt', descending: true)
            .get();
        return adminQuery.docs.map((doc) => ProjectModel.fromFirestore(doc)).toList();
      }
      
      // Firestore 'whereIn' has a limit of 30 items, so we need to batch
      final projects = <ProjectModel>[];
      final batches = <List<String>>[];
      
      for (var i = 0; i < projectIds.length; i += 10) {
        batches.add(projectIds.sublist(
          i,
          i + 10 > projectIds.length ? projectIds.length : i + 10,
        ));
      }
      
      for (final batch in batches) {
        final query = await _projectsCollection
            .where(FieldPath.documentId, whereIn: batch)
            .get();
        projects.addAll(query.docs.map((doc) => ProjectModel.fromFirestore(doc)));
      }
      
      // Also get projects where user is admin but might not be in projectIds
      final adminQuery = await _projectsCollection
          .where('adminId', isEqualTo: userId)
          .get();
      
      for (final doc in adminQuery.docs) {
        if (!projects.any((p) => p.id == doc.id)) {
          projects.add(ProjectModel.fromFirestore(doc));
        }
      }

      projects.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return projects;
    } catch (e) {
      throw DatabaseException.unknown(e);
    }
  }

  /// Stream of projects for user (admin, director, or member)
  Stream<List<ProjectModel>> streamProjectsForUser(String userId) {
    // Watch user document for projectIds changes, then fetch projects
    return _firestore
        .collection(AppConstants.usersCollection)
        .doc(userId)
        .snapshots()
        .asyncMap((userDoc) async {
          // Get projectIds from user document
          final projectIds = List<String>.from(userDoc.data()?['projectIds'] ?? []);
          
          // Get all projects (admin + member projects)
          final allProjects = <ProjectModel>[];
          
          // Get admin projects
          final adminQuery = await _projectsCollection
              .where('adminId', isEqualTo: userId)
              .get();
          allProjects.addAll(adminQuery.docs.map((doc) => ProjectModel.fromFirestore(doc)));
          
          // Get member projects (where user is in projectIds)
          if (projectIds.isNotEmpty) {
            // Firestore 'whereIn' has a limit of 30 items, so we need to batch
            final batches = <List<String>>[];
            for (var i = 0; i < projectIds.length; i += 10) {
              batches.add(projectIds.sublist(
                i,
                i + 10 > projectIds.length ? projectIds.length : i + 10,
              ));
            }
            
            for (final batch in batches) {
              final query = await _projectsCollection
                  .where(FieldPath.documentId, whereIn: batch)
                  .get();
              allProjects.addAll(query.docs.map((doc) => ProjectModel.fromFirestore(doc)));
            }
          }
          
          // Deduplicate by project ID
          final uniqueProjects = <String, ProjectModel>{};
          for (final project in allProjects) {
            uniqueProjects[project.id] = project;
          }
          
          final result = uniqueProjects.values.toList();
          result.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
          return result;
        });
  }

  /// Update project
  Future<ProjectModel> updateProject({
    required String projectId,
    String? name,
    String? description,
    double? budget,
    String? status,
    DateTime? startDate,
    DateTime? endDate,
    String? imageUrl,
  }) async {
    try {
      final updates = <String, dynamic>{
        'updatedAt': Timestamp.now(),
      };

      if (name != null) updates['name'] = name;
      if (description != null) updates['description'] = description;
      if (budget != null) updates['budget'] = budget;
      if (status != null) updates['status'] = status;
      if (startDate != null) updates['startDate'] = Timestamp.fromDate(startDate);
      if (endDate != null) updates['endDate'] = Timestamp.fromDate(endDate);
      if (imageUrl != null) updates['imageUrl'] = imageUrl;

      await _projectsCollection.doc(projectId).update(updates);

      final updatedProject = await getProjectById(projectId);
      if (updatedProject == null) {
        throw DatabaseException.notFound();
      }

      return updatedProject;
    } catch (e) {
      if (e is DatabaseException) rethrow;
      throw DatabaseException.unknown(e);
    }
  }

  /// Update project total spent
  Future<void> updateProjectTotalSpent(String projectId, double amount) async {
    try {
      await _projectsCollection.doc(projectId).update({
        'totalSpent': FieldValue.increment(amount),
        'updatedAt': Timestamp.now(),
      });
    } catch (e) {
      throw DatabaseException.unknown(e);
    }
  }

  /// Delete project
  Future<void> deleteProject(String projectId) async {
    try {
      final project = await getProjectById(projectId);
      if (project == null) {
        throw DatabaseException.notFound();
      }

      // Remove project ID from admin's list
      await _firestore.collection(AppConstants.usersCollection).doc(project.adminId).update({
        'projectIds': FieldValue.arrayRemove([projectId]),
        'updatedAt': Timestamp.now(),
      });

      // Remove project ID from all members' lists
      for (final member in project.members) {
        await _firestore.collection(AppConstants.usersCollection).doc(member.userId).update({
          'projectIds': FieldValue.arrayRemove([projectId]),
          'updatedAt': Timestamp.now(),
        });
      }

      // Delete all expenses for this project
      final expenses = await _firestore
          .collection(AppConstants.expensesCollection)
          .where('projectId', isEqualTo: projectId)
          .get();

      final batch = _firestore.batch();
      for (final expense in expenses.docs) {
        batch.delete(expense.reference);
      }

      // Delete all invitations for this project
      final invitations = await _invitationsCollection
          .where('projectId', isEqualTo: projectId)
          .get();

      for (final invitation in invitations.docs) {
        batch.delete(invitation.reference);
      }

      // Delete the project
      batch.delete(_projectsCollection.doc(projectId));

      await batch.commit();
    } catch (e) {
      if (e is DatabaseException) rethrow;
      throw DatabaseException.unknown(e);
    }
  }

  /// Create project invitation
  Future<InvitationModel> createInvitation({
    required String projectId,
    required String projectName,
    required String invitedBy,
    required String invitedByName,
    String? invitedEmail,
    String memberRole = ProjectMemberRoles.labour,
    int expiryDays = 7,
  }) async {
    try {
      print('🔵 [Invitation] Creating invitation for project: $projectId');
      print('🔵 [Invitation] Role: $memberRole');
      
      final docRef = _invitationsCollection.doc();
      final now = DateTime.now();

      final invitation = InvitationModel(
        id: docRef.id,
        projectId: projectId,
        projectName: projectName,
        invitedBy: invitedBy,
        invitedByName: invitedByName,
        invitedEmail: invitedEmail,
        memberRole: memberRole,
        createdAt: now,
        expiresAt: now.add(Duration(days: expiryDays)),
      );

      print('🔵 [Invitation] Invitation ID: ${invitation.id}');
      print('🔵 [Invitation] Writing to Firestore...');
      
      await docRef.set(invitation.toMap());
      
      print('✅ [Invitation] Invitation created successfully');
      print('🔵 [Invitation] Shareable link: ${invitation.shareableLink}');
      
      return invitation;
    } on FirebaseException catch (e) {
      print('❌ [Invitation] Firebase error: ${e.code} - ${e.message}');
      throw DatabaseException(
        message: 'Failed to create invitation: ${e.message}',
        code: e.code,
        originalError: e,
      );
    } catch (e, stackTrace) {
      print('❌ [Invitation] Error creating invitation: $e');
      print('❌ [Invitation] Stack trace: $stackTrace');
      throw DatabaseException.unknown(e);
    }
  }

  /// Get invitation by ID
  Future<InvitationModel?> getInvitationById(String invitationId) async {
    try {
      final doc = await _invitationsCollection.doc(invitationId).get();
      if (!doc.exists) return null;
      return InvitationModel.fromFirestore(doc);
    } catch (e) {
      throw DatabaseException.unknown(e);
    }
  }

  /// Accept invitation
  Future<void> acceptInvitation({
    required String invitationId,
    required String userId,
    required String userName,
    required String userEmail,
    String? userPhotoUrl,
  }) async {
    try {
      final invitation = await getInvitationById(invitationId);
      if (invitation == null) {
        throw DatabaseException.notFound();
      }

      if (!invitation.isValid) {
        throw DatabaseException(
          message: 'This invitation has expired',
          code: 'invitation-expired',
        );
      }
      
      // Check if user is already a member
      final project = await getProjectById(invitation.projectId);
      if (project != null) {
        if (project.adminId == userId) {
          throw DatabaseException(
            message: 'You are already the admin of this project',
            code: 'already-admin',
          );
        }
        if (project.members.any((m) => m.userId == userId)) {
          throw DatabaseException(
            message: 'You are already a member of this project',
            code: 'already-member',
          );
        }
      }

      final now = DateTime.now();
      final memberId = _uuid.v4();

      // Add user as project member with the role from the invitation
      final member = ProjectMember(
        id: memberId,
        userId: userId,
        name: userName,
        email: userEmail,
        photoUrl: userPhotoUrl,
        role: invitation.memberRole, // Use role from invitation
        joinedAt: now,
      );

      await _projectsCollection.doc(invitation.projectId).update({
        'members': FieldValue.arrayUnion([member.toMap()]),
        'updatedAt': Timestamp.now(),
      });

      // Add project ID to user's list
      await _firestore.collection(AppConstants.usersCollection).doc(userId).update({
        'projectIds': FieldValue.arrayUnion([invitation.projectId]),
        'updatedAt': Timestamp.now(),
      });

      // Update invitation status
      await _invitationsCollection.doc(invitationId).update({
        'status': InvitationStatus.accepted,
        'acceptedBy': userId,
        'acceptedAt': Timestamp.now(),
      });
    } catch (e) {
      if (e is DatabaseException) rethrow;
      throw DatabaseException.unknown(e);
    }
  }

  /// Cancel invitation
  Future<void> cancelInvitation(String invitationId) async {
    try {
      await _invitationsCollection.doc(invitationId).update({
        'status': InvitationStatus.cancelled,
      });
    } catch (e) {
      throw DatabaseException.unknown(e);
    }
  }

  /// Remove member from project
  Future<void> removeMember({
    required String projectId,
    required String memberId,
    required String userId,
    required String removedBy,
    required String removedByName,
    bool isDirector = false,
  }) async {
    try {
      final project = await getProjectById(projectId);
      if (project == null) {
        throw DatabaseException.notFound();
      }

      final memberToRemove = project.members.firstWhere(
        (m) => m.id == memberId,
        orElse: () => throw DatabaseException.notFound(),
      );

      await _projectsCollection.doc(projectId).update({
        'members': FieldValue.arrayRemove([memberToRemove.toMap()]),
        'updatedAt': Timestamp.now(),
      });

      // Remove project ID from user's list
      await _firestore.collection(AppConstants.usersCollection).doc(userId).update({
        'projectIds': FieldValue.arrayRemove([projectId]),
        'updatedAt': Timestamp.now(),
      });

      // If director removed member, notify admin
      if (isDirector) {
        await NotificationService.instance.notifyMemberRemovedByDirector(
          adminId: project.adminId,
          projectName: project.name,
          memberName: memberToRemove.name,
          removedByName: removedByName,
          projectId: projectId,
          memberId: memberId,
        );
      }
    } catch (e) {
      if (e is DatabaseException) rethrow;
      throw DatabaseException.unknown(e);
    }
  }

  /// Get pending invitations for project
  Future<List<InvitationModel>> getPendingInvitations(String projectId) async {
    try {
      final query = await _invitationsCollection
          .where('projectId', isEqualTo: projectId)
          .where('status', isEqualTo: InvitationStatus.pending)
          .orderBy('createdAt', descending: true)
          .get();

      return query.docs
          .map((doc) => InvitationModel.fromFirestore(doc))
          .where((invitation) => invitation.isValid)
          .toList();
    } catch (e) {
      throw DatabaseException.unknown(e);
    }
  }

  /// Update director permissions
  Future<void> updateDirectorPermissions({
    required String projectId,
    required String directorUserId,
    required DirectorPermissions permissions,
  }) async {
    try {
      final project = await getProjectById(projectId);
      if (project == null) {
        throw DatabaseException.notFound();
      }

      // Get current permissions map
      final updatedPermissions = Map<String, DirectorPermissions>.from(
        project.directorPermissions,
      );
      updatedPermissions[directorUserId] = permissions;

      // Convert to map for Firestore
      final permissionsMap = updatedPermissions.map(
        (key, value) => MapEntry(key, value.toMap()),
      );

      await _projectsCollection.doc(projectId).update({
        'directorPermissions': permissionsMap,
        'updatedAt': Timestamp.now(),
      });
    } catch (e) {
      if (e is DatabaseException) rethrow;
      throw DatabaseException.unknown(e);
    }
  }
}

