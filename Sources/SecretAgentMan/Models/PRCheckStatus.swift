import Foundation

enum PRState: Equatable {
    case draft
    case changesRequested
    case needsReview
    case approved
    case inMergeQueue
    case merged
}

struct PRInfo: Equatable {
    let number: Int
    let url: URL
    let state: PRState
    let checkStatus: PRCheckStatus
    let additions: Int
    let deletions: Int
    let changedFiles: Int
    let commentCount: Int
    let reviewers: [PRReviewer]
    let reviewComments: [PRReviewComment]
    let failedChecks: [String]
}

struct PRReviewComment: Equatable {
    let author: String
    let body: String
    let state: PRReviewState
}

enum PRReviewState: String, Equatable {
    case approved = "APPROVED"
    case changesRequested = "CHANGES_REQUESTED"
    case commented = "COMMENTED"
    case dismissed = "DISMISSED"
    case pending = "PENDING"
}

struct PRReviewer: Equatable, Hashable {
    let login: String
    let avatarURL: URL
}

enum PRCheckStatus: Equatable {
    case pass
    case fail
    case pending
    case none
}
