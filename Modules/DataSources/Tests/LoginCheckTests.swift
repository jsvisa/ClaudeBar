import Foundation
import Mockable
import Quotas
import Testing
@testable import DataSources

/// `loginCheck` — when a data source declares a command whose success says the
/// CLI is signed in, a missing `requiresFiles` entry asks the command instead
/// of refusing (#525): the login may live outside the file, as a keyring does.
/// The check fails closed — anything but a clean exit is *not signed in* — and
/// it never starts a login (#216).
@Suite
struct LoginCheckTests {
    private func decode(_ json: String) throws -> DataSourceDefinition {
        try JSONDecoder().decode(DataSourceDefinition.self, from: Data(json.utf8))
    }

    private func make(_ definition: DataSourceDefinition, executor: MockCLIExecutor, network: MockNetworkClient) -> DataSource {
        DataSources.make(definition, providerId: "acme", cliExecutor: executor, network: network,
                         makeTransport: { _, _, _, _ in MockRPCTransport() }, environment: { _ in nil },
                         homeDirectory: FileManager.default.temporaryDirectory, now: { Date() })
    }

    private func http(_ body: String) -> MockNetworkClient {
        let network = MockNetworkClient()
        let response = HTTPURLResponse(url: URL(string: "https://example.com")!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        given(network).request(.any).willReturn((Data(body.utf8), response))
        return network
    }

    private func check(output: String = "Logged in", exitCode: Int32 = 0, found: Bool = true) -> MockCLIExecutor {
        let executor = MockCLIExecutor()
        given(executor).locate(.any).willReturn(found ? "/usr/local/bin/acme" : nil)
        given(executor).execute(binary: .matching { $0 == "acme" },
                                args: .matching { $0 == ["login", "status"] },
                                input: .any, timeout: .any, workingDirectory: .any, autoResponses: .any)
            .willReturn(CLIResult(output: output, exitCode: exitCode))
        return executor
    }

    /// A definition that needs a file that is not there, and asks the CLI instead.
    private let usage = """
    {"kind":"api",
     "requiresFiles":["/no/such/acme/auth.json"],
     "loginCheck":{"cli":"acme","args":["login","status"]},
     "fetch":{"http":{"url":"https://example.com/usage"}},
     "mapping":{"json":{"quotas":[{"kind":"weekly","usedPercent":"used"}]}}}
    """

    @Test
    func `should fetch when a file it needs is missing but the login check says signed in`() async throws {
        let source = make(try decode(usage), executor: check(), network: http(#"{"used":25}"#))

        let usage = try await source.fetchUsage()

        #expect(usage.quota(for: .weekly)?.percentRemaining == 75)
    }

    @Test
    func `should refuse with key needed when the login check says not signed in`() async throws {
        let source = make(try decode(usage), executor: check(output: "Not logged in", exitCode: 1), network: http("{}"))

        await #expect(throws: DataSourceError(.lookup, .authenticationRequired)) { try await source.fetchUsage() }
    }

    @Test
    func `should treat a login check whose CLI is not installed as not signed in`() async throws {
        let source = make(try decode(usage), executor: check(found: false), network: http("{}"))

        await #expect(throws: DataSourceError(.lookup, .authenticationRequired)) { try await source.fetchUsage() }
    }

    @Test
    func `should treat a login check that cannot run as not signed in`() async throws {
        let executor = MockCLIExecutor()
        given(executor).locate(.any).willReturn("/usr/local/bin/acme")
        given(executor).execute(binary: .any, args: .any, input: .any, timeout: .any, workingDirectory: .any, autoResponses: .any)
            .willThrow(UsageError.executionFailed("could not start"))
        let source = make(try decode(usage), executor: executor, network: http("{}"))

        await #expect(throws: DataSourceError(.lookup, .authenticationRequired)) { try await source.fetchUsage() }
    }

    @Test
    func `should read the login check's command from the definition and keep it when written back`() throws {
        let definition = try decode(usage)

        #expect(definition.loginCheck == CommandCall(cli: "acme", args: ["login", "status"]))
        #expect(try JSONEncoder().decode(DataSourceDefinition.self,
                                         from: JSONEncoder().encode(definition)).loginCheck == definition.loginCheck)
    }

    @Test
    func `should leave a definition without a login check without one`() throws {
        let definition = try decode("""
        {"kind":"api","requiresFiles":["/no/such/acme/auth.json"],
         "fetch":{"http":{"url":"https://example.com/usage"}},
         "mapping":{"json":{"quotas":[]}}}
        """)

        #expect(definition.loginCheck == nil)
    }
}
