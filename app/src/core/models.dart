import 'package:flutter/material.dart';

import '../../samanvay_design.dart';
import 'geo.dart';

enum AppRole { citizen, department, coordinator, admin }

AppRole roleFromDb(String? value) => switch ((value ?? '').toLowerCase()) {
      'department' => AppRole.department,
      'coordinator' => AppRole.coordinator,
      'admin' => AppRole.admin,
      _ => AppRole.citizen,
    };

extension AppRoleText on AppRole {
  String get label => switch (this) {
        AppRole.citizen => 'Citizen',
        AppRole.department => 'Department officer',
        AppRole.coordinator => 'Coordinator',
        AppRole.admin => 'Administrator',
      };
  IconData get icon => switch (this) {
        AppRole.citizen => Icons.person_outline,
        AppRole.department => Icons.engineering_outlined,
        AppRole.coordinator => Icons.hub_outlined,
        AppRole.admin => Icons.admin_panel_settings_outlined,
      };
  bool get isStaff => this != AppRole.citizen;
}

class AppUser {
  const AppUser({
    required this.id,
    required this.name,
    required this.role,
    this.email,
    this.departmentId,
    this.departmentName,
  });
  final String id;
  final String name;
  final String? email;
  final AppRole role;
  final String? departmentId;
  final String? departmentName;
}

class Department {
  const Department(this.id, this.name);
  final String id;
  final String name;
}

/// Request lifecycle as stored in excavation_requests.status.
class CaseStatus {
  CaseStatus._();
  static const lifecycle = ['submitted', 'under_review', 'approved', 'in_progress', 'completed'];

  static String label(String s) => switch (s) {
        'draft' => 'Draft',
        'submitted' => 'Submitted',
        'under_review' => 'Under department review',
        'clarification_required' => 'Clarification required',
        'conflict_detected' => 'Conflict detected',
        'coordination_pending' => 'Coordination pending',
        'approved' => 'Approved',
        'scheduled' => 'Scheduled',
        'in_progress' => 'In progress',
        'restoration_pending' => 'Restoration pending',
        'completed' => 'Completed',
        'rejected' => 'Rejected',
        'cancelled' => 'Cancelled',
        _ => s.replaceAll('_', ' '),
      };

  static Color color(String s) => switch (s) {
        'draft' || 'submitted' => SvColors.stone,
        'under_review' || 'coordination_pending' => SvColors.gold,
        'clarification_required' => SvColors.clay,
        'conflict_detected' || 'rejected' || 'cancelled' => SvColors.error,
        'approved' || 'scheduled' => SvColors.olive,
        'in_progress' => const Color(0xFF3F6E8C),
        'restoration_pending' => SvColors.ochre,
        'completed' => SvColors.forest,
        _ => SvColors.ash,
      };

  static bool isOpen(String s) => !['completed', 'rejected', 'cancelled'].contains(s);
}

const caseCategories = <(String, String, IconData)>[
  ('road_reconstruction', 'Road reconstruction', Icons.add_road),
  ('water_supply', 'Water supply', Icons.water_drop_outlined),
  ('sewerage', 'Sewerage', Icons.water_outlined),
  ('stormwater_drainage', 'Stormwater drainage', Icons.waves_outlined),
  ('electricity', 'Electricity', Icons.bolt_outlined),
  ('telecom', 'Telecom & fibre', Icons.cell_tower_outlined),
  ('gas', 'Gas', Icons.local_fire_department_outlined),
  ('other', 'Something else', Icons.more_horiz),
];

const workActivities = <(String, String)>[
  ('new_installation', 'New installation'),
  ('repair', 'Repair'),
  ('maintenance', 'Maintenance'),
  ('relocation', 'Relocation'),
  ('inspection', 'Inspection'),
  ('emergency_response', 'Emergency response'),
  ('other', 'Other'),
];

String categoryLabel(String? c) =>
    caseCategories.where((x) => x.$1 == c).map((x) => x.$2).firstOrNull ?? (c ?? 'Other').replaceAll('_', ' ');

IconData categoryIcon(String? c) => caseCategories.where((x) => x.$1 == c).map((x) => x.$3).firstOrNull ?? Icons.construction;

class CaseSummary {
  CaseSummary({
    required this.id,
    required this.number,
    required this.title,
    required this.status,
    this.category,
    this.activity,
    this.road,
    this.city,
    this.location,
    this.radiusM,
    this.start,
    this.end,
    this.requesterId,
    this.description,
    this.isDemo = false,
  });
  final String id;
  final String number;
  final String title;
  final String status;
  final String? category;
  final String? activity;
  final String? road;
  final String? city;
  final GeoPoint? location;
  final double? radiusM;
  final DateTime? start;
  final DateTime? end;
  final String? requesterId;
  final String? description;
  final bool isDemo;

  String get place => [road, city].where((s) => s != null && s.trim().isNotEmpty).join(', ');
}

class DeptReview {
  DeptReview({required this.id, required this.departmentId, required this.departmentName, required this.status, this.remarks});
  final String id;
  final String departmentId;
  final String departmentName;
  final String status;
  final String? remarks;

  bool get isFinal => status == 'approved' || status == 'rejected';
  bool get isCleared => status == 'approved';

  String get statusLabel => reviewStatusLabel(status);
}

String reviewStatusLabel(String s) => switch (s) {
      'pending' => 'Not started',
      'under_review' || 'in_review' => 'In review',
      'approved' => 'Cleared',
      'rejected' => 'Refused',
      'conflict_detected' => 'Conflict found',
      'changes_requested' || 'needs_changes' => 'Changes asked',
      _ => s.replaceAll('_', ' '),
    };

class SpatialResult {
  SpatialResult({required this.status, required this.possibleOverlap, required this.advisory, this.checkedAt, this.overlapCount = 0, this.nearbyCount = 0});
  final String status; // completed | unavailable | missing_work_location | missing_work_radius
  final bool possibleOverlap;
  final String advisory;
  final DateTime? checkedAt;
  final int overlapCount;
  final int nearbyCount;
}

class DigOnceMatch {
  DigOnceMatch({required this.number, this.title, this.category, this.start, this.end, required this.distanceM, required this.gapDays});
  final String number;
  final String? title;
  final String? category;
  final DateTime? start;
  final DateTime? end;
  final double distanceM;
  final int gapDays;
}

class DigOnceResult {
  DigOnceResult({required this.status, required this.matches, this.windowDays = 90, this.distanceM = 60});
  final String status; // completed | missing_work_location | missing_work_dates
  final List<DigOnceMatch> matches;
  final int windowDays;
  final double distanceM;
}

class NoticeItem {
  NoticeItem({required this.title, this.area, this.department, this.start, this.end, this.status, this.progress});
  final String title;
  final String? area;
  final String? department;
  final DateTime? start;
  final DateTime? end;
  final String? status;
  final int? progress;
}

const reportTypes = <(String, String)>[
  ('road_obstruction', 'Road blocked or obstructed'),
  ('unsafe_excavation', 'Unsafe or open trench'),
  ('unmarked_work', 'Work without signs or barricades'),
  ('possible_damage', 'Possible damage to a pipe or cable'),
  ('blocked_access', 'Blocked access to a home or shop'),
  ('other', 'Something else'),
];

class CitizenReport {
  CitizenReport({required this.id, required this.type, required this.area, required this.details, required this.status, required this.createdAt, this.city, this.reference});
  final String id;
  final String type;
  final String area;
  final String? city;
  final String details;
  final String status;
  final DateTime createdAt;
  final String? reference;
}

class InboxItem {
  InboxItem({required this.id, required this.title, required this.body, required this.createdAt, this.read = false, this.caseId, this.kind = 'system'});
  final String id;
  final String title;
  final String body;
  final DateTime createdAt;
  final bool read;
  final String? caseId;
  final String kind;
}

class NewCaseDraft {
  String category = 'road_reconstruction';
  String activity = 'repair';
  String title = '';
  String description = '';
  String road = '';
  String city = '';
  GeoPoint? location;
  double? locationAccuracyM;
  String locationSource = 'not set'; // gps | map | manual | place
  double radiusM = 10;
  DateTime? start;
  DateTime? end;
}
