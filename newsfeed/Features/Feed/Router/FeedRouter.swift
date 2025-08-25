//
//  FeedRouter.swift
//  newsfeed
//
//  Created by Stanislav Ivanov on 24.08.2025.
//

import SafariServices
import UIKit

enum FeedRouter {
    static func openWeb(from vc: UIViewController, url: URL) {
        let safari = SFSafariViewController(url: url)
        safari.preferredControlTintColor = .label
        safari.modalPresentationStyle = .pageSheet
        vc.present(safari, animated: true)
    }
}
