import Foundation
import Mockable
import Testing
@testable import DataSources

/// *Configured* — what `isReady` answers before anything runs.
@Suite
struct ReadinessTests {
    private func make(requiresFiles: [String], loginCheck: CommandCall? = nil, executor: MockCLIExecutor? = nil) -> DataSource {
        let definition = DataSourceDefinition(kind: "file", fetch: .http(HTTPRequest(url: "https://acme.test")),
                                              mapping: .script(ScriptMapping(file: "none.js")), requiresFiles: requiresFiles,
                                              loginCheck: loginCheck)
        return DataSources.make(definition, providerId: "acme", cliExecutor: executor ?? MockCLIExecutor(), network: MockNetworkClient(),
                                makeTransport: { _, _, _, _ in MockRPCTransport() }, environment: { _ in nil },
                                homeDirectory: FileManager.default.temporaryDirectory, now: { Date() })
    }

    @Test
    func `should not be configured when a file it needs is missing`() async {
        #expect(await make(requiresFiles: ["/no/such/acme/login.json"]).isReady() == false)
    }

    @Test
    func `should be configured when the files it needs exist`() async throws {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("acme-\(UUID().uuidString).json")
        try Data("{}".utf8).write(to: file)
        defer { try? FileManager.default.removeItem(at: file) }
        #expect(await make(requiresFiles: [file.path]).isReady() == true)
    }

    @Test
    func `should be configured when a needed file is missing but the login check says signed in`() async {
        let executor = MockCLIExecutor()
        given(executor).locate(.any).willReturn("/usr/local/bin/acme")
        given(executor).execute(binary: .any, args: .any, input: .any, timeout: .any, workingDirectory: .any, autoResponses: .any)
            .willReturn(CLIResult(output: "Logged in"))
        #expect(await make(requiresFiles: ["/no/such/acme/login.json"],
                           loginCheck: CommandCall(cli: "acme", args: ["login", "status"]),
                           executor: executor).isReady() == true)
    }

    @Test
    func `should not be configured when a needed file is missing and the login check says not signed in`() async {
        let executor = MockCLIExecutor()
        given(executor).locate(.any).willReturn("/usr/local/bin/acme")
        given(executor).execute(binary: .any, args: .any, input: .any, timeout: .any, workingDirectory: .any, autoResponses: .any)
            .willReturn(CLIResult(output: "Not logged in", exitCode: 1))
        #expect(await make(requiresFiles: ["/no/such/acme/login.json"],
                           loginCheck: CommandCall(cli: "acme", args: ["login", "status"]),
                           executor: executor).isReady() == false)
    }
}
