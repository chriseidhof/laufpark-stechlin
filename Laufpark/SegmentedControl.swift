//
//  SegmentedControl.swift
//  Laufpark
//
//  Created by Chris Eidhof on 06.12.17.
//  Copyright © 2017 objc.io. All rights reserved.
//

import UIKit
import Incremental

enum HorizontalAlignment {
    case left
    case center
    case right
}

enum VerticalAlignment {
    case top
    case middle
    case bottom
}

extension CGSize {
    func align(horizontal: HorizontalAlignment = .left, vertical: VerticalAlignment = .top, in frame: CGRect) -> CGRect {
        var result = CGRect(origin: .zero, size: self)
        switch horizontal {
        case .left: result.origin.x = 0
        case .center: result.origin.x = (frame.size.width - width)/2
        case .right: result.origin.x = frame.size.width - width
        }
        switch vertical {
        case .top: result.origin.y = 0
        case .middle: result.origin.y = (frame.size.height - height)/2
        case .bottom: result.origin.y = frame.size.height - height
        }
        
        return result.integral
    }
}

extension CGRect {
    mutating func alignTo(horizontal: HorizontalAlignment, vertical: VerticalAlignment, of rect: CGRect) {
        self = size.align(horizontal: horizontal, vertical: vertical, in: rect)
    }
}


func segmentedControl(segments: I<[SegmentedControl.Segment]>, value: I<Int>, textColor: I<UIColor>, selectedTextColor: I<UIColor>, onChange: @escaping (Int) -> ()) -> IBox<SegmentedControl> {
    let c = IBox(SegmentedControl())
    c.bind(segments, to: \SegmentedControl.segments)
    c.bind(textColor, to: \.textColor)
    c.bind(selectedTextColor, to: \.selectedTextColor)
    c.observe(value: value) { (c, v) in
        c.selectedSegmentIndex = v
    }
    let ta = TargetAction { [unowned c] in
        onChange(c.unbox.selectedSegmentIndex!)
    }
    c.unbox.addTarget(ta, action: #selector(TargetAction.action(_:)), for: .valueChanged)
    c.disposables.append(ta)
    return c
}

final class SegmentView: UIView {
    var label: UILabel = UILabel()
    var imageView = UIImageView()
    var textColor: UIColor {
        get { return label.textColor }
        set {
            label.textColor = newValue
            imageView.tintColor = newValue
        }
    }
    var size: CGSize = .zero
    
    override var intrinsicContentSize: CGSize {
        return size
    }
}

func segment(_ image: UIImage, title: String, textColor: UIColor, size: CGSize) -> SegmentView {
    let view = SegmentView(frame: CGRect(x: 0, y: 0, width: size.width, height: size.height))
    view.size = size
    let imageView = view.imageView
    imageView.image = image
    let label = view.label
    label.text = title.uppercased()
    label.font = .preferredFont(forTextStyle: .caption1)
    label.textColor = textColor
    view.addSubview(imageView)
    view.addSubview(label)
    view.label = label
    
    imageView.frame = image.size.align(horizontal: .center, vertical: .top, in: view.frame)
    label.frame = label.intrinsicContentSize.align(horizontal: .center, vertical: .bottom, in: view.frame)
    return view
}

let segmentSize = CGSize(width: 46, height: 55)

public final class SegmentedControl: UIControl {
    public struct Segment: Equatable {
        let image: UIImage
        let title: String
        
        public static func ==(lhs: Segment, rhs: Segment) -> Bool {
            return lhs.image == rhs.image && lhs.title == rhs.title
        }
    }
    
    public var selectedSegmentIndex: Int? = nil {
        didSet {
            indicator.isHidden = selectedSegmentIndex == nil
            sendActions(for: .valueChanged)
        }
    }
    let indicatorSpacing: CGFloat = 3
    let indicatorHeight: CGFloat = 2
    let spacing: CGFloat = 20
    let animationDuration: TimeInterval = 0.2
    
    public var textColor: UIColor = .black {
        didSet {
            UIView.animate(withDuration: animationDuration) {
                for (index, label) in self.segmentLabels.enumerated() {
                    if index == self.selectedSegmentIndex { continue }
                    label.textColor = self.textColor
                }
            }
        }
    }
    
    var segmentLabels: [UILabel] {
        return subviews.dropLast().map { $0.subviews.flatMap { $0 as? UILabel }.first! }
    }
    
    public var selectedTextColor: UIColor = .white {
        didSet {
            UIView.animate(withDuration: animationDuration) {
                if let i = self.selectedSegmentIndex {
                    self.segmentLabels[i].textColor = self.selectedTextColor
                }
                self.indicator.backgroundColor = self.selectedTextColor
            }
        }
    }
    
    public var indicatorColor: UIColor {
        set {
            indicator.backgroundColor = newValue
        }
        get {
            return indicator.backgroundColor!
        }
    }
    private lazy var indicator: UIView = {
        let result = UIView()
        result.frame.size.height = indicatorHeight
        result.frame.size.width = segmentSize.width
        result.backgroundColor = selectedTextColor
        return result
    }()
    public var segments: [Segment] = [] {
        didSet {
            subviews.forEach { $0.removeFromSuperview() }
            for (i, s) in segments.enumerated() {
                let color = i == selectedSegmentIndex ? selectedTextColor : textColor
                addSubview(segment(s.image, title: s.title, textColor: color, size: segmentSize))
            }
            addSubview(indicator)
            
            invalidateIntrinsicContentSize()
        }
    }
    
    public override init(frame: CGRect) {
        super.init(frame: frame)
        
        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tapped(_:))))
    }
    
    @objc func tapped(_ sender: UITapGestureRecognizer) {
        let location = sender.location(in: self)
        guard let index = subviews.index(where: { $0.frame.contains(location) }) else { return } // todo should we compute this with math?
        selectedSegmentIndex = index
        let newX = leftForSegment(i: index)
        UIView.animate(withDuration: animationDuration) { [weak self] in
            self?.indicator.frame.origin.x = newX
        }
    }
    
    public required init?(coder aDecoder: NSCoder) {
        fatalError()
    }
    
    public override var intrinsicContentSize: CGSize {
        let count = CGFloat(segments.count)
        return CGSize(width: count * segmentSize.width + (count-1) * spacing,
                      height: segmentSize.height + indicatorSpacing + indicatorHeight)
    }
    
    func leftForSegment(i: Int) -> CGFloat {
        return CGFloat(i) * (spacing + segmentSize.width)
    }
    
    public override func layoutSubviews() {
        super.layoutSubviews()
        
        
        for i in 0..<subviews.count-1 { // minus the indicator
            subviews[i].frame.origin.y = 0
            subviews[i].frame.origin.x = leftForSegment(i: i)
        }
        
        if let i = selectedSegmentIndex {
            indicator.frame.alignTo(horizontal: .left, vertical: .bottom, of: bounds)
            indicator.frame.origin.x = leftForSegment(i: i)
        }
    }
}
