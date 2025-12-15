import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants/app_constants.dart';

/// Project model representing construction projects
class ProjectModel {
  final String id;
  final String name;
  final String? description;
  final double budget;
  final double totalSpent;
  final String status; // 'active', 'completed', 'on_hold', 'cancelled'
  final String adminId; // User ID of the project admin
  final String adminName;
  final List<ProjectMember> members;
  final DateTime startDate;
  final DateTime? endDate;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? imageUrl;

  const ProjectModel({
    required this.id,
    required this.name,
    this.description,
    required this.budget,
    this.totalSpent = 0,
    this.status = ProjectStatus.active,
    required this.adminId,
    required this.adminName,
    this.members = const [],
    required this.startDate,
    this.endDate,
    required this.createdAt,
    required this.updatedAt,
    this.imageUrl,
  });

  /// Get remaining budget
  double get remainingBudget => budget - totalSpent;

  /// Get budget utilization percentage
  double get budgetUtilization => budget > 0 ? (totalSpent / budget) * 100 : 0;

  /// Check if project is over budget
  bool get isOverBudget => totalSpent > budget;

  /// Check if project is active
  bool get isActive => status == ProjectStatus.active;

  /// Get total member count (including admin)
  int get memberCount => members.length + 1;

  /// Create ProjectModel from Firestore document
  factory ProjectModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ProjectModel(
      id: doc.id,
      name: data['name'] ?? '',
      description: data['description'],
      budget: (data['budget'] ?? 0).toDouble(),
      totalSpent: (data['totalSpent'] ?? 0).toDouble(),
      status: data['status'] ?? ProjectStatus.active,
      adminId: data['adminId'] ?? '',
      adminName: data['adminName'] ?? '',
      members: (data['members'] as List<dynamic>?)
              ?.map((m) => ProjectMember.fromMap(m as Map<String, dynamic>))
              .toList() ??
          [],
      startDate: (data['startDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      endDate: (data['endDate'] as Timestamp?)?.toDate(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      imageUrl: data['imageUrl'],
    );
  }

  /// Create ProjectModel from Map
  factory ProjectModel.fromMap(Map<String, dynamic> map, String id) {
    return ProjectModel(
      id: id,
      name: map['name'] ?? '',
      description: map['description'],
      budget: (map['budget'] ?? 0).toDouble(),
      totalSpent: (map['totalSpent'] ?? 0).toDouble(),
      status: map['status'] ?? ProjectStatus.active,
      adminId: map['adminId'] ?? '',
      adminName: map['adminName'] ?? '',
      members: (map['members'] as List<dynamic>?)
              ?.map((m) => ProjectMember.fromMap(m as Map<String, dynamic>))
              .toList() ??
          [],
      startDate: map['startDate'] is Timestamp
          ? (map['startDate'] as Timestamp).toDate()
          : DateTime.tryParse(map['startDate'] ?? '') ?? DateTime.now(),
      endDate: map['endDate'] is Timestamp
          ? (map['endDate'] as Timestamp).toDate()
          : DateTime.tryParse(map['endDate'] ?? ''),
      createdAt: map['createdAt'] is Timestamp
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.tryParse(map['createdAt'] ?? '') ?? DateTime.now(),
      updatedAt: map['updatedAt'] is Timestamp
          ? (map['updatedAt'] as Timestamp).toDate()
          : DateTime.tryParse(map['updatedAt'] ?? '') ?? DateTime.now(),
      imageUrl: map['imageUrl'],
    );
  }

  /// Convert to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'budget': budget,
      'totalSpent': totalSpent,
      'status': status,
      'adminId': adminId,
      'adminName': adminName,
      'members': members.map((m) => m.toMap()).toList(),
      'startDate': Timestamp.fromDate(startDate),
      'endDate': endDate != null ? Timestamp.fromDate(endDate!) : null,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'imageUrl': imageUrl,
    };
  }

  /// Create a copy with modified fields
  ProjectModel copyWith({
    String? id,
    String? name,
    String? description,
    double? budget,
    double? totalSpent,
    String? status,
    String? adminId,
    String? adminName,
    List<ProjectMember>? members,
    DateTime? startDate,
    DateTime? endDate,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? imageUrl,
  }) {
    return ProjectModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      budget: budget ?? this.budget,
      totalSpent: totalSpent ?? this.totalSpent,
      status: status ?? this.status,
      adminId: adminId ?? this.adminId,
      adminName: adminName ?? this.adminName,
      members: members ?? this.members,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      imageUrl: imageUrl ?? this.imageUrl,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProjectModel &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'ProjectModel(id: $id, name: $name, budget: $budget, totalSpent: $totalSpent)';
  }
}

/// Project member model
class ProjectMember {
  final String id;
  final String userId;
  final String name;
  final String email;
  final String? photoUrl;
  final String role;
  final DateTime joinedAt;

  const ProjectMember({
    required this.id,
    required this.userId,
    required this.name,
    required this.email,
    this.photoUrl,
    this.role = UserRoles.stakeholder,
    required this.joinedAt,
  });

  factory ProjectMember.fromMap(Map<String, dynamic> map) {
    return ProjectMember(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      photoUrl: map['photoUrl'],
      role: map['role'] ?? UserRoles.stakeholder,
      joinedAt: map['joinedAt'] is Timestamp
          ? (map['joinedAt'] as Timestamp).toDate()
          : DateTime.tryParse(map['joinedAt'] ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'name': name,
      'email': email,
      'photoUrl': photoUrl,
      'role': role,
      'joinedAt': Timestamp.fromDate(joinedAt),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProjectMember &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

