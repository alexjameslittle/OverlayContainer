//
//  UIScrollViiew+Utils.swift
//  Pods
//
//  Created by Gaétan Zanella on 28/11/2018.
//

import UIKit

extension UIScrollView {

    var scrollsUp: Bool {
        return panGestureRecognizer.yDirection == .up
    }

    var scrollsDown: Bool {
        return panGestureRecognizer.yDirection == .down
    }

    var isContentOriginInBounds: Bool {
        return contentOffset.y <= -oc_adjustedContentInset.top
    }

    var isContentEndInBounds: Bool {
        return contentOffset.y >= (contentSize.height - frame.height)
    }

    func scrollToTop() {
        contentOffset.y = -oc_adjustedContentInset.top
    }

    func isContentOriginInBounds(position: OverlayContainerViewController.OverlayPosition) -> Bool {
        switch position {
        case .bottom:
            return contentOffset.y <= -oc_adjustedContentInset.top
        case .top:
            return contentOffset.y >= -oc_adjustedContentInset.top
        }
    }
}


extension UIScrollView {
    
    var oc_adjustedContentInset: UIEdgeInsets {
        
        if #available(iOS 11.0, *) {
            return self.adjustedContentInset
        } else {
            // Fallback on earlier versions
            return self.contentInset
        }
    }
}
