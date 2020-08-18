//
//  LayoutPrimitives.swift
//
//  Created by Pedro Branco on 12/08/2020.
//  Copyright (c) 2020 Pedro Branco. All rights reserved.
//

import UIKit

public enum LayoutPrimitivesPriority: Float {
    case highest = 1000, almostHighest = 999, high = 750, medium = 500, low = 250, almostLowest = 2, lowest = 1
}

public enum LayoutPrimitives {
    case relative(
        toView: UIView?, // when toView is nil we consider relative to parent
        attribute: NSLayoutConstraint.Attribute,
        relatedBy: NSLayoutConstraint.Relation = .equal,
        to: NSLayoutConstraint.Attribute,
        multiplier: CGFloat = 1,
        constant: CGFloat = 0,
        priority: Float = LayoutPrimitivesPriority.highest.rawValue
    )
    case relativeToSibling(
        attribute: NSLayoutConstraint.Attribute,
        relatedBy: NSLayoutConstraint.Relation = .equal,
        to: NSLayoutConstraint.Attribute,
        multiplier: CGFloat = 1,
        constant: CGFloat = 0,
        priority: Float = LayoutPrimitivesPriority.highest.rawValue
    )
    case alignToSafeArea(
        top: CGFloat = 0,
        right: CGFloat = 0,
        bottom: CGFloat = 0,
        left: CGFloat = 0
    )
    case fixed(
        attribute: NSLayoutConstraint.Attribute,
        relatedBy: NSLayoutConstraint.Relation = .equal,
        constant: CGFloat,
        priority: Float = LayoutPrimitivesPriority.highest.rawValue
    )
    case ratio(
        multiplier: CGFloat,
        constant: CGFloat = 0,
        priority: Float = LayoutPrimitivesPriority.highest.rawValue
    )
    indirect case aggregate(
        [LayoutPrimitives]
    )
}

extension LayoutPrimitives: ExpressibleByArrayLiteral {
    public init(arrayLiteral elements: LayoutPrimitives...) {
        self = .aggregate(elements)
    }
}

public extension LayoutPrimitives {
    fileprivate func getConstraints(for view: UIView) -> [NSLayoutConstraint] {
        var result = [NSLayoutConstraint]()
        getConstraintsRecursive(for: view, result: &result)
        return result
    }

    fileprivate func getConstraintsRecursive(for view: UIView, result: inout [NSLayoutConstraint]) {
        switch self {
        case let .relative(toView, attribute, relatedBy, to, multiplier, constant, priority):
            var relatedView: UIView? = toView

            if relatedView == nil {
                relatedView = view.superview
            }

            guard let relatedViewFinal = relatedView else { return }

            let constraint = NSLayoutConstraint(item: view, attribute: attribute, relatedBy: relatedBy, toItem: relatedViewFinal, attribute: to, multiplier: multiplier, constant: constant)
            constraint.priority = UILayoutPriority(rawValue: priority)
            result.append(constraint)
        case let .relativeToSibling(attribute, relatedBy, to, multiplier, constant, priority):
            guard let superview = view.superview else { return }

            var siblingFlag = false
            for v in superview.subviews.reversed() {
                if siblingFlag {
                    let constraint = NSLayoutConstraint(item: view, attribute: attribute, relatedBy: relatedBy, toItem: v, attribute: to, multiplier: multiplier, constant: constant)
                    constraint.priority = UILayoutPriority(rawValue: priority)
                    result.append(constraint)
                    break
                }

                if v == view {
                    siblingFlag = true
                }
            }
        case let .alignToSafeArea(top, right, bottom, left):
            guard let superview = view.superview else { return }

            let constraints: [NSLayoutConstraint] = [
                view.leadingAnchor.constraint(equalTo: superview.safeAreaLayoutGuide.leadingAnchor, constant: left),
                view.trailingAnchor.constraint(equalTo: superview.safeAreaLayoutGuide.trailingAnchor, constant: -right),
                view.topAnchor.constraint(equalTo: superview.safeAreaLayoutGuide.topAnchor, constant: top),
                view.bottomAnchor.constraint(equalTo: superview.bottomAnchor, constant: -bottom),
            ]
            result.append(contentsOf: constraints)
        case let .fixed(attribute, relatedBy, constant, priority):
            let constraint = NSLayoutConstraint(item: view, attribute: attribute, relatedBy: relatedBy, toItem: nil, attribute: .notAnAttribute, multiplier: 1, constant: constant)
            constraint.priority = UILayoutPriority(rawValue: priority)
            result.append(constraint)
        case let .ratio(multiplier, constant, priority):
            let constraint = NSLayoutConstraint(item: view, attribute: NSLayoutConstraint.Attribute.width, relatedBy: NSLayoutConstraint.Relation.equal, toItem: view, attribute: NSLayoutConstraint.Attribute.height, multiplier: multiplier, constant: constant)
            constraint.priority = UILayoutPriority(rawValue: priority)
            result.append(constraint)
        case let .aggregate(primitives):
            for primitive in primitives {
                primitive.getConstraintsRecursive(for: view, result: &result)
            }
        }
    }
}

public extension LayoutPrimitives {
    // When the view parameter is nil we consider relative to parent
    static func fill(to view: UIView? = nil, _ leftRightMargin: CGFloat = 0, _ topBottomMargin: CGFloat = 0, priority: LayoutPrimitivesPriority = .highest) -> LayoutPrimitives {
        return [
            .fillWidth(to: view, leftRightMargin, priority: priority),
            .fillHeight(to: view, topBottomMargin, priority: priority),
        ]
    }

    static func fillWidth(to view: UIView? = nil, _ leftRightMargin: CGFloat = 0, priority: LayoutPrimitivesPriority = .highest) -> LayoutPrimitives {
        return [
            .relative(toView: view, attribute: .centerY, to: .centerY, priority: LayoutPrimitivesPriority.lowest.rawValue), // center vertically with less priority
            .relative(toView: view, attribute: .leading, to: .leading, constant: leftRightMargin, priority: priority.rawValue),
            .relative(toView: view, attribute: .trailing, to: .trailing, constant: -leftRightMargin, priority: priority.rawValue),
        ]
    }

    static func fillHeight(to view: UIView? = nil, _ topBottomMargin: CGFloat = 0, priority: LayoutPrimitivesPriority = .highest) -> LayoutPrimitives {
        return [
            .relative(toView: view, attribute: .centerX, to: .centerX, priority: LayoutPrimitivesPriority.lowest.rawValue), // center horizontally with less priority
            .relative(toView: view, attribute: .top, to: .top, constant: topBottomMargin, priority: priority.rawValue),
            .relative(toView: view, attribute: .bottom, to: .bottom, constant: -topBottomMargin, priority: priority.rawValue),
        ]
    }

    static func fillWidthPercent(to view: UIView? = nil, _ multiplier: CGFloat, priority: LayoutPrimitivesPriority = .highest) -> LayoutPrimitives {
        return [
            .relative(toView: view, attribute: .centerY, to: .centerY, priority: LayoutPrimitivesPriority.lowest.rawValue), // center vertically with less priority
            .relative(toView: view, attribute: .width, to: .width, multiplier: multiplier, priority: priority.rawValue),
        ]
    }

    static func fillHeightPercent(to view: UIView? = nil, _ multiplier: CGFloat, priority: LayoutPrimitivesPriority = .highest) -> LayoutPrimitives {
        return [
            .relative(toView: view, attribute: .centerX, to: .centerX, priority: LayoutPrimitivesPriority.lowest.rawValue), // center horizontally with less priority
            .relative(toView: view, attribute: .height, to: .height, multiplier: multiplier, priority: priority.rawValue),
        ]
    }

    static func width(_ constant: CGFloat, priority: LayoutPrimitivesPriority = .highest) -> LayoutPrimitives {
        return .fixed(attribute: .width, constant: constant, priority: priority.rawValue)
    }

    static func height(_ constant: CGFloat, priority: LayoutPrimitivesPriority = .highest) -> LayoutPrimitives {
        return .fixed(attribute: .height, constant: constant, priority: priority.rawValue)
    }

    static func maxWidth(_ constant: CGFloat, priority: LayoutPrimitivesPriority = .highest) -> LayoutPrimitives {
        return .fixed(attribute: .width, relatedBy: .lessThanOrEqual, constant: constant, priority: priority.rawValue)
    }

    static func maxHeight(_ constant: CGFloat, priority: LayoutPrimitivesPriority = .highest) -> LayoutPrimitives {
        return .fixed(attribute: .height, relatedBy: .lessThanOrEqual, constant: constant, priority: priority.rawValue)
    }

    static func minWidth(_ constant: CGFloat, priority: LayoutPrimitivesPriority = .highest) -> LayoutPrimitives {
        return .fixed(attribute: .width, relatedBy: .greaterThanOrEqual, constant: constant, priority: priority.rawValue)
    }

    static func minHeight(_ constant: CGFloat, priority: LayoutPrimitivesPriority = .highest) -> LayoutPrimitives {
        return .fixed(attribute: .height, relatedBy: .greaterThanOrEqual, constant: constant, priority: priority.rawValue)
    }

    static func centerX(to view: UIView? = nil, _ constant: CGFloat = 0, priority: LayoutPrimitivesPriority = .highest) -> LayoutPrimitives {
        return .relative(toView: view, attribute: .centerX, to: .centerX, constant: constant, priority: priority.rawValue)
    }

    static func centerY(to view: UIView? = nil, _ constant: CGFloat = 0, priority: LayoutPrimitivesPriority = .highest) -> LayoutPrimitives {
        return .relative(toView: view, attribute: .centerY, to: .centerY, constant: constant, priority: priority.rawValue)
    }

    static func top(to view: UIView? = nil, _ constant: CGFloat = 0, priority: LayoutPrimitivesPriority = .highest) -> LayoutPrimitives {
        return .relative(toView: view, attribute: .top, to: .top, constant: constant, priority: priority.rawValue)
    }

    static func right(to view: UIView? = nil, _ constant: CGFloat = 0, priority: LayoutPrimitivesPriority = .highest) -> LayoutPrimitives {
        return .relative(toView: view, attribute: .trailing, to: .trailing, constant: -constant, priority: priority.rawValue)
    }

    static func bottom(to view: UIView? = nil, _ constant: CGFloat = 0, priority: LayoutPrimitivesPriority = .highest) -> LayoutPrimitives {
        return .relative(toView: view, attribute: .bottom, to: .bottom, constant: -constant, priority: priority.rawValue)
    }

    static func left(to view: UIView? = nil, _ constant: CGFloat = 0, priority: LayoutPrimitivesPriority = .highest) -> LayoutPrimitives {
        return .relative(toView: view, attribute: .leading, to: .leading, constant: constant, priority: priority.rawValue)
    }

    static func align(to view: UIView? = nil, top: CGFloat, right: CGFloat, bottom: CGFloat, left: CGFloat, priority: LayoutPrimitivesPriority = .highest) -> LayoutPrimitives {
        return [
            .relative(toView: view, attribute: .top, to: .top, constant: top, priority: priority.rawValue),
            .relative(toView: view, attribute: .trailing, to: .trailing, constant: right, priority: priority.rawValue),
            .relative(toView: view, attribute: .bottom, to: .bottom, constant: bottom, priority: priority.rawValue),
            .relative(toView: view, attribute: .leading, to: .leading, constant: left, priority: priority.rawValue),
        ]
    }

    static func below(_ view: UIView, _ constant: CGFloat = 0, priority: LayoutPrimitivesPriority = .highest) -> LayoutPrimitives {
        return .relative(toView: view, attribute: .top, to: .bottom, constant: constant, priority: priority.rawValue)
    }

    static func belowSibling(_ constant: CGFloat = 0, priority: LayoutPrimitivesPriority = .highest) -> LayoutPrimitives {
        return .relativeToSibling(attribute: .top, to: .bottom, constant: constant, priority: priority.rawValue)
    }

    static func nextTo(_ view: UIView, _ constant: CGFloat = 0, priority: LayoutPrimitivesPriority = .highest) -> LayoutPrimitives {
        return .relative(toView: view, attribute: .left, to: .right, constant: constant, priority: priority.rawValue)
    }

    static func nextToSibling(_ constant: CGFloat = 0, priority: LayoutPrimitivesPriority = .highest) -> LayoutPrimitives {
        return .relativeToSibling(attribute: .left, to: .right, constant: constant, priority: priority.rawValue)
    }

    static func above(_ view: UIView, _ constant: CGFloat = 0, priority: LayoutPrimitivesPriority = .highest) -> LayoutPrimitives {
        return .relative(toView: view, attribute: .bottom, to: .top, constant: -constant, priority: priority.rawValue)
    }

    static func behind(_ view: UIView, _ constant: CGFloat = 0, priority: LayoutPrimitivesPriority = .highest) -> LayoutPrimitives {
        return .relative(toView: view, attribute: .right, to: .left, constant: -constant, priority: priority.rawValue)
    }

    static func aspectRatio(_ width: CGFloat, _ height: CGFloat, priority: LayoutPrimitivesPriority = .highest) -> LayoutPrimitives {
        return .ratio(multiplier: width / height, priority: priority.rawValue)
    }
}

public extension UIView {
    private struct Holder {
        static let semaphore = DispatchSemaphore(value: 1)
        static var childPrimitives = [String: LayoutPrimitives]()
    }

    private var childPrimitives: LayoutPrimitives? {
        get {
            Holder.semaphore.wait()
            let primitives = Holder.childPrimitives[description]
            Holder.semaphore.signal()
            return primitives
        }
        set(newValue) {
            Holder.semaphore.wait()
            Holder.childPrimitives[description] = newValue
            Holder.semaphore.signal()
        }
    }

    @discardableResult
    func add<T>(_ subview: T, _ primitives: LayoutPrimitives, configure: ((T) -> Void)? = nil) -> (T, [NSLayoutConstraint]) where T: UIView {
        addSubview(subview)
        return apply(subview, primitives, configure: configure)
    }

    @discardableResult
    func addDefault<T>(_ subview: T, _ backgroundColor: UIColor = .clear, _ primitives: LayoutPrimitives = .fill(15, 0), configure: ((T) -> Void)? = nil) -> T where T: UIView {
        subview.backgroundColor = backgroundColor
        return add(subview, primitives, configure: configure).0
    }

    @discardableResult
    func addHStack(alignment: UIStackView.Alignment = .fill, distribution: UIStackView.Distribution = .fill, spacing: CGFloat = 0, _ primitives: LayoutPrimitives = [], configure: ((StackPv) -> Void)? = nil) -> StackPv {
        let subview = StackPv(axis: .horizontal, alignment: alignment, distribution: distribution, spacing: spacing)
        return add(subview, primitives, configure: configure).0
    }

    @discardableResult
    func addVStack(alignment: UIStackView.Alignment = .fill, distribution: UIStackView.Distribution = .fill, spacing: CGFloat = 0, _ primitives: LayoutPrimitives = [], configure: ((StackPv) -> Void)? = nil) -> StackPv {
        let subview = StackPv(axis: .vertical, alignment: alignment, distribution: distribution, spacing: spacing)
        return add(subview, primitives, configure: configure).0
    }

    @discardableResult
    func addChildren(_ subviews: UIView...) -> Self {
        for view in subviews {
            addSubview(view)
            view.applyChildPrimitives()
            view.childPrimitives = nil
        }
        return self
    }

    private func applyChildPrimitives() {
        guard let childPrimitives = childPrimitives else { return }
        apply(childPrimitives)
    }

    @discardableResult
    func configureChild(_ primitives: LayoutPrimitives...) -> Self {
        childPrimitives = .aggregate(primitives)
        return self
    }

    @discardableResult
    func apply(_ primitives: LayoutPrimitives...) -> Self {
        return apply(self, .aggregate(primitives), configure: nil).0
    }

    private func apply<T>(_ subview: T, _ primitives: LayoutPrimitives, configure: ((T) -> Void)? = nil) -> (T, [NSLayoutConstraint]) where T: UIView {
        subview.translatesAutoresizingMaskIntoConstraints = false
        let constraints: [NSLayoutConstraint] = primitives.getConstraints(for: subview)
        NSLayoutConstraint.activate(constraints)
        configure?(subview)
        return (subview, constraints)
    }
}

public class StackPv: UIStackView {
    required init(coder: NSCoder) {
        super.init(coder: coder)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
    }

    convenience init(axis: NSLayoutConstraint.Axis = .vertical, alignment: Alignment = .fill, distribution: Distribution = .fill, spacing: CGFloat = 0) {
        self.init(frame: .zero)
        self.axis = axis
        self.alignment = alignment
        self.distribution = distribution
        self.spacing = spacing
        backgroundColor = .clear
    }

    @discardableResult
    func add(_ views: UIView...) -> Self {
        for view in views {
            if let spacer = view as? SpacerPv {
                spacer.applySpacing(axis: axis)
            }
            addArrangedSubview(view)
        }
        return self
    }
}

public class VStackPv: StackPv {
    convenience init(alignment: Alignment = .fill, distribution: Distribution = .fill, spacing: CGFloat = 0) {
        self.init(axis: .vertical, alignment: alignment, distribution: distribution, spacing: spacing)
    }
}

public class HStackPv: StackPv {
    convenience init(alignment: Alignment = .fill, distribution: Distribution = .fill, spacing: CGFloat = 0) {
        self.init(axis: .horizontal, alignment: alignment, distribution: distribution, spacing: spacing)
    }
}

public class SpacerPv: UIView {
    var spacing: CGFloat?
    var min: CGFloat?
    var max: CGFloat?
    var priority: LayoutPrimitivesPriority = .highest

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
    }

    convenience init(_ spacing: CGFloat? = nil, min: CGFloat? = nil, max: CGFloat? = nil, priority: LayoutPrimitivesPriority = .highest) {
        self.init(frame: .zero)
        self.spacing = spacing
        self.min = min
        self.max = max
        self.priority = priority
        backgroundColor = .clear
    }

    @discardableResult
    func applySpacing(axis: NSLayoutConstraint.Axis = .vertical) -> Self {
        if let spacing = spacing {
            apply(axis == .vertical ? .height(spacing, priority: priority) : .width(spacing, priority: priority))
        }

        if let min = min {
            apply(axis == .vertical ? .minHeight(min, priority: priority) : .minWidth(min, priority: priority))
        }

        if let max = max {
            apply(axis == .vertical ? .maxHeight(max, priority: priority) : .maxWidth(max, priority: priority))
        }

        return self
    }
}

public class SpacerFilledPv: SpacerPv {
    convenience init(min: CGFloat = 1000000, priority: LayoutPrimitivesPriority = .lowest) {
        self.init(nil, min: min, max: nil, priority: priority)
    }
}
