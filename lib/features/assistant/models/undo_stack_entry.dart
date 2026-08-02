import '../../../core/models/transaction.dart';

/// The type of mutation that was performed.
enum UndoOperationType { create, update, delete }

/// An in-memory record of a reversible transaction mutation performed
/// during the current [Chat_Session].
///
/// The [snapshot] holds the transaction state *before* the operation:
/// - For [UndoOperationType.create]: the created transaction (reversal = delete it).
/// - For [UndoOperationType.update]: the transaction before the update (reversal = restore it).
/// - For [UndoOperationType.delete]: the deleted transaction (reversal = re-create it).
///
/// The stack is capped at 10 entries and is never persisted to the database.
class UndoStackEntry {
  const UndoStackEntry({
    required this.operationId,
    required this.type,
    required this.snapshot,
    required this.humanDescription,
  });

  /// Unique identifier for this undo entry (UUID v4).
  final String operationId;

  final UndoOperationType type;

  /// Transaction state before the operation was applied.
  final Transaction snapshot;

  /// Human-readable summary shown to the user on undo confirmation.
  /// Example: "Added ₹500 Grocery expense on 12 Jun"
  final String humanDescription;
}
