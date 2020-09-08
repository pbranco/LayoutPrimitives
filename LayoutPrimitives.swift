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
    case constrained(
        view1: UIView,
        attr1: NSLayoutConstraint.Attribute,
        relation: NSLayoutConstraint.Relation,
        view2: UIView,
        attr2: NSLayoutConstraint.Attribute,
        multiplier: CGFloat = 1,
        constant: CGFloat = 0,
        priority: LayoutPrimitivesPriority = .highest
    )
    case relative(
        toView: UIView?, // whenever toView is nil we consider relative to parent
        attr1: NSLayoutConstraint.Attribute,
        relation: NSLayoutConstraint.Relation = .equal,
        attr2: NSLayoutConstraint.Attribute,
        multiplier: CGFloat = 1,
        constant: CGFloat = 0,
        priority: LayoutPrimitivesPriority = .highest
    )
    case relativeToSibling(
        attr1: NSLayoutConstraint.Attribute,
        relation: NSLayoutConstraint.Relation = .equal,
        attr2: NSLayoutConstraint.Attribute,
        multiplier: CGFloat = 1,
        constant: CGFloat = 0,
        priority: LayoutPrimitivesPriority = .highest
    )
    case alignToSafeArea(
        top: CGFloat = 0,
        right: CGFloat = 0,
        bottom: CGFloat = 0,
        left: CGFloat = 0,
        priority: LayoutPrimitivesPriority = .highest
    )
    case fixed(
        attr: NSLayoutConstraint.Attribute,
        relation: NSLayoutConstraint.Relation = .equal,
        constant: CGFloat,
        priority: LayoutPrimitivesPriority = .highest
    )
    case ratio(
        multiplier: CGFloat,
        constant: CGFloat = 0,
        priority: LayoutPrimitivesPriority = .highest
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
        case let .constrained(view1, attr1, relation, view2, attr2, multiplier, constant, priority):
            let constraint = NSLayoutConstraint(item: view1, attribute: attr1, relatedBy: relation, toItem: view2, attribute: attr2, multiplier: multiplier, constant: constant)
            constraint.priority = UILayoutPriority(rawValue: priority.rawValue)
            result.append(constraint)
        case let .relative(toView, attr1, relation, attr2, multiplier, constant, priority):
            var relatedView: UIView? = toView

            if relatedView == nil {
                relatedView = view.superview
            }

            guard let relatedViewFinal = relatedView else { return }

            let constraint = NSLayoutConstraint(item: view, attribute: attr1, relatedBy: relation, toItem: relatedViewFinal, attribute: attr2, multiplier: multiplier, constant: constant)
            constraint.priority = UILayoutPriority(rawValue: priority.rawValue)
            result.append(constraint)
        case let .relativeToSibling(attr1, relation, attr2, multiplier, constant, priority):
            guard let superview = view.superview else { return }

            var siblingFlag = false
            for v in superview.subviews.reversed() {
                if siblingFlag {
                    let constraint = NSLayoutConstraint(item: view, attribute: attr1, relatedBy: relation, toItem: v, attribute: attr2, multiplier: multiplier, constant: constant)
                    constraint.priority = UILayoutPriority(rawValue: priority.rawValue)
                    result.append(constraint)
                    break
                }

                if v == view {
                    siblingFlag = true
                }
            }
        case let .alignToSafeArea(top, right, bottom, left, priority):
            guard let superview = view.superview else { return }

            let constraints: [NSLayoutConstraint] = [
                view.leadingAnchor.constraint(equalTo: superview.safeAreaLayoutGuide.leadingAnchor, constant: left),
                view.trailingAnchor.constraint(equalTo: superview.safeAreaLayoutGuide.trailingAnchor, constant: -right),
                view.topAnchor.constraint(equalTo: superview.safeAreaLayoutGuide.topAnchor, constant: top),
                view.bottomAnchor.constraint(equalTo: superview.safeAreaLayoutGuide.bottomAnchor, constant: -bottom),
            ]
            constraints.forEach { $0.priority = UILayoutPriority(rawValue: priority.rawValue) }
            result.append(contentsOf: constraints)
        case let .fixed(attr, relation, constant, priority):
            let constraint = NSLayoutConstraint(item: view, attribute: attr, relatedBy: relation, toItem: nil, attribute: .notAnAttribute, multiplier: 1, constant: constant)
            constraint.priority = UILayoutPriority(rawValue: priority.rawValue)
            result.append(constraint)
        case let .ratio(multiplier, constant, priority):
            let constraint = NSLayoutConstraint(item: view, attribute: NSLayoutConstraint.Attribute.width, relatedBy: NSLayoutConstraint.Relation.equal, toItem: view, attribute: NSLayoutConstraint.Attribute.height, multiplier: multiplier, constant: constant)
            constraint.priority = UILayoutPriority(rawValue: priority.rawValue)
            result.append(constraint)
        case let .aggregate(primitives):
            for primitive in primitives {
                primitive.getConstraintsRecursive(for: view, result: &result)
            }
        }
    }
}

public extension LayoutPrimitives {
    // Note: Whenever the view parameter is nil we consider relative to parent

    /// The 'fill' primitive is equivalent to the following constraints:
    ///    leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: leftRightMargin),
    ///    trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -leftRightMargin),
    ///    topAnchor.constraint(equalTo: view.topAnchor, constant: topBottomMargin),
    ///    bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -topBottomMargin)
    static func fill(to view: UIView? = nil, _ leftRightMargin: CGFloat = 0, _ topBottomMargin: CGFloat = 0, priority: LayoutPrimitivesPriority = .highest) -> LayoutPrimitives {
        return .align(to: view, top: topBottomMargin, right: leftRightMargin, bottom: topBottomMargin, left: leftRightMargin, priority: priority)
    }

    /// The 'fillWidth' primitive is equivalent to the following constraints:
    ///    leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: leftRightMargin),
    ///    trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -leftRightMargin)
    static func fillWidth(to view: UIView? = nil, _ leftRightMargin: CGFloat = 0, priority: LayoutPrimitivesPriority = .highest) -> LayoutPrimitives {
        return [
            .relative(toView: view, attr1: .leading, attr2: .leading, constant: leftRightMargin, priority: priority),
            .relative(toView: view, attr1: .trailing, attr2: .trailing, constant: -leftRightMargin, priority: priority),
        ]
    }

    /// The 'fillHeight' primitive is equivalent to the following constraints:
    ///    topAnchor.constraint(equalTo: view.topAnchor, constant: topBottomMargin),
    ///    bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -topBottomMargin)
    static func fillHeight(to view: UIView? = nil, _ topBottomMargin: CGFloat = 0, priority: LayoutPrimitivesPriority = .highest) -> LayoutPrimitives {
        return [
            .relative(toView: view, attr1: .top, attr2: .top, constant: topBottomMargin, priority: priority),
            .relative(toView: view, attr1: .bottom, attr2: .bottom, constant: -topBottomMargin, priority: priority),
        ]
    }

    /// The 'equalWidths' primitive is equivalent to the following constraint:
    ///    widthAnchor.constraint(equalTo: view.widthAnchor).multiplier = multiplier
    static func equalWidths(to view: UIView? = nil, _ multiplier: CGFloat = 1, priority: LayoutPrimitivesPriority = .highest) -> LayoutPrimitives {
        return .relative(toView: view, attr1: .width, attr2: .width, multiplier: multiplier, priority: priority)
    }

    /// The 'equalHeights' primitive is equivalent to the following constraint:
    ///    heightAnchor.constraint(equalTo: view.heightAnchor).multiplier = multiplier
    static func equalHeights(to view: UIView? = nil, _ multiplier: CGFloat = 1, priority: LayoutPrimitivesPriority = .highest) -> LayoutPrimitives {
        return .relative(toView: view, attr1: .height, attr2: .height, multiplier: multiplier, priority: priority)
    }

    /// The 'centerX' primitive is equivalent to the following constraint:
    ///    centerXAnchor.constraint(equalTo: view.centerXAnchor, constant: constant)
    static func centerX(to view: UIView? = nil, _ constant: CGFloat = 0, priority: LayoutPrimitivesPriority = .highest) -> LayoutPrimitives {
        return .relative(toView: view, attr1: .centerX, attr2: .centerX, constant: constant, priority: priority)
    }

    /// The 'centerY' primitive is equivalent to the following constraint:
    ///    centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: constant)
    static func centerY(to view: UIView? = nil, _ constant: CGFloat = 0, priority: LayoutPrimitivesPriority = .highest) -> LayoutPrimitives {
        return .relative(toView: view, attr1: .centerY, attr2: .centerY, constant: constant, priority: priority)
    }

    /// The 'top' primitive is equivalent to the following constraint:
    ///    topAnchor.constraint(equalTo: view.topAnchor, constant: constant)
    static func top(to view: UIView? = nil, _ constant: CGFloat = 0, priority: LayoutPrimitivesPriority = .highest) -> LayoutPrimitives {
        return .relative(toView: view, attr1: .top, attr2: .top, constant: constant, priority: priority)
    }

    /// The 'right' primitive is equivalent to the following constraint:
    ///    trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: constant)
    static func right(to view: UIView? = nil, _ constant: CGFloat = 0, priority: LayoutPrimitivesPriority = .highest) -> LayoutPrimitives {
        return .relative(toView: view, attr1: .trailing, attr2: .trailing, constant: -constant, priority: priority)
    }

    /// The 'bottom' primitive is equivalent to the following constraint:
    ///    bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: constant)
    static func bottom(to view: UIView? = nil, _ constant: CGFloat = 0, priority: LayoutPrimitivesPriority = .highest) -> LayoutPrimitives {
        return .relative(toView: view, attr1: .bottom, attr2: .bottom, constant: -constant, priority: priority)
    }

    /// The 'left' primitive is equivalent to the following constraint:
    ///    leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: constant)
    static func left(to view: UIView? = nil, _ constant: CGFloat = 0, priority: LayoutPrimitivesPriority = .highest) -> LayoutPrimitives {
        return .relative(toView: view, attr1: .leading, attr2: .leading, constant: constant, priority: priority)
    }

    /// The 'align' primitive is equivalent to the following constraints:
    ///    leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: left),
    ///    trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -right),
    ///    topAnchor.constraint(equalTo: view.topAnchor, constant: top),
    ///    bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -bottom)
    static func align(to view: UIView? = nil, top: CGFloat, right: CGFloat, bottom: CGFloat, left: CGFloat, priority: LayoutPrimitivesPriority = .highest) -> LayoutPrimitives {
        return [
            .relative(toView: view, attr1: .top, attr2: .top, constant: top, priority: priority),
            .relative(toView: view, attr1: .trailing, attr2: .trailing, constant: -right, priority: priority),
            .relative(toView: view, attr1: .bottom, attr2: .bottom, constant: -bottom, priority: priority),
            .relative(toView: view, attr1: .leading, attr2: .leading, constant: left, priority: priority),
        ]
    }

    /// The 'below' primitive is equivalent to the following constraint:
    ///    topAnchor.constraint(equalTo: view.bottomAnchor, constant: constant)
    static func below(_ view: UIView, _ constant: CGFloat = 0, priority: LayoutPrimitivesPriority = .highest) -> LayoutPrimitives {
        return .relative(toView: view, attr1: .top, attr2: .bottom, constant: constant, priority: priority)
    }

    /// The 'belowSibling' primitive is equivalent to the following constraint:
    ///    topAnchor.constraint(equalTo: siblingView.bottomAnchor, constant: constant) // where siblingView is the view just above the current view
    static func belowSibling(_ constant: CGFloat = 0, priority: LayoutPrimitivesPriority = .highest) -> LayoutPrimitives {
        return .relativeToSibling(attr1: .top, attr2: .bottom, constant: constant, priority: priority)
    }

    /// The 'nextTo' primitive is equivalent to the following constraint:
    ///    leadingAnchor.constraint(equalTo: view.trailingAnchor, constant: constant)
    static func nextTo(_ view: UIView, _ constant: CGFloat = 0, priority: LayoutPrimitivesPriority = .highest) -> LayoutPrimitives {
        return .relative(toView: view, attr1: .left, attr2: .right, constant: constant, priority: priority)
    }

    /// The 'nextToSibling' primitive is equivalent to the following constraint:
    ///    leadingAnchor.constraint(equalTo: siblingView.trailingAnchor, constant: constant) // where siblingView is the view just before to the current view
    static func nextToSibling(_ constant: CGFloat = 0, priority: LayoutPrimitivesPriority = .highest) -> LayoutPrimitives {
        return .relativeToSibling(attr1: .left, attr2: .right, constant: constant, priority: priority)
    }

    /// The 'above' primitive is equivalent to the following constraint:
    ///    bottomAnchor.constraint(equalTo: view.topAnchor, constant: -constant)
    static func above(_ view: UIView, _ constant: CGFloat = 0, priority: LayoutPrimitivesPriority = .highest) -> LayoutPrimitives {
        return .relative(toView: view, attr1: .bottom, attr2: .top, constant: -constant, priority: priority)
    }

    /// The 'behind' primitive is equivalent to the following constraint:
    ///    trailingAnchor.constraint(equalTo: view.leadingAnchor, constant: -constant)
    static func behind(_ view: UIView, _ constant: CGFloat = 0, priority: LayoutPrimitivesPriority = .highest) -> LayoutPrimitives {
        return .relative(toView: view, attr1: .right, attr2: .left, constant: -constant, priority: priority)
    }

    /// The 'width' primitive is equivalent to the following constraint:
    ///    widthAnchor.constraint(equalToConstant: constant)
    static func width(_ constant: CGFloat, priority: LayoutPrimitivesPriority = .highest) -> LayoutPrimitives {
        return .fixed(attr: .width, constant: constant, priority: priority)
    }

    /// The 'width(percent:)' primitive is equivalent to the following constraint:
    ///    widthAnchor.constraint(equalToConstant: UIScreen.main.bounds.width * percent)
    static func width(percent: CGFloat, priority: LayoutPrimitivesPriority = .highest) -> LayoutPrimitives {
        return .fixed(attr: .width, constant: UIScreen.main.bounds.width * percent, priority: priority)
    }

    /// The 'height' primitive is equivalent to the following constraint:
    ///    heightAnchor.constraint(equalToConstant: constant)
    static func height(_ constant: CGFloat, priority: LayoutPrimitivesPriority = .highest) -> LayoutPrimitives {
        return .fixed(attr: .height, constant: constant, priority: priority)
    }

    /// The 'height(percent:)' primitive is equivalent to the following constraint:
    ///    heightAnchor.constraint(equalToConstant: UIScreen.main.bounds.width * percent)
    static func height(percent: CGFloat, priority: LayoutPrimitivesPriority = .highest) -> LayoutPrimitives {
        return .fixed(attr: .height, constant: UIScreen.main.bounds.height * percent, priority: priority)
    }

    /// The 'maxWidth' primitive is equivalent to the following constraint:
    ///    widthAnchor.constraint(lessThanOrEqualToConstant: constant)
    static func maxWidth(_ constant: CGFloat, priority: LayoutPrimitivesPriority = .highest) -> LayoutPrimitives {
        return .fixed(attr: .width, relation: .lessThanOrEqual, constant: constant, priority: priority)
    }

    /// The 'maxWidth(percent:)' primitive is equivalent to the following constraint:
    ///    widthAnchor.constraint(lessThanOrEqualToConstant: UIScreen.main.bounds.width * percent)
    static func maxWidth(percent: CGFloat, priority: LayoutPrimitivesPriority = .highest) -> LayoutPrimitives {
        return .fixed(attr: .width, relation: .lessThanOrEqual, constant: UIScreen.main.bounds.width * percent, priority: priority)
    }

    /// The 'maxHeight' primitive is equivalent to the following constraint:
    ///    heightAnchor.constraint(lessThanOrEqualToConstant: constant)
    static func maxHeight(_ constant: CGFloat, priority: LayoutPrimitivesPriority = .highest) -> LayoutPrimitives {
        return .fixed(attr: .height, relation: .lessThanOrEqual, constant: constant, priority: priority)
    }

    /// The 'maxHeight(percent:)' primitive is equivalent to the following constraint:
    ///    heightAnchor.constraint(lessThanOrEqualToConstant: UIScreen.main.bounds.height * percent)
    static func maxHeight(percent: CGFloat, priority: LayoutPrimitivesPriority = .highest) -> LayoutPrimitives {
        return .fixed(attr: .height, relation: .lessThanOrEqual, constant: UIScreen.main.bounds.height * percent, priority: priority)
    }

    /// The 'minWidth' primitive is equivalent to the following constraint:
    ///    widthAnchor.constraint(greaterThanOrEqualToConstant: constant)
    static func minWidth(_ constant: CGFloat, priority: LayoutPrimitivesPriority = .highest) -> LayoutPrimitives {
        return .fixed(attr: .width, relation: .greaterThanOrEqual, constant: constant, priority: priority)
    }

    /// The 'minWidth(percent:)' primitive is equivalent to the following constraint:
    ///    widthAnchor.constraint(greaterThanOrEqualToConstant: UIScreen.main.bounds.width * percent)
    static func minWidth(percent: CGFloat, priority: LayoutPrimitivesPriority = .highest) -> LayoutPrimitives {
        return .fixed(attr: .width, relation: .greaterThanOrEqual, constant: UIScreen.main.bounds.width * percent, priority: priority)
    }

    /// The 'minHeight' primitive is equivalent to the following constraint:
    ///    heightAnchor.constraint(greaterThanOrEqualToConstant: constant)
    static func minHeight(_ constant: CGFloat, priority: LayoutPrimitivesPriority = .highest) -> LayoutPrimitives {
        return .fixed(attr: .height, relation: .greaterThanOrEqual, constant: constant, priority: priority)
    }

    /// The 'minHeight(percent:)' primitive is equivalent to the following constraint:
    ///    heightAnchor.constraint(greaterThanOrEqualToConstant: UIScreen.main.bounds.height * percent)
    static func minHeight(percent: CGFloat, priority: LayoutPrimitivesPriority = .highest) -> LayoutPrimitives {
        return .fixed(attr: .height, relation: .greaterThanOrEqual, constant: UIScreen.main.bounds.height * percent, priority: priority)
    }

    /// The 'aspectRatio' primitive is equivalent to the following constraint:
    ///    widthAnchor.constraint(equalTo: heightAnchor).multiplier = widthParcel / heightParcel
    static func aspectRatio(_ widthParcel: CGFloat, _ heightParcel: CGFloat, priority: LayoutPrimitivesPriority = .highest) -> LayoutPrimitives {
        return .ratio(multiplier: widthParcel / heightParcel, priority: priority)
    }
}

public struct ViewConstraints<T> {
    let view: T
    let constraints: [NSLayoutConstraint]
}

public class LayoutPrimitivesUtils {
    static func apply<T>(to view: T, _ primitives: LayoutPrimitives, configure: ((T) -> Void)? = nil) -> ViewConstraints<T> where T: UIView {
        view.translatesAutoresizingMaskIntoConstraints = false
        let constraints: [NSLayoutConstraint] = primitives.getConstraints(for: view)
        NSLayoutConstraint.activate(constraints)
        configure?(view)
        return ViewConstraints(view: view, constraints: constraints)
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
    func add<T>(_ subview: T, _ primitives: LayoutPrimitives, configure: ((T) -> Void)? = nil) -> T where T: UIView {
        addSubview(subview)
        return LayoutPrimitivesUtils.apply(to: subview, primitives, configure: configure).view
    }

    @discardableResult
    func addDefaultSubview(bg backgroundColor: UIColor = .clear, _ primitives: LayoutPrimitives = .fill(), configure: ((UIView) -> Void)? = nil) -> UIView {
        let subview = UIView()
        subview.backgroundColor = backgroundColor
        return add(subview, primitives, configure: configure)
    }

    @discardableResult
    func addHStack(bg backgroundColor: UIColor = .clear, scrollable: Bool = false, scrollDelegate: UIScrollViewDelegate? = nil, alignment: UIStackView.Alignment = .fill, distribution: UIStackView.Distribution = .fill, spacing: CGFloat = 0, _ primitives: LayoutPrimitives, configure: ((StackPv) -> Void)? = nil) -> StackPv {
        let stack = StackPv(axis: .horizontal, alignment: alignment, distribution: distribution, spacing: spacing)
        stack.backgroundColor = backgroundColor

        if scrollable {
            addHScrollContainer(scrollDelegate: scrollDelegate, .fill())
                .add(stack, primitives, configure: configure)
            return stack
        }

        return add(stack, primitives, configure: configure)
    }

    @discardableResult
    func addVStack(bg backgroundColor: UIColor = .clear, scrollable: Bool = false, scrollDelegate: UIScrollViewDelegate? = nil, alignment: UIStackView.Alignment = .fill, distribution: UIStackView.Distribution = .fill, spacing: CGFloat = 0, _ primitives: LayoutPrimitives, configure: ((StackPv) -> Void)? = nil) -> StackPv {
        let stack = StackPv(axis: .vertical, alignment: alignment, distribution: distribution, spacing: spacing)
        stack.backgroundColor = backgroundColor

        if scrollable {
            addVScrollContainer(scrollDelegate: scrollDelegate, .fill())
                .add(stack, primitives, configure: configure)
            return stack
        }

        return add(stack, primitives, configure: configure)
    }

    @discardableResult
    func addHScrollContainer<T>(_ container: T = UIView() as! T, bg backgroundColor: UIColor = .clear, scrollDelegate: UIScrollViewDelegate? = nil, _ primitives: LayoutPrimitives, configure: ((T) -> Void)? = nil) -> T where T: UIView {
        container.backgroundColor = backgroundColor
        let scroller = addScroller(.fill())
        scroller.delegate = scrollDelegate
        scroller.add(container, [primitives, .equalHeights()], configure: configure)
        return container
    }

    @discardableResult
    func addVScrollContainer<T>(_ container: T = UIView() as! T, bg backgroundColor: UIColor = .clear, scrollDelegate: UIScrollViewDelegate? = nil, _ primitives: LayoutPrimitives, configure: ((T) -> Void)? = nil) -> T where T: UIView {
        container.backgroundColor = backgroundColor
        let scroller = addScroller(.fill())
        scroller.delegate = scrollDelegate
        scroller.add(container, [primitives, .equalWidths()], configure: configure)
        return container
    }

    @discardableResult
    func addScroller(bg backgroundColor: UIColor = .clear, _ primitives: LayoutPrimitives, configure: ((UIScrollView) -> Void)? = nil) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.backgroundColor = backgroundColor
        add(scrollView, primitives, configure: configure)
        return scrollView
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
    func childWith(_ primitives: LayoutPrimitives...) -> Self {
        childPrimitives = .aggregate(primitives)
        return self
    }

    @discardableResult
    func insert<T>(_ subview: T, at index: Int, _ primitives: LayoutPrimitives, configure: ((T) -> Void)? = nil) -> T where T: UIView {
        insertSubview(subview, at: index)
        return LayoutPrimitivesUtils.apply(to: subview, primitives, configure: configure).view
    }

    @discardableResult
    func insert<T>(_ subview: T, above siblingSubview: UIView, _ primitives: LayoutPrimitives, configure: ((T) -> Void)? = nil) -> T where T: UIView {
        insertSubview(subview, aboveSubview: siblingSubview)
        return LayoutPrimitivesUtils.apply(to: subview, primitives, configure: configure).view
    }

    @discardableResult
    func insert<T>(_ subview: T, below siblingSubview: UIView, _ primitives: LayoutPrimitives, configure: ((T) -> Void)? = nil) -> T where T: UIView {
        insertSubview(subview, belowSubview: siblingSubview)
        return LayoutPrimitivesUtils.apply(to: subview, primitives, configure: configure).view
    }

    @discardableResult
    func apply(_ primitives: LayoutPrimitives...) -> Self {
        return LayoutPrimitivesUtils.apply(to: self, .aggregate(primitives), configure: nil).view
    }

    @discardableResult
    func applyConstraint(relativeTo relatedView: UIView, attr1: NSLayoutConstraint.Attribute, relation: NSLayoutConstraint.Relation, attr2: NSLayoutConstraint.Attribute, multiplier: CGFloat = 1, constant: CGFloat = 0, priority: LayoutPrimitivesPriority = .highest) -> NSLayoutConstraint {
        return LayoutPrimitivesUtils.apply(to: self, .constrained(view1: self, attr1: attr1, relation: relation, view2: relatedView, attr2: attr2, multiplier: multiplier, constant: constant, priority: priority), configure: nil).constraints[0]
    }
}

public class StackPv: UIStackView {
    required init(coder: NSCoder) {
        super.init(coder: coder)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
    }

    convenience init(axis: NSLayoutConstraint.Axis = .vertical, alignment: Alignment = .fill, distribution: Distribution = .fill, spacing: CGFloat = 0, bg backgroundColor: UIColor = .clear) {
        self.init(frame: .zero)
        self.axis = axis
        self.alignment = alignment
        self.distribution = distribution
        self.spacing = spacing
        self.backgroundColor = backgroundColor
    }

    @discardableResult
    func addArranged(_ views: UIView...) -> Self {
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
    convenience init(alignment: Alignment = .fill, distribution: Distribution = .fill, spacing: CGFloat = 0, bg backgroundColor: UIColor = .clear) {
        self.init(axis: .vertical, alignment: alignment, distribution: distribution, spacing: spacing, bg: backgroundColor)
    }
}

public class HStackPv: StackPv {
    convenience init(alignment: Alignment = .fill, distribution: Distribution = .fill, spacing: CGFloat = 0, bg backgroundColor: UIColor = .clear) {
        self.init(axis: .horizontal, alignment: alignment, distribution: distribution, spacing: spacing, bg: backgroundColor)
    }
}

public class SpacerPv: UIView {
    var spacing: CGFloat?
    var percent: CGFloat?
    var min: CGFloat?
    var max: CGFloat?
    var priority: LayoutPrimitivesPriority = .highest

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
    }

    convenience init(_ spacing: CGFloat? = nil, percent: CGFloat? = nil, min: CGFloat? = nil, max: CGFloat? = nil, bg backgroundColor: UIColor = .clear, priority: LayoutPrimitivesPriority = .highest) {
        self.init(frame: .zero)
        self.spacing = spacing
        self.percent = percent
        self.min = min
        self.max = max
        self.priority = priority
        self.backgroundColor = backgroundColor
    }

    @discardableResult
    func applySpacing(axis: NSLayoutConstraint.Axis = .vertical) -> Self {
        if let spacing = spacing {
            apply(axis == .vertical ? .height(spacing, priority: priority) : .width(spacing, priority: priority))
        }

        if let percent = percent {
            apply(axis == .vertical ? .height(UIScreen.main.bounds.height * percent, priority: priority) : .width(UIScreen.main.bounds.width * percent, priority: priority))
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
    convenience init(bg backgroundColor: UIColor = .clear, priority: LayoutPrimitivesPriority = .lowest) {
        self.init(nil, min: 1000000, max: nil, priority: priority)
    }
}

public class ViewPv: UIView {
    convenience init(bg backgroundColor: UIColor = .clear, _ primitives: LayoutPrimitives = []) {
        self.init()
        self.backgroundColor = backgroundColor
        apply(primitives)
    }
}

public class ImagePv: UIImageView {
    convenience init(_ named: String, contentMode: ContentMode = .scaleAspectFit, _ primitives: LayoutPrimitives = []) {
        self.init(image: UIImage(named: named))
        self.contentMode = contentMode
        setContentHuggingPriority(.required, for: .horizontal)
        setContentCompressionResistancePriority(.required, for: .vertical)
        apply(primitives)
    }
}

public class LabelPv: UILabel {
    convenience init(_ text: String, alignment: NSTextAlignment = .natural, font: UIFont = .preferredFont(forTextStyle: .body), color: UIColor = .black, lineBreak: NSLineBreakMode = .byWordWrapping, lines: Int = 0, _ primitives: LayoutPrimitives = []) {
        self.init()
        self.text = text
        textAlignment = alignment
        self.font = font
        textColor = color
        lineBreakMode = lineBreak
        numberOfLines = lines
        apply(primitives)
    }
}
