//
//  LayoutPrimitives.swift
//
//
//  Created by Pedro Branco on 12/08/2020.
//
//

import UIKit

public enum LayoutPrimitivesPriority: Float {
    case highest = 1000, high = 999, medium = 500, low = 2, lowest = 1
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
        case .relative(let toView, let attribute, let relatedBy, let to, let multiplier, let constant, let priority):
            var relatedView: UIView? = toView
            
            if relatedView == nil {
                relatedView = view.superview
            }
            
            guard let relatedViewFinal = relatedView else { return }
            
            let constraint = NSLayoutConstraint(item: view, attribute: attribute, relatedBy: relatedBy, toItem: relatedViewFinal, attribute: to, multiplier: multiplier, constant: constant)
            constraint.priority = UILayoutPriority(rawValue: priority)
            result.append(constraint)
        case .relativeToSibling(let attribute, let relatedBy, let to, let multiplier, let constant, let priority):
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
        case .alignToSafeArea(let top, let right, let bottom, let left):
            guard let superview = view.superview else { return }
            
            let constraints: [NSLayoutConstraint] = [
                view.leadingAnchor.constraint(equalTo: superview.safeAreaLayoutGuide.leadingAnchor, constant: left),
                view.trailingAnchor.constraint(equalTo: superview.safeAreaLayoutGuide.trailingAnchor, constant: -right),
                view.topAnchor.constraint(equalTo: superview.safeAreaLayoutGuide.topAnchor, constant: top),
                view.bottomAnchor.constraint(equalTo: superview.bottomAnchor, constant: -bottom),
            ]
            result.append(contentsOf: constraints)
        case .fixed(let attribute, let relatedBy, let constant, let priority):
            let constraint = NSLayoutConstraint(item: view, attribute: attribute, relatedBy: relatedBy, toItem: nil, attribute: .notAnAttribute, multiplier: 1, constant: constant)
            constraint.priority = UILayoutPriority(rawValue: priority)
            result.append(constraint)
        case .ratio(let multiplier, let constant, let priority):
            let constraint = NSLayoutConstraint(item: view, attribute: NSLayoutConstraint.Attribute.height, relatedBy: NSLayoutConstraint.Relation.equal, toItem: view, attribute: NSLayoutConstraint.Attribute.width, multiplier: multiplier, constant: constant)
            constraint.priority = UILayoutPriority(rawValue: priority)
            result.append(constraint)
        case .aggregate(let pins):
            for pin in pins {
                pin.getConstraintsRecursive(for: view, result: &result)
            }
        }
    }
}

public extension LayoutPrimitives {
    // When toView is nil we consider relative to parent
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
            .relative(toView: view, attribute: .width, to: .width, multiplier: multiplier, priority: priority.rawValue)
        ]
    }
    
    static func fillHeightPercent(to view: UIView? = nil, _ multiplier: CGFloat, priority: LayoutPrimitivesPriority = .highest) -> LayoutPrimitives {
        return [
            .relative(toView: view, attribute: .centerX, to: .centerX, priority: LayoutPrimitivesPriority.lowest.rawValue), // center horizontally with less priority
            .relative(toView: view, attribute: .height, to: .height, multiplier: multiplier, priority: priority.rawValue)
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
    
    static func centerHorizontally(to view: UIView? = nil, _ constant: CGFloat = 0, priority: LayoutPrimitivesPriority = .highest) -> LayoutPrimitives {
        return .relative(toView: view, attribute: .centerX, to: .centerX, constant: constant, priority: priority.rawValue)
    }
    
    static func centerVertically(to view: UIView? = nil, _ constant: CGFloat = 0, priority: LayoutPrimitivesPriority = .highest) -> LayoutPrimitives {
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
    
    static func align(to view: UIView? = nil, _ top: CGFloat, _ right: CGFloat, _ bottom: CGFloat, _ left: CGFloat, priority: LayoutPrimitivesPriority = .highest) -> LayoutPrimitives {
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
    
    static func aspectRatio(_ multiplier: CGFloat, priority: LayoutPrimitivesPriority = .highest) -> LayoutPrimitives {
        return .ratio(multiplier: multiplier, priority: priority.rawValue)
    }
    
    static func keepAspectRatio(priority: LayoutPrimitivesPriority = .highest) -> LayoutPrimitives {
        return .ratio(multiplier: 1, priority: priority.rawValue)
    }
}

public extension UIView {
    @discardableResult
    func add<T>(_ subview: T, _ primitives: LayoutPrimitives, configure: ((T) -> Void)? = nil) -> (T, [NSLayoutConstraint]) where T: UIView {
        subview.translatesAutoresizingMaskIntoConstraints = false
        addSubview(subview)
        let constraints: [NSLayoutConstraint] = primitives.getConstraints(for: subview)
        NSLayoutConstraint.activate(constraints)
        configure?(subview)
        return (subview, constraints)
    }
}
