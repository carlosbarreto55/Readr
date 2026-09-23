import Foundation
import Testing

@testable import Readr

@Suite("Background tasks")
struct BackgroundTasksTests {

    @Test("Both identifiers are declared, or the scheduler refuses to register them")
    func identifiersAreDeclared() throws {
        let declared = try #require(
            Bundle.main.object(forInfoDictionaryKey: "BGTaskSchedulerPermittedIdentifiers")
                as? [String])
        #expect(declared.contains(BackgroundTasks.libraryRefresh))
        #expect(declared.contains(BackgroundTasks.downloadProcessing))
    }
}
