@testable import SecretAgentMan
import Testing

struct DiffServiceTests {
    let service = DiffService()

    @Test
    func parsesFileChangesFromUnifiedDiff() async {
        let diff = """
        diff --git a/src/app/layout.tsx b/src/app/layout.tsx
        index abc1234..def5678 100644
        --- a/src/app/layout.tsx
        +++ b/src/app/layout.tsx
        @@ -1,3 +1,4 @@
         import React from 'react'
        +import { Subscription } from './subscription'
         export default function Layout() {
        -  return <div />
        +  return <div><Subscription /></div>
        diff --git a/src/components/subscription.tsx b/src/components/subscription.tsx
        new file mode 100644
        --- /dev/null
        +++ b/src/components/subscription.tsx
        @@ -0,0 +1,5 @@
        +export function Subscription() {
        +  return <div>Sub</div>
        +}
        """

        let changes = await service.parseChanges(from: diff)

        #expect(changes.count == 2)
        #expect(changes[0].path == "src/app/layout.tsx")
        #expect(changes[0].insertions == 2)
        #expect(changes[0].deletions == 1)
        #expect(changes[0].status == .modified)
        #expect(changes[1].path == "src/components/subscription.tsx")
        #expect(changes[1].insertions == 3)
        #expect(changes[1].status == .added)
    }

    @Test
    func returnsEmptyForNoDiff() async {
        let changes = await service.parseChanges(from: "")
        #expect(changes.isEmpty)
    }

    @Test
    func parsesDeletedFile() async {
        let diff = """
        diff --git a/src/old.ts b/src/old.ts
        deleted file mode 100644
        --- a/src/old.ts
        +++ /dev/null
        @@ -1,3 +0,0 @@
        -export function old() {
        -  return true
        -}
        """
        let changes = await service.parseChanges(from: diff)
        #expect(changes.count == 1)
        #expect(changes[0].status == .deleted)
        #expect(changes[0].deletions == 3)
        #expect(changes[0].insertions == 0)
    }

    @Test
    func parsesMultipleHunksInSameFile() async {
        let diff = """
        diff --git a/src/app.ts b/src/app.ts
        --- a/src/app.ts
        +++ b/src/app.ts
        @@ -1,3 +1,4 @@
         line1
        +added1
         line2
         line3
        @@ -10,3 +11,4 @@
         line10
        +added2
         line11
         line12
        """
        let changes = await service.parseChanges(from: diff)
        #expect(changes.count == 1)
        #expect(changes[0].insertions == 2)
        #expect(changes[0].deletions == 0)
    }

    @Test
    func parsesFileWithOnlyAdditions() async {
        let diff = """
        diff --git a/src/new.ts b/src/new.ts
        --- a/src/new.ts
        +++ b/src/new.ts
        @@ -1,2 +1,5 @@
         existing
        +line1
        +line2
        +line3
         end
        """
        let changes = await service.parseChanges(from: diff)
        #expect(changes.count == 1)
        #expect(changes[0].insertions == 3)
        #expect(changes[0].deletions == 0)
        #expect(changes[0].status == .added)
    }

    @Test
    func parsesFileWithOnlyDeletions() async {
        let diff = """
        diff --git a/src/shrink.ts b/src/shrink.ts
        --- a/src/shrink.ts
        +++ b/src/shrink.ts
        @@ -1,5 +1,2 @@
         existing
        -line1
        -line2
        -line3
         end
        """
        let changes = await service.parseChanges(from: diff)
        #expect(changes.count == 1)
        #expect(changes[0].deletions == 3)
        #expect(changes[0].insertions == 0)
        #expect(changes[0].status == .deleted)
    }
}
