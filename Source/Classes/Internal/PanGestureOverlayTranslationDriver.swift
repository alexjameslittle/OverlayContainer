//
//  PanGestureOverlayTranslationDriver.swift
//  OverlayContainer
//
//  Created by Gaétan Zanella on 29/11/2018.
//

import UIKit

class PanGestureOverlayTranslationDriver: NSObject, OverlayTranslationDriver {

    private weak var translationController: OverlayTranslationController?
    private let panGestureRecognizer: OverlayTranslationGestureRecognizer

    // MARK: - Life Cycle

    init(translationController: OverlayTranslationController,
         panGestureRecognizer: OverlayTranslationGestureRecognizer) {
        self.translationController = translationController
        self.panGestureRecognizer = panGestureRecognizer
        super.init()
        panGestureRecognizer.addTarget(self, action: #selector(overlayPanGestureAction(_:)))
    }

    // MARK: - OverlayTranslationDriver

    func clean() {
        // no-op
    }

    // MARK: - Action

    @objc private func overlayPanGestureAction(_ sender: OverlayTranslationGestureRecognizer) {
        guard let controller = translationController, let view = sender.view else { return }
        let translation = sender.translation(in: nil)
        let offset = view.transform == .identity ? translation.y : -translation.y
        switch sender.state {
        case .began:
            controller.startOverlayTranslation()
            if controller.isDraggable(at: sender.startingLocation, in: view) {
                controller.dragOverlay(withOffset: offset, usesFunction: true)
            } else {
                sender.cancel()
            }
        case .changed:
            controller.dragOverlay(withOffset: offset, usesFunction: true)
        case .failed, .ended:
            var velocity = sender.velocity(in: nil)
            velocity.y = view.transform == .identity ? velocity.y : -velocity.y
            controller.endOverlayTranslation(withVelocity: velocity)
        case .cancelled, .possible:
            break
        @unknown default:
            break
        }
    }
}
