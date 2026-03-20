import Cocoa
import SwiftUI

/// 动画管理器
/// 提供统一的动画效果和过渡
class AnimationManager {

    // MARK: - Singleton

    static let shared = AnimationManager()

    private init() {}

    // MARK: - Status Bar Animations

    /// 状态栏图标脉冲动画
    func pulseStatusBarIcon(_ button: NSStatusBarButton, color: NSColor = .systemBlue) {
        guard let layer = button.layer else { return }

        // 创建脉冲动画
        let pulseAnimation = CABasicAnimation(keyPath: "transform.scale")
        pulseAnimation.fromValue = 1.0
        pulseAnimation.toValue = 1.3
        pulseAnimation.duration = 0.3
        pulseAnimation.autoreverses = true
        pulseAnimation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)

        // 创建颜色动画
        let colorAnimation = CABasicAnimation(keyPath: "backgroundColor")
        colorAnimation.fromValue = NSColor.clear.cgColor
        colorAnimation.toValue = color.withAlphaComponent(0.3).cgColor
        colorAnimation.duration = 0.3
        colorAnimation.autoreverses = true
        colorAnimation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)

        // 组合动画
        let groupAnimation = CAAnimationGroup()
        groupAnimation.animations = [pulseAnimation, colorAnimation]
        groupAnimation.duration = 0.6

        layer.add(groupAnimation, forKey: "pulseAnimation")
    }

    /// 状态栏图标旋转动画
    func rotateStatusBarIcon(_ button: NSStatusBarButton) {
        guard let layer = button.layer else { return }

        let rotationAnimation = CABasicAnimation(keyPath: "transform.rotation")
        rotationAnimation.fromValue = 0
        rotationAnimation.toValue = Double.pi * 2
        rotationAnimation.duration = 0.5
        rotationAnimation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)

        layer.add(rotationAnimation, forKey: "rotationAnimation")
    }

    /// 状态栏图标闪烁动画
    func blinkStatusBarIcon(_ button: NSStatusBarButton, count: Int = 3) {
        guard let layer = button.layer else { return }

        let blinkAnimation = CABasicAnimation(keyPath: "opacity")
        blinkAnimation.fromValue = 1.0
        blinkAnimation.toValue = 0.3
        blinkAnimation.duration = 0.2
        blinkAnimation.autoreverses = true
        blinkAnimation.repeatCount = Float(count)
        blinkAnimation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)

        layer.add(blinkAnimation, forKey: "blinkAnimation")
    }

    // MARK: - Popover Animations

    /// 弹出窗口出现动画
    func animatePopoverAppearance(_ popover: NSPopover) {
        guard let contentView = popover.contentViewController?.view else { return }

        // 初始状态
        contentView.layer?.opacity = 0
        contentView.layer?.transform = CATransform3DMakeScale(0.8, 0.8, 1.0)

        // 动画到最终状态
        CATransaction.begin()
        CATransaction.setAnimationDuration(0.25)
        CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .easeOut))

        contentView.layer?.opacity = 1.0
        contentView.layer?.transform = CATransform3DIdentity

        CATransaction.commit()
    }

    /// 弹出窗口消失动画
    func animatePopoverDisappearance(_ popover: NSPopover, completion: @escaping () -> Void) {
        guard let contentView = popover.contentViewController?.view else {
            completion()
            return
        }

        CATransaction.begin()
        CATransaction.setAnimationDuration(0.2)
        CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .easeIn))
        CATransaction.setCompletionBlock(completion)

        contentView.layer?.opacity = 0
        contentView.layer?.transform = CATransform3DMakeScale(0.8, 0.8, 1.0)

        CATransaction.commit()
    }

    // MARK: - Window Animations

    /// 窗口淡入动画
    func fadeInWindow(_ window: NSWindow, duration: TimeInterval = 0.3) {
        window.alphaValue = 0
        window.makeKeyAndOrderFront(nil)

        NSAnimationContext.runAnimationGroup { context in
            context.duration = duration
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            window.animator().alphaValue = 1.0
        }
    }

    /// 窗口淡出动画
    func fadeOutWindow(_ window: NSWindow, duration: TimeInterval = 0.3, completion: @escaping () -> Void = {}) {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = duration
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            window.animator().alphaValue = 0
        } completionHandler: {
            window.orderOut(nil)
            completion()
        }
    }

    /// 窗口缩放出现动画
    func scaleInWindow(_ window: NSWindow, duration: TimeInterval = 0.3) {
        let originalFrame = window.frame
        let scaledFrame = NSRect(
            x: originalFrame.midX - originalFrame.width * 0.4,
            y: originalFrame.midY - originalFrame.height * 0.4,
            width: originalFrame.width * 0.8,
            height: originalFrame.height * 0.8
        )

        window.setFrame(scaledFrame, display: false)
        window.alphaValue = 0
        window.makeKeyAndOrderFront(nil)

        NSAnimationContext.runAnimationGroup { context in
            context.duration = duration
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            window.animator().setFrame(originalFrame, display: true)
            window.animator().alphaValue = 1.0
        }
    }

    // MARK: - SwiftUI Animations

    /// 获取弹簧动画
    static func springAnimation(duration: Double = 0.5, bounce: Double = 0.3) -> Animation {
        .spring(duration: duration, bounce: bounce)
    }

    /// 获取缓动动画
    static func easeAnimation(duration: Double = 0.3) -> Animation {
        .easeInOut(duration: duration)
    }

    /// 获取弹性动画
    static func bounceAnimation(duration: Double = 0.6) -> Animation {
        .interpolatingSpring(stiffness: 300, damping: 15)
    }

    // MARK: - Notification Animations

    /// 通知横幅动画
    func showNotificationBanner(_ view: NSView, in parentView: NSView, duration: TimeInterval = 3.0) {
        // 设置初始位置（屏幕顶部外）
        let finalFrame = NSRect(
            x: 0,
            y: parentView.bounds.height - view.bounds.height,
            width: parentView.bounds.width,
            height: view.bounds.height
        )
        let initialFrame = NSRect(
            x: 0,
            y: parentView.bounds.height,
            width: parentView.bounds.width,
            height: view.bounds.height
        )

        view.frame = initialFrame
        parentView.addSubview(view)

        // 滑入动画
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.4
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            view.animator().frame = finalFrame
        } completionHandler: {
            // 延迟后滑出
            DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                NSAnimationContext.runAnimationGroup { context in
                    context.duration = 0.3
                    context.timingFunction = CAMediaTimingFunction(name: .easeIn)
                    view.animator().frame = initialFrame
                } completionHandler: {
                    view.removeFromSuperview()
                }
            }
        }
    }

    // MARK: - Loading Animations

    /// 创建加载指示器
    func createLoadingIndicator(size: CGFloat = 20) -> NSView {
        let containerView = NSView(frame: NSRect(x: 0, y: 0, width: size, height: size))
        containerView.wantsLayer = true

        let indicatorLayer = CAShapeLayer()
        let path = NSBezierPath(ovalIn: NSRect(x: 2, y: 2, width: size - 4, height: size - 4))
        if #available(macOS 14.0, *) {
            indicatorLayer.path = path.cgPath
        }
        indicatorLayer.fillColor = NSColor.clear.cgColor
        indicatorLayer.strokeColor = NSColor.controlAccentColor.cgColor
        indicatorLayer.lineWidth = 2
        indicatorLayer.lineCap = .round
        indicatorLayer.strokeStart = 0
        indicatorLayer.strokeEnd = 0.8

        containerView.layer?.addSublayer(indicatorLayer)

        // 旋转动画
        let rotationAnimation = CABasicAnimation(keyPath: "transform.rotation")
        rotationAnimation.fromValue = 0
        rotationAnimation.toValue = Double.pi * 2
        rotationAnimation.duration = 1.0
        rotationAnimation.repeatCount = .infinity
        rotationAnimation.timingFunction = CAMediaTimingFunction(name: .linear)

        indicatorLayer.add(rotationAnimation, forKey: "rotation")

        return containerView
    }

    /// 停止加载指示器
    func stopLoadingIndicator(_ view: NSView) {
        view.layer?.sublayers?.forEach { $0.removeAllAnimations() }
    }

    // MARK: - Transition Animations

    /// 视图切换动画
    func transitionBetweenViews(
        from fromView: NSView,
        to toView: NSView,
        in containerView: NSView,
        direction: TransitionDirection = .fade
    ) {
        toView.frame = containerView.bounds

        switch direction {
        case .fade:
            fadeTransition(from: fromView, to: toView, in: containerView)
        case .slideLeft:
            slideTransition(from: fromView, to: toView, in: containerView, direction: .left)
        case .slideRight:
            slideTransition(from: fromView, to: toView, in: containerView, direction: .right)
        case .slideUp:
            slideTransition(from: fromView, to: toView, in: containerView, direction: .up)
        case .slideDown:
            slideTransition(from: fromView, to: toView, in: containerView, direction: .down)
        }
    }

    private func fadeTransition(from fromView: NSView, to toView: NSView, in containerView: NSView) {
        toView.alphaValue = 0
        containerView.addSubview(toView)

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.3
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            fromView.animator().alphaValue = 0
            toView.animator().alphaValue = 1
        } completionHandler: {
            fromView.removeFromSuperview()
        }
    }

    private func slideTransition(
        from fromView: NSView,
        to toView: NSView,
        in containerView: NSView,
        direction: SlideDirection
    ) {
        let containerBounds = containerView.bounds
        var fromEndFrame = containerBounds
        var toStartFrame = containerBounds

        switch direction {
        case .left:
            fromEndFrame.origin.x = -containerBounds.width
            toStartFrame.origin.x = containerBounds.width
        case .right:
            fromEndFrame.origin.x = containerBounds.width
            toStartFrame.origin.x = -containerBounds.width
        case .up:
            fromEndFrame.origin.y = containerBounds.height
            toStartFrame.origin.y = -containerBounds.height
        case .down:
            fromEndFrame.origin.y = -containerBounds.height
            toStartFrame.origin.y = containerBounds.height
        }

        toView.frame = toStartFrame
        containerView.addSubview(toView)

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.4
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            fromView.animator().frame = fromEndFrame
            toView.animator().frame = containerBounds
        } completionHandler: {
            fromView.removeFromSuperview()
        }
    }
}

// MARK: - Animation Types

enum TransitionDirection {
    case fade
    case slideLeft
    case slideRight
    case slideUp
    case slideDown
}

private enum SlideDirection {
    case left, right, up, down
}

// MARK: - SwiftUI Animation Extensions

extension Animation {
    /// 自定义弹簧动画
    static var typelock: Animation {
        .spring(duration: 0.5, bounce: 0.3)
    }

    /// 快速动画
    static var typelockFast: Animation {
        .easeInOut(duration: 0.2)
    }

    /// 慢速动画
    static var typelockSlow: Animation {
        .easeInOut(duration: 0.8)
    }
}
