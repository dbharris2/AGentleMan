@testable import AGentleMan
import Testing

@Suite("DiffService")
struct DiffServiceTests {
    let service = DiffService()

    @Test("parses jj diff stat output")
    func parsesJJDiffStat() async {
        let output = """
        src/app/layout.tsx                          |  2 +-
        src/components/subscription.tsx              | 42 ++++++++++++++++++++++++++++
        src/utils/feature-flags/flags.ts             |  2 +-
        3 files changed, 45 insertions(+), 1 deletion(-)
        """

        let changes = await service.parseDiffStat(output)

        #expect(changes.count == 3)
        #expect(changes[0].path == "src/app/layout.tsx")
        #expect(changes[0].insertions > 0)
        #expect(changes[0].deletions > 0)
        #expect(changes[1].path == "src/components/subscription.tsx")
        #expect(changes[1].insertions > 0)
        #expect(changes[1].deletions == 0)
    }

    @Test("returns empty for no changes")
    func emptyOutput() async {
        let changes = await service.parseDiffStat("")
        #expect(changes.isEmpty)
    }

    @Test("handles git diff stat format")
    func parsesGitDiffStat() async {
        let output = """
         README.md | 10 +++++++---
         1 file changed, 7 insertions(+), 3 deletions(-)
        """

        let changes = await service.parseDiffStat(output)
        #expect(changes.count == 1)
        #expect(changes[0].path == "README.md")
    }
}
