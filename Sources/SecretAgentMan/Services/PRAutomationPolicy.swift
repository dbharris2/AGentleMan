import Foundation

struct PRAutomationPolicy {
    struct Settings: Equatable {
        let autoFixCI: Bool
        let autoAnalyzeReviews: Bool
    }

    struct DeepDetails: Equatable {
        let reviewComments: [PRReviewComment]
        let failedChecks: [String]
        let detailedCheckStatus: PRCheckStatus
    }

    enum EventKind: Equatable {
        case changesRequested
        case checksFailed
        case approvedWithComments
    }

    struct InitialPlan: Equatable {
        let needsDeepFetch: Bool
    }

    struct DeepPlan: Equatable {
        let events: [EventKind]
    }

    func initialPlan(old: PRInfo?, new: PRInfo, settings: Settings) -> InitialPlan {
        let hasFailedChecksTransition = new.checkStatus == .fail && old?.checkStatus != .fail
        let hasChangesRequestedTransition = new.state == .changesRequested && old?.state != .changesRequested
        let hasApprovedTransition = new.state == .approved && old?.state != .approved

        let needsDeepFetch = (settings.autoFixCI && hasFailedChecksTransition)
            || (settings.autoAnalyzeReviews && hasChangesRequestedTransition)
            || (settings.autoAnalyzeReviews && hasApprovedTransition)

        return InitialPlan(needsDeepFetch: needsDeepFetch)
    }

    func mergedInfo(current: PRInfo, details: DeepDetails) -> PRInfo {
        PRInfo(
            number: current.number,
            url: current.url,
            state: current.state,
            checkStatus: details.detailedCheckStatus,
            additions: current.additions,
            deletions: current.deletions,
            changedFiles: current.changedFiles,
            commentCount: current.commentCount,
            reviewers: current.reviewers,
            reviewComments: details.reviewComments,
            failedChecks: details.failedChecks
        )
    }

    func deepPlan(old: PRInfo?, new: PRInfo, details: DeepDetails, settings: Settings) -> DeepPlan {
        let hasFailedChecksTransition = new.checkStatus == .fail && old?.checkStatus != .fail
        let hasChangesRequestedTransition = new.state == .changesRequested && old?.state != .changesRequested
        let hasApprovedTransition = new.state == .approved && old?.state != .approved

        var events: [EventKind] = []

        if settings.autoFixCI, hasFailedChecksTransition {
            events.append(.checksFailed)
        }

        if settings.autoAnalyzeReviews, hasChangesRequestedTransition {
            events.append(.changesRequested)
        }

        if settings.autoAnalyzeReviews, hasApprovedTransition {
            let approvalComments = details.reviewComments
                .filter { $0.state == .approved && !$0.body.isEmpty }
            let oldCommentCount = old?.reviewComments.count(where: { $0.state == .approved }) ?? 0
            if approvalComments.count > oldCommentCount {
                events.append(.approvedWithComments)
            }
        }

        return DeepPlan(events: events)
    }
}
