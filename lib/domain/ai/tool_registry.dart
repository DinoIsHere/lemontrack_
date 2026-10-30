/// JSON tool schemas per resources/05_ai_tools_contract.md, passed to LLM providers.
class ToolRegistry {
  static const _catEnum = ['deep_work', 'meetings', 'study', 'health', 'admin', 'personal'];

  static final List<Map<String, dynamic>> tools = [
    {
      'name': 'get_day',
      'description': 'List all time blocks on a given local date, sorted by start time. Use before editing to learn existing block ids.',
      'parameters': {
        'type': 'object',
        'properties': {
          'date': {'type': 'string', 'description': 'Local date YYYY-MM-DD'},
        },
        'required': ['date'],
      },
    },
    {
      'name': 'get_range',
      'description': 'List time blocks that overlap a local datetime range.',
      'parameters': {
        'type': 'object',
        'properties': {
          'start': {'type': 'string', 'description': 'ISO 8601 local datetime with offset'},
          'end': {'type': 'string', 'description': 'ISO 8601 local datetime with offset'},
        },
        'required': ['start', 'end'],
      },
    },
    {
      'name': 'find_free_slot',
      'description': 'Find the earliest free window of at least the given length inside the day. Respects workday hours (09:00-18:00) unless ignore_workday is true.',
      'parameters': {
        'type': 'object',
        'properties': {
          'date': {'type': 'string', 'description': 'Local date YYYY-MM-DD'},
          'duration_minutes': {'type': 'integer', 'minimum': 5, 'maximum': 720},
          'earliest': {'type': 'string', 'description': 'HH:MM local, optional'},
          'ignore_workday': {'type': 'boolean'},
        },
        'required': ['date', 'duration_minutes'],
      },
    },
    {
      'name': 'create_block',
      'description': 'Create a new time block. If the time conflicts with another block it is still created and the result lists conflicts. Prefer find_free_slot first when the user gave no time.',
      'parameters': {
        'type': 'object',
        'properties': {
          'title': {'type': 'string', 'minLength': 1, 'maxLength': 120},
          'start': {'type': 'string', 'description': 'ISO 8601 local datetime with offset'},
          'duration_minutes': {'type': 'integer', 'minimum': 5, 'maximum': 720},
          'category': {'type': 'string', 'enum': _catEnum},
          'priority': {'type': 'integer', 'minimum': 0, 'maximum': 2},
          'notes': {'type': 'string', 'maxLength': 2000},
        },
        'required': ['title', 'start', 'duration_minutes', 'category'],
      },
    },
    {
      'name': 'update_block',
      'description': 'Change fields of an existing block. Only send fields that change.',
      'parameters': {
        'type': 'object',
        'properties': {
          'block_id': {'type': 'string'},
          'title': {'type': 'string', 'minLength': 1, 'maxLength': 120},
          'start': {'type': 'string', 'description': 'ISO 8601 local datetime with offset'},
          'duration_minutes': {'type': 'integer', 'minimum': 5, 'maximum': 720},
          'category': {'type': 'string', 'enum': _catEnum},
          'priority': {'type': 'integer', 'minimum': 0, 'maximum': 2},
          'notes': {'type': 'string', 'maxLength': 2000},
        },
        'required': ['block_id'],
      },
    },
    {
      'name': 'move_block',
      'description': 'Move a block to a new start time, keeping its duration.',
      'parameters': {
        'type': 'object',
        'properties': {
          'block_id': {'type': 'string'},
          'new_start': {'type': 'string', 'description': 'ISO 8601 local datetime with offset'},
        },
        'required': ['block_id', 'new_start'],
      },
    },
    {
      'name': 'shift_following',
      'description': 'Shift every block that starts at or after a given time by delta minutes (negative = earlier). Use when a meeting ran long. Returns the moved blocks.',
      'parameters': {
        'type': 'object',
        'properties': {
          'from': {'type': 'string', 'description': 'ISO 8601 local datetime with offset'},
          'delta_minutes': {'type': 'integer', 'minimum': -720, 'maximum': 720},
          'exclude_category': {'type': 'string', 'enum': _catEnum},
        },
        'required': ['from', 'delta_minutes'],
      },
    },
    {
      'name': 'complete_block',
      'description': 'Mark a block as done. Optionally record tracked time in minutes.',
      'parameters': {
        'type': 'object',
        'properties': {
          'block_id': {'type': 'string'},
          'tracked_minutes': {'type': 'integer', 'minimum': 0, 'maximum': 720},
        },
        'required': ['block_id'],
      },
    },
    {
      'name': 'delete_block',
      'description': 'Soft-delete a block. The user can undo it. Confirm with the user before deleting more than one block.',
      'parameters': {
        'type': 'object',
        'properties': {
          'block_id': {'type': 'string'},
        },
        'required': ['block_id'],
      },
    },
    {
      'name': 'summarize_day',
      'description': 'Totals for a local date: planned minutes, tracked minutes, per-category minutes, done count, conflicting pairs.',
      'parameters': {
        'type': 'object',
        'properties': {
          'date': {'type': 'string', 'description': 'Local date YYYY-MM-DD'},
        },
        'required': ['date'],
      },
    },
  ];
}
