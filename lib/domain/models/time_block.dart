enum BlockStatus { planned, inProgress, done, skipped }
enum BlockSource { user, ai, seed }
enum ActionActor { user, ai }
enum ChatRole { user, assistant, tool, system }
enum AiProvider { ruleBased, openai, gemini }

class TimeBlock {
  final String id;
  final String title;
  final String? notes;
  final DateTime startUtc;
  final DateTime endUtc;
  final String timezone;
  final String categoryId;
  final BlockStatus status;
  final int trackedSeconds;
  final int priority;
  final BlockSource source;
  final DateTime createdAtUtc;
  final DateTime updatedAtUtc;
  final DateTime? deletedAtUtc;
  final String? recurrenceRule;

  const TimeBlock({
    required this.id,
    required this.title,
    this.notes,
    required this.startUtc,
    required this.endUtc,
    required this.timezone,
    required this.categoryId,
    required this.status,
    required this.trackedSeconds,
    required this.priority,
    required this.source,
    required this.createdAtUtc,
    required this.updatedAtUtc,
    this.deletedAtUtc,
    this.recurrenceRule,
  });

  Duration get duration => endUtc.difference(startUtc);
  int get plannedSeconds => duration.inSeconds;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'notes': notes,
        'startUtc': startUtc.toIso8601String(),
        'endUtc': endUtc.toIso8601String(),
        'timezone': timezone,
        'categoryId': categoryId,
        'status': status.name,
        'trackedSeconds': trackedSeconds,
        'priority': priority,
        'source': source.name,
        'createdAtUtc': createdAtUtc.toIso8601String(),
        'updatedAtUtc': updatedAtUtc.toIso8601String(),
        'deletedAtUtc': deletedAtUtc?.toIso8601String(),
        'recurrenceRule': recurrenceRule,
      };

  factory TimeBlock.fromJson(Map<String, dynamic> j) => TimeBlock(
        id: j['id'] as String,
        title: j['title'] as String,
        notes: j['notes'] as String?,
        startUtc: DateTime.parse(j['startUtc'] as String).toUtc(),
        endUtc: DateTime.parse(j['endUtc'] as String).toUtc(),
        timezone: j['timezone'] as String? ?? '',
        categoryId: j['categoryId'] as String,
        status: BlockStatus.values.firstWhere((e) => e.name == j['status'], orElse: () => BlockStatus.planned),
        trackedSeconds: (j['trackedSeconds'] as num?)?.toInt() ?? 0,
        priority: (j['priority'] as num?)?.toInt() ?? 1,
        source: BlockSource.values.firstWhere((e) => e.name == j['source'], orElse: () => BlockSource.user),
        createdAtUtc: DateTime.parse(j['createdAtUtc'] as String).toUtc(),
        updatedAtUtc: DateTime.parse(j['updatedAtUtc'] as String).toUtc(),
        deletedAtUtc: j['deletedAtUtc'] == null ? null : DateTime.parse(j['deletedAtUtc'] as String).toUtc(),
        recurrenceRule: j['recurrenceRule'] as String?,
      );

  TimeBlock copyWith({
    String? title,
    String? notes,
    DateTime? startUtc,
    DateTime? endUtc,
    String? categoryId,
    BlockStatus? status,
    int? trackedSeconds,
    int? priority,
    DateTime? updatedAtUtc,
    DateTime? deletedAtUtc,
  }) {
    return TimeBlock(
      id: id,
      title: title ?? this.title,
      notes: notes ?? this.notes,
      startUtc: startUtc ?? this.startUtc,
      endUtc: endUtc ?? this.endUtc,
      timezone: timezone,
      categoryId: categoryId ?? this.categoryId,
      status: status ?? this.status,
      trackedSeconds: trackedSeconds ?? this.trackedSeconds,
      priority: priority ?? this.priority,
      source: source,
      createdAtUtc: createdAtUtc,
      updatedAtUtc: updatedAtUtc ?? DateTime.now().toUtc(),
      deletedAtUtc: deletedAtUtc ?? this.deletedAtUtc,
      recurrenceRule: recurrenceRule,
    );
  }
}

class Category {
  final String id;
  final String name;
  final int colorHex;
  final String iconName;
  final int sortOrder;

  const Category({
    required this.id,
    required this.name,
    required this.colorHex,
    required this.iconName,
    required this.sortOrder,
  });
}

class ActionLogEntry {
  final String id;
  final DateTime atUtc;
  final ActionActor actor;
  final String kind;
  final String? blockId;
  final String? before;
  final String? after;
  final bool undone;
  final String? conversationId;

  const ActionLogEntry({
    required this.id,
    required this.atUtc,
    required this.actor,
    required this.kind,
    this.blockId,
    this.before,
    this.after,
    this.undone = false,
    this.conversationId,
  });
}

class ChatMessage {
  final String id;
  final String conversationId;
  final ChatRole role;
  final String content;
  final String? toolCallsJson;
  final String? toolCallId;
  final DateTime createdAtUtc;

  const ChatMessage({
    required this.id,
    required this.conversationId,
    required this.role,
    required this.content,
    this.toolCallsJson,
    this.toolCallId,
    required this.createdAtUtc,
  });
}

class Settings {
  final int workdayStartHour;
  final int workdayStartMin;
  final int workdayEndHour;
  final int workdayEndMin;
  final int defaultBlockMinutes;
  final int snapMinutes;
  final int reminderLeadMinutes;
  final AiProvider aiProvider;
  final String aiModelName;
  final bool hasSeenOnboarding;

  const Settings({
    this.workdayStartHour = 9,
    this.workdayStartMin = 0,
    this.workdayEndHour = 18,
    this.workdayEndMin = 0,
    this.defaultBlockMinutes = 30,
    this.snapMinutes = 5,
    this.reminderLeadMinutes = 10,
    this.aiProvider = AiProvider.ruleBased,
    this.aiModelName = 'rule-based',
    this.hasSeenOnboarding = false,
  });
}
