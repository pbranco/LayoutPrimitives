//
//  LayoutPrimitives.swift
//
//
//  Created by Pedro Branco on 12/08/2020.
//
//

import UIKit

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
    case fixed(
        attribute: NSLayoutConstraint.Attribute,
        relatedBy: NSLayoutConstraint.Relation = .equal,
        constant: CGFloat,
        priority: Float = LayoutPrimitivesPriority.highest.rawValue
    )
    case aspectRatio(
        multiplier: CGFloat,
        constant: CGFloat = 0,
        priority: Float = LayoutPrimitivesPriority.highest.rawValue
    )
    indirect case aggregate(
        [LayoutPrimitives]
    )
}

public enum LayoutPrimitivesPriority: Float {
    case highest = 1000, high = 999, medium = 500, low = 2, lowest = 1
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
        case .fixed(let attribute, let relatedBy, let constant, let priority):
            let constraint = NSLayoutConstraint(item: view, attribute: attribute, relatedBy: relatedBy, toItem: nil, attribute: .notAnAttribute, multiplier: 1, constant: constant)
            constraint.priority = UILayoutPriority(rawValue: priority)
            result.append(constraint)
        case .aspectRatio(let multiplier, let constant, let priority):
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
    static func fillWidth(_ leftRightMargin: CGFloat = 0, to view: UIView? = nil, priority: LayoutPrimitivesPriority = .highest) -> LayoutPrimitives {
        return [
            .relative(toView: view, attribute: .centerY, to: .centerY, priority: LayoutPrimitivesPriority.lowest.rawValue), // center vertically with less priority
            .relative(toView: view, attribute: .leading, to: .leading, constant: leftRightMargin, priority: priority.rawValue),
            .relative(toView: view, attribute: .trailing, to: .trailing, constant: -leftRightMargin, priority: priority.rawValue),
        ]
    }
    
    static func fillHeight(_ topBottomMargin: CGFloat = 0, to view: UIView? = nil, priority: LayoutPrimitivesPriority = .highest) -> LayoutPrimitives {
        return [
            .relative(toView: view, attribute: .centerX, to: .centerX, priority: LayoutPrimitivesPriority.lowest.rawValue), // center horizontally with less priority
            .relative(toView: view, attribute: .top, to: .top, constant: topBottomMargin, priority: priority.rawValue),
            .relative(toView: view, attribute: .bottom, to: .bottom, constant: -topBottomMargin, priority: priority.rawValue),
        ]
    }
    
    static func fillWidthPercent(_ multiplier: CGFloat, to view: UIView? = nil, priority: LayoutPrimitivesPriority = .highest) -> LayoutPrimitives {
        return [
            .relative(toView: view, attribute: .centerY, to: .centerY, priority: 1), // center vertically with less priority
            .relative(toView: view, attribute: .width, to: .width, multiplier: multiplier, priority: priority.rawValue)
        ]
    }
    
    static func fillHeightPercent(_ multiplier: CGFloat, to view: UIView? = nil, priority: LayoutPrimitivesPriority = .highest) -> LayoutPrimitives {
        return [
            .relative(toView: view, attribute: .centerX, to: .centerX, priority: 1), // center horizontally with less priority
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
    
    static func centerHorizontally(_ constant: CGFloat = 0, to view: UIView? = nil, priority: LayoutPrimitivesPriority = .highest) -> LayoutPrimitives {
        return .relative(toView: view, attribute: .centerX, to: .centerX, constant: constant, priority: priority.rawValue)
    }
    
    static func centerVertically(_ constant: CGFloat = 0, to view: UIView? = nil, priority: LayoutPrimitivesPriority = .highest) -> LayoutPrimitives {
        return .relative(toView: view, attribute: .centerY, to: .centerY, constant: constant, priority: priority.rawValue)
    }
    
    static func top(_ constant: CGFloat = 0, to view: UIView? = nil, priority: LayoutPrimitivesPriority = .highest) -> LayoutPrimitives {
        return .relative(toView: view, attribute: .top, to: .top, constant: constant, priority: priority.rawValue)
    }
    
    static func right(_ constant: CGFloat = 0, to view: UIView? = nil, priority: LayoutPrimitivesPriority = .highest) -> LayoutPrimitives {
        return .relative(toView: view, attribute: .trailing, to: .trailing, constant: -constant, priority: priority.rawValue)
    }
    
    static func bottom(_ constant: CGFloat = 0, to view: UIView? = nil, priority: LayoutPrimitivesPriority = .highest) -> LayoutPrimitives {
        return .relative(toView: view, attribute: .bottom, to: .bottom, constant: -constant, priority: priority.rawValue)
    }
    
    static func left(_ constant: CGFloat = 0, to view: UIView? = nil, priority: LayoutPrimitivesPriority = .highest) -> LayoutPrimitives {
        return .relative(toView: view, attribute: .leading, to: .leading, constant: constant, priority: priority.rawValue)
    }
    
    static func align(_ top: CGFloat, _ right: CGFloat, _ bottom: CGFloat, _ left: CGFloat, to view: UIView? = nil, priority: LayoutPrimitivesPriority = .highest) -> LayoutPrimitives {
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
    
    static func ratio(_ multiplier: CGFloat, priority: LayoutPrimitivesPriority = .highest) -> LayoutPrimitives {
        return .aspectRatio(multiplier: multiplier, priority: priority.rawValue)
    }
}

public extension UIView {
    @discardableResult
    func add<T>(_ subview: T, _ primitives: LayoutPrimitives, configure: ((T, [NSLayoutConstraint]) -> Void)? = nil) -> T where T: UIView {
        subview.translatesAutoresizingMaskIntoConstraints = false
        addSubview(subview)
        let constraints: [NSLayoutConstraint] = primitives.getConstraints(for: subview)
        NSLayoutConstraint.activate(constraints)
        configure?(subview, constraints)
        return subview
    }
}
