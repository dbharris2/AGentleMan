import Foundation
@testable import SecretAgentMan
import Testing

struct PRServiceTests {
    let service = PRService()

    // MARK: - parsePRInfo

    @Test
    func parsesBasicPRInfo() async {
        let json = makePRJSON(
            number: 123,
            url: "https://github.com/org/repo/pull/123",
            additions: 10,
            deletions: 5,
            changedFiles: 3
        )
        let info = await service.parsePRInfo(from: json)
        #expect(info != nil)
        #expect(info?.number == 123)
        #expect(info?.url == URL(string: "https://github.com/org/repo/pull/123"))
        #expect(info?.state == .needsReview)
        #expect(info?.additions == 10)
        #expect(info?.deletions == 5)
        #expect(info?.changedFiles == 3)
    }

    @Test
    func parsesEmptyArrayAsNil() async {
        let info = await service.parsePRInfo(from: "[]")
        #expect(info == nil)
    }

    @Test
    func parsesMalformedJSONAsNil() async {
        let info = await service.parsePRInfo(from: "not json")
        #expect(info == nil)
    }

    @Test
    func parsesEmptyStringAsNil() async {
        let info = await service.parsePRInfo(from: "")
        #expect(info == nil)
    }

    // MARK: - PR State

    @Test
    func detectsDraftState() async {
        let json = makePRJSON(isDraft: true, state: "OPEN", reviewDecision: "", mergeStateStatus: "")
        let info = await service.parsePRInfo(from: json)
        #expect(info?.state == .draft)
    }

    @Test
    func detectsMergedState() async {
        let json = makePRJSON(isDraft: false, state: "MERGED", reviewDecision: "APPROVED", mergeStateStatus: "")
        let info = await service.parsePRInfo(from: json)
        #expect(info?.state == .merged)
    }

    @Test
    func detectsApprovedState() async {
        let json = makePRJSON(isDraft: false, state: "OPEN", reviewDecision: "APPROVED", mergeStateStatus: "")
        let info = await service.parsePRInfo(from: json)
        #expect(info?.state == .approved)
    }

    @Test
    func detectsChangesRequestedState() async {
        let json = makePRJSON(isDraft: false, state: "OPEN", reviewDecision: "CHANGES_REQUESTED", mergeStateStatus: "")
        let info = await service.parsePRInfo(from: json)
        #expect(info?.state == .changesRequested)
    }

    @Test
    func detectsInMergeQueueState() async {
        let json = makePRJSON(isDraft: false, state: "OPEN", reviewDecision: "APPROVED", mergeStateStatus: "QUEUED")
        let info = await service.parsePRInfo(from: json)
        #expect(info?.state == .inMergeQueue)
    }

    @Test
    func mergedTakesPriorityOverDraft() async {
        let json = makePRJSON(isDraft: true, state: "MERGED", reviewDecision: "", mergeStateStatus: "")
        let info = await service.parsePRInfo(from: json)
        #expect(info?.state == .merged)
    }

    // MARK: - Check Status

    @Test
    func allChecksPassed() async {
        let json = makePRJSON(checks: [
            makeCheckRun(status: "COMPLETED", conclusion: "SUCCESS"),
            makeCheckRun(status: "COMPLETED", conclusion: "SUCCESS"),
        ])
        let info = await service.parsePRInfo(from: json)
        #expect(info?.checkStatus == .pass)
    }

    @Test
    func skippedCheckCountsAsPass() async {
        let json = makePRJSON(checks: [
            makeCheckRun(status: "COMPLETED", conclusion: "SUCCESS"),
            makeCheckRun(status: "COMPLETED", conclusion: "SKIPPED"),
        ])
        let info = await service.parsePRInfo(from: json)
        #expect(info?.checkStatus == .pass)
    }

    @Test
    func failedCheckReturnsFail() async {
        let json = makePRJSON(checks: [
            makeCheckRun(status: "COMPLETED", conclusion: "SUCCESS"),
            makeCheckRun(status: "COMPLETED", conclusion: "FAILURE"),
        ])
        let info = await service.parsePRInfo(from: json)
        #expect(info?.checkStatus == .fail)
    }

    @Test
    func pendingCheckReturnsPending() async {
        let json = makePRJSON(checks: [
            makeCheckRun(status: "COMPLETED", conclusion: "SUCCESS"),
            makeCheckRun(status: "IN_PROGRESS", conclusion: ""),
        ])
        let info = await service.parsePRInfo(from: json)
        #expect(info?.checkStatus == .pending)
    }

    @Test
    func noChecksReturnsNone() async {
        let json = makePRJSON(checks: [])
        let info = await service.parsePRInfo(from: json)
        #expect(info?.checkStatus == PRCheckStatus.none)
    }

    @Test
    func statusContextSuccess() async {
        let json = makePRJSON(checks: [
            makeStatusContext(state: "SUCCESS"),
        ])
        let info = await service.parsePRInfo(from: json)
        #expect(info?.checkStatus == .pass)
    }

    @Test
    func statusContextFailure() async {
        let json = makePRJSON(checks: [
            makeStatusContext(state: "FAILURE"),
        ])
        let info = await service.parsePRInfo(from: json)
        #expect(info?.checkStatus == .fail)
    }

    @Test
    func statusContextPending() async {
        let json = makePRJSON(checks: [
            makeStatusContext(state: "PENDING"),
        ])
        let info = await service.parsePRInfo(from: json)
        #expect(info?.checkStatus == .pending)
    }

    @Test
    func mixedCheckRunAndStatusContext() async {
        let json = makePRJSON(checks: [
            makeCheckRun(status: "COMPLETED", conclusion: "SUCCESS"),
            makeStatusContext(state: "SUCCESS"),
        ])
        let info = await service.parsePRInfo(from: json)
        #expect(info?.checkStatus == .pass)
    }

    // MARK: - Reviewers

    @Test
    func excludesAuthorFromReviewers() async {
        let json = makePRJSON(
            reviews: [#"{"author":{"login":"author"}}"#, #"{"author":{"login":"reviewer1"}}"#]
        )
        let info = await service.parsePRInfo(from: json)
        #expect(info?.reviewers.count == 1)
        #expect(info?.reviewers.first?.login == "reviewer1")
    }

    @Test
    func deduplicatesReviewers() async {
        let json = makePRJSON(
            reviews: [#"{"author":{"login":"reviewer1"}}"#, #"{"author":{"login":"reviewer1"}}"#],
            reviewRequests: [#"{"login":"reviewer1"}"#]
        )
        let info = await service.parsePRInfo(from: json)
        #expect(info?.reviewers.count == 1)
    }

    @Test
    func combinesReviewsAndRequests() async {
        let json = makePRJSON(
            reviews: [#"{"author":{"login":"reviewer1"}}"#],
            reviewRequests: [#"{"login":"reviewer2"}"#]
        )
        let info = await service.parsePRInfo(from: json)
        #expect(info?.reviewers.count == 2)
    }

    // MARK: - Helpers

    // swiftlint:disable function_parameter_count
    private func makePRJSON(
        number: Int = 1,
        url: String = "https://github.com/o/r/pull/1",
        isDraft: Bool = false,
        state: String = "OPEN",
        reviewDecision: String = "",
        mergeStateStatus: String = "",
        checks: [String] = [],
        additions: Int = 0,
        deletions: Int = 0,
        changedFiles: Int = 0,
        reviews: [String] = [],
        reviewRequests: [String] = []
    ) -> String {
        let checksStr = checks.joined(separator: ",")
        let reviewsStr = reviews.joined(separator: ",")
        let requestsStr = reviewRequests.joined(separator: ",")
        return """
        [{\
        "number":\(number),\
        "url":"\(url)",\
        "isDraft":\(isDraft),\
        "state":"\(state)",\
        "reviewDecision":"\(reviewDecision)",\
        "mergeStateStatus":"\(mergeStateStatus)",\
        "statusCheckRollup":[\(checksStr)],\
        "additions":\(additions),\
        "deletions":\(deletions),\
        "changedFiles":\(changedFiles),\
        "comments":[],\
        "reviews":[\(reviewsStr)],\
        "reviewRequests":[\(requestsStr)],\
        "author":{"login":"author"}\
        }]
        """
    }

    // swiftlint:enable function_parameter_count

    private func makeCheckRun(status: String, conclusion: String) -> String {
        #"{"__typename":"CheckRun","status":"\#(status)","conclusion":"\#(conclusion)"}"#
    }

    private func makeStatusContext(state: String) -> String {
        """
        {"__typename":"StatusContext","state":"\(state)"}
        """
    }
}
