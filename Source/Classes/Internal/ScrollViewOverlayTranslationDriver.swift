//
//  ScrollViewOverlayTranslationDriver.swift
//  OverlayContainer
//
//  Created by Gaétan Zanella on 29/11/2018.
//

import UIKit

class ScrollViewOverlayTranslationDriver: OverlayTranslationDriver, OverlayScrollViewDelegate {

    weak var translationController: OverlayTranslationController?
    weak var scrollView: UIScrollView?
    private let position: OverlayContainerViewController.OverlayPosition

    private let scrollViewDelegateProxy = OverlayScrollViewDelegateProxy()

    // (gz) 2018-11-27 The overlay's transaction is not always equal to the scroll view translation.
    // The user can scroll bottom then drag the overlay up repeatedly in a single gesture.
    private var overlayTranslation: CGFloat = 0
    private var scrollViewTranslation: CGFloat = 0
    private var lastContentOffsetWhileScrolling: CGPoint = .zero

    // MARK: - Life Cycle

    init(translationController: OverlayTranslationController, scrollView: UIScrollView,
         position: OverlayContainerViewController.OverlayPosition) {
        self.translationController = translationController
        self.scrollView = scrollView
        self.position = position
        scrollViewDelegateProxy.forward(to: self, delegateInvocationsFrom: scrollView)
        lastContentOffsetWhileScrolling = scrollView.contentOffset
    }

    // MARK: - OverlayTranslationDriver

    func clean() {
        scrollViewDelegateProxy.cancelForwarding()
    }

    // MARK: - OverlayScrollViewDelegate

    func overlayScrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        translationController?.startOverlayTranslation()
    }

    func overlayScrollViewDidScroll(_ scrollView: UIScrollView) {
        guard let controller = translationController else { return }
        let previousTranslation = scrollViewTranslation
        let translation = scrollView.panGestureRecognizer.translation(in: scrollView)
        scrollViewTranslation = translation.y
        if shouldDragOverlay(following: scrollView) {
            overlayTranslation += scrollViewTranslation - previousTranslation
            let offset = adjustedContentOffset(dragging: scrollView)
            lastContentOffsetWhileScrolling = offset
            scrollView.contentOffset = offset // Warning : calls `overlayScrollViewDidScroll(_:)` again
            controller.dragOverlay(withOffset: overlayTranslation, usesFunction: false)
        } else {
            lastContentOffsetWhileScrolling = scrollView.contentOffset
        }
    }

    func overlayScrollView(_ scrollView: UIScrollView,
                           willEndDraggingwithVelocity velocity: CGPoint,
                           targetContentOffset: UnsafeMutablePointer<CGPoint>) {
        guard let controller = translationController else { return }
        overlayTranslation = 0
        scrollViewTranslation = 0
        // (gz) 2018-11-27 We reset the translation each time the user ends dragging.
        // Otherwise the calculation is wrong in `overlayScrollViewDidScroll(_:)`
        // if the user drags the overlay while the animation did not finish.
        scrollView.panGestureRecognizer.setTranslation(.zero, in: nil)
        // (gz) 2018-01-24 We adjust the content offset and the velocity only if the overlay will be dragged.
        switch controller.translationPosition {
        case .bottom where targetContentOffset.pointee.y > -scrollView.oc_adjustedContentInset.top:
            // (gz) 2018-11-26 The user raises its finger in the bottom position
            // and the content offset will exceed the top content inset.
            targetContentOffset.pointee.y = -scrollView.oc_adjustedContentInset.top
        case .inFlight where !controller.overlayHasReachedANotch():
            targetContentOffset.pointee.y = lastContentOffsetWhileScrolling.y
        case .top, .bottom, .inFlight, .stationary:
            break
        }
        // If the overlay is in flight and the user scrolls bottom, we ignore the velocity and we do not
        // modify the target offset.
        let adjustedVelocity: CGPoint
        if shouldDragOverlay(following: scrollView) {
            adjustedVelocity =  velocity
        } else {
            adjustedVelocity = .zero
        }
        controller.endOverlayTranslation(withVelocity: adjustedVelocity)
    }

    // MARK: - Private

    private func shouldDragOverlay(following scrollView: UIScrollView) -> Bool {
        guard let controller = translationController, scrollView.isTracking else { return false }
        let velocity = scrollView.panGestureRecognizer.velocity(in: nil).y
        let movesUp = velocity < 0
        switch controller.translationPosition {
        case .bottom:
            let shouldDrag = !scrollView.isContentOriginInBounds && scrollView.scrollsUp
            return shouldDrag
        case .top:
            switch position {
            case .bottom:
                let shouldDrag = scrollView.isContentOriginInBounds && !movesUp
                return shouldDrag
            case .top:
                let shouldDrag = scrollView.isContentEndInBounds && movesUp
                return shouldDrag
            }
        case .inFlight:
            switch position {
            case .bottom:
                let shouldDrag = scrollView.isContentOriginInBounds || scrollView.scrollsUp
                return shouldDrag
            case .top:
                let shouldDrag = scrollView.isContentEndInBounds || scrollView.scrollsDown
                return shouldDrag
            }

        case .stationary:
            switch position {
            case .bottom:
                return scrollView.scrollsUp
            case .top:
                return scrollView.scrollsDown
            }
        }
    }

    private func adjustedContentOffset(dragging scrollView: UIScrollView) -> CGPoint {
        guard let controller = translationController else { return .zero }
        var contentOffset = lastContentOffsetWhileScrolling
        let topInset = -scrollView.oc_adjustedContentInset.top
        let bottomInset = (scrollView.contentSize.height - scrollView.frame.height)
        switch controller.translationPosition {
        case .inFlight, .top, .bottom:
            // (gz) 2018-11-26 The user raised its finger in the top or in flight positions while scrolling bottom.
            // If the scroll's animation did not finish when the user translates the overlay,
            // the content offset may have exceeded the top inset. We adjust it.
            switch position {
            case .bottom:
                if contentOffset.y < topInset {
                    contentOffset.y = topInset
                }
            case .top:
                if contentOffset.y > bottomInset {
                    contentOffset.y = bottomInset
                }
            }
        case .stationary:
            break
        }
        // (gz) 2018-11-26 Between two `overlayScrollViewDidScroll:` calls,
        // the scrollView exceeds the top's contentInset. We adjust the target.
        switch position {
        case .bottom:
            if (contentOffset.y - topInset) * (scrollView.contentOffset.y - topInset) < 0 {
                contentOffset.y = topInset
            }
        case .top:
            if (contentOffset.y - bottomInset) * (scrollView.contentOffset.y - bottomInset) < 0 {
                contentOffset.y = bottomInset
            }
        }

        return contentOffset
    }
}
