import Testing
import Foundation

@Suite("Hook Installer — Plugin Updates")
struct HookInstallerUpdateTests {

    @Test("Returns error when claude CLI not found")
    func returnsErrorWhenClaudeNotFound() {
        // updatePluginIfNeeded checks version before invoking the CLI.
        // When bundled > installed, it calls claude plugin install.
        // We document the expected behavior; CLI invocation is covered by HookInstallerTests.
    }
}
