class ToolCall {
  const ToolCall({required this.tool, required this.arguments});

  final String tool;
  final Map<String, dynamic> arguments;

  factory ToolCall.fromJson(Map<String, dynamic> json) {
    return ToolCall(
      tool: json['tool'] as String,
      arguments: Map<String, dynamic>.from(
        (json['arguments'] as Map?) ?? const {},
      ),
    );
  }

  Map<String, dynamic> toJson() => {'tool': tool, 'arguments': arguments};
}

class ToolResult {
  const ToolResult({
    required this.ok,
    this.result,
    this.error,
  });

  final bool ok;
  final Map<String, dynamic>? result;
  final String? error;

  Map<String, dynamic> toJson() => {
    'ok': ok,
    if (result != null) 'result': result,
    if (error != null) 'error': error,
  };

  factory ToolResult.success(Map<String, dynamic> result) =>
      ToolResult(ok: true, result: result);

  factory ToolResult.failure(String error) =>
      ToolResult(ok: false, error: error);
}
