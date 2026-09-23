import Testing

/// Polls `condition` on the main actor until it holds, or fails after about a
/// second. For effects of `onAction`, which starts unstructured tasks.
@MainActor
func waitUntil(
    _ condition: @MainActor () async -> Bool,
    sourceLocation: SourceLocation = #_sourceLocation
) async throws {
    for _ in 0..<200 {
        if await condition() { return }
        try await Task.sleep(for: .milliseconds(5))
    }
    Issue.record("Condition never became true", sourceLocation: sourceLocation)
}
