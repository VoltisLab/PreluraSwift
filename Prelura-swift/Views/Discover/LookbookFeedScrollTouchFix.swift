//
//  LookbookFeedScrollTouchFix.swift
//  Prelura-swift
//
//  SwiftUI ScrollView is backed by UIScrollView, which defaults to delaysContentTouches = true.
//  That can prevent taps on nested controls (e.g. like) from firing reliably - especially inside
//  LazyVStack. Anchoring this view in scroll content walks up to the enclosing UIScrollView and
//  disables touch delay. We re-run when the view attaches to a window because hierarchy timing
//  can be late on first layout.
//

import SwiftUI
import UIKit

/// Finds the nearest UIScrollView ancestor and disables delayed content touches.
private final class ScrollImmediateTouchesAnchorView: UIView {
    override func didMoveToSuperview() {
        super.didMoveToSuperview()
        applyScrollImmediateTouchesIfNeeded()
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        applyScrollImmediateTouchesIfNeeded()
        if window != nil {
            DispatchQueue.main.async { [weak self] in
                self?.applyScrollImmediateTouchesIfNeeded()
            }
        }
    }

    private func applyScrollImmediateTouchesIfNeeded() {
        guard superview != nil else { return }
        var ancestor: UIView? = superview
        while let cur = ancestor {
            if let sc = cur as? UIScrollView {
                sc.delaysContentTouches = false
                sc.canCancelContentTouches = true
                break
            }
            ancestor = cur.superview
        }
    }
}

/// Place once per SwiftUI `ScrollView`’s content (e.g. first child, zero size) so buttons/taps inside respond immediately.
struct LookbookScrollImmediateTouchesAnchor: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        ScrollImmediateTouchesAnchorView()
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
}
