//
//  LayoutPrimitives+RxSwift.swift
//
//  Created by Pedro Branco on 24/09/2020.
//  Copyright (c) 2020 Pedro Branco. All rights reserved.
//

import RxSwift
import UIKit

class LabelRx: LabelPv {
    convenience init(width: CGFloat? = nil, height: CGFloat? = nil, _ rxText: BehaviorSubject<String>, alignment: NSTextAlignment = .natural, font: UIFont = .preferredFont(forTextStyle: .body), lineBreak: NSLineBreakMode = .byWordWrapping, lines: Int = 0, color: UIColor = .black, disposedBy bag: DisposeBag, configure: ((LabelPv) -> Void)? = nil) {
        self.init(width: width, height: height, try! rxText.value(), alignment: alignment, font: font, lineBreak: lineBreak, lines: lines, color: color, configure: configure)

        rxText.bind { [weak self] text in
            self?.text = text
        }.disposed(by: bag)
    }
}
