import 'package:cloud_firestore/cloud_firestore.dart';

class AuditLogEntry {
  final String id;
  final String action;
  final String performedBy;
  final String? targetId;
  final String? targetType;
  final String? details;
  final Timestamp timestamp;

  AuditLogEntry({
    required this.id,
    required this.action,
    required this.performedBy,
    this.targetId,
    this.targetType,
    this.details,
    required this.timestamp,
  });

  factory AuditLogEntry.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AuditLogEntry(
      id: doc.id,
      action: data['action'] ?? '',
      performedBy: data['performedBy'] ?? '',
      targetId: data['targetId'],
      targetType: data['targetType'],
      details: data['details'],
      timestamp: data['timestamp'] ?? Timestamp.now(),
    );
  }
}
