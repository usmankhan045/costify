import 'package:cloud_firestore/cloud_firestore.dart';

/// Invitation model for project invitations
class InvitationModel {
  final String id;
  final String projectId;
  final String projectName;
  final String invitedBy; // Admin user ID
  final String invitedByName;
  final String? invitedEmail; // Optional - if inviting specific email
  final String status; // 'pending', 'accepted', 'expired', 'cancelled'
  final DateTime createdAt;
  final DateTime expiresAt;
  final String? acceptedBy; // User ID who accepted
  final DateTime? acceptedAt;

  const InvitationModel({
    required this.id,
    required this.projectId,
    required this.projectName,
    required this.invitedBy,
    required this.invitedByName,
    this.invitedEmail,
    this.status = InvitationStatus.pending,
    required this.createdAt,
    required this.expiresAt,
    this.acceptedBy,
    this.acceptedAt,
  });

  /// Check if invitation is still valid
  bool get isValid =>
      status == InvitationStatus.pending &&
      DateTime.now().isBefore(expiresAt);

  /// Check if invitation is expired
  bool get isExpired =>
      status == InvitationStatus.expired ||
      DateTime.now().isAfter(expiresAt);

  /// Check if invitation is accepted
  bool get isAccepted => status == InvitationStatus.accepted;

  /// Create InvitationModel from Firestore document
  factory InvitationModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return InvitationModel(
      id: doc.id,
      projectId: data['projectId'] ?? '',
      projectName: data['projectName'] ?? '',
      invitedBy: data['invitedBy'] ?? '',
      invitedByName: data['invitedByName'] ?? '',
      invitedEmail: data['invitedEmail'],
      status: data['status'] ?? InvitationStatus.pending,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      expiresAt: (data['expiresAt'] as Timestamp?)?.toDate() ??
          DateTime.now().add(const Duration(days: 7)),
      acceptedBy: data['acceptedBy'],
      acceptedAt: (data['acceptedAt'] as Timestamp?)?.toDate(),
    );
  }

  /// Create InvitationModel from Map
  factory InvitationModel.fromMap(Map<String, dynamic> map, String id) {
    return InvitationModel(
      id: id,
      projectId: map['projectId'] ?? '',
      projectName: map['projectName'] ?? '',
      invitedBy: map['invitedBy'] ?? '',
      invitedByName: map['invitedByName'] ?? '',
      invitedEmail: map['invitedEmail'],
      status: map['status'] ?? InvitationStatus.pending,
      createdAt: map['createdAt'] is Timestamp
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.tryParse(map['createdAt'] ?? '') ?? DateTime.now(),
      expiresAt: map['expiresAt'] is Timestamp
          ? (map['expiresAt'] as Timestamp).toDate()
          : DateTime.tryParse(map['expiresAt'] ?? '') ??
              DateTime.now().add(const Duration(days: 7)),
      acceptedBy: map['acceptedBy'],
      acceptedAt: map['acceptedAt'] is Timestamp
          ? (map['acceptedAt'] as Timestamp).toDate()
          : DateTime.tryParse(map['acceptedAt'] ?? ''),
    );
  }

  /// Convert to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'projectId': projectId,
      'projectName': projectName,
      'invitedBy': invitedBy,
      'invitedByName': invitedByName,
      'invitedEmail': invitedEmail,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
      'expiresAt': Timestamp.fromDate(expiresAt),
      'acceptedBy': acceptedBy,
      'acceptedAt': acceptedAt != null ? Timestamp.fromDate(acceptedAt!) : null,
    };
  }

  /// Generate shareable link
  String get shareableLink {
    return 'https://costify.app/invite/$id';
  }

  /// Create a copy with modified fields
  InvitationModel copyWith({
    String? id,
    String? projectId,
    String? projectName,
    String? invitedBy,
    String? invitedByName,
    String? invitedEmail,
    String? status,
    DateTime? createdAt,
    DateTime? expiresAt,
    String? acceptedBy,
    DateTime? acceptedAt,
  }) {
    return InvitationModel(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      projectName: projectName ?? this.projectName,
      invitedBy: invitedBy ?? this.invitedBy,
      invitedByName: invitedByName ?? this.invitedByName,
      invitedEmail: invitedEmail ?? this.invitedEmail,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
      acceptedBy: acceptedBy ?? this.acceptedBy,
      acceptedAt: acceptedAt ?? this.acceptedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InvitationModel &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// Invitation status constants
class InvitationStatus {
  InvitationStatus._();

  static const String pending = 'pending';
  static const String accepted = 'accepted';
  static const String expired = 'expired';
  static const String cancelled = 'cancelled';
}

