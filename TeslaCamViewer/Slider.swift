//
//  Slider.swift
//  TeslaCamViewer
//
//  Created by Daniel Beard on 5/27/23.
//  Copyright © 2023 dbeard. All rights reserved.
//

import Foundation
import SwiftUI

extension Double {
    func convert(fromRange: (Double, Double), toRange: (Double, Double)) -> Double {
        var value = self
        value -= fromRange.0
        value /= Double(fromRange.1 - fromRange.0)
        value *= toRange.1 - toRange.0
        value += toRange.0
        return value
    }
}

struct SliderParts {
    let barLeft: SliderModifier
    let knob: SliderModifier
    let barRight: SliderModifier
}
struct SliderModifier: ViewModifier {
    enum Name {
        case barLeft
        case knob
        case barRight
    }
    let name: Name
    let size: CGSize
    let offset: CGFloat

    func body(content: Content) -> some View {
        content
        .frame(width: size.width)
        .position(x: size.width * 0.5, y: size.height * 0.5)
        .offset(x: offset)
    }
}

struct CustomSlider<Component: View>: View {

    @Binding var value: Double
    var range: (Double, Double)
    var knobWidth: CGFloat?
    let viewBuilder: (SliderParts) -> Component

    init(value: Binding<Double>, range: (Double, Double), knobWidth: CGFloat? = nil,
         _ viewBuilder: @escaping (SliderParts) -> Component) {
        _value = value
        self.range = range
        self.viewBuilder = viewBuilder
        self.knobWidth = knobWidth
    }

    var body: some View {
      GeometryReader { geometry in
          let frame = geometry.frame(in: .global)
          let drag = DragGesture(minimumDistance: 0).onChanged({ drag in
            onDragChange(drag, frame) }
          )
          let offsetX = currentXOffsetFromValue(frame: frame)
          let knobSize = CGSize(width: knobWidth ?? frame.height, height: frame.height)
          let barLeftSize = CGSize(width: CGFloat(offsetX + knobSize.width * 0.5), height:  frame.height)
          let barRightSize = CGSize(width: frame.width - barLeftSize.width, height: frame.height)
          let modifiers = SliderParts(
              barLeft: SliderModifier(name: .barLeft, size: barLeftSize, offset: 0),
              knob: SliderModifier(name: .knob, size: knobSize, offset: offsetX),
              barRight: SliderModifier(name: .barRight, size: barRightSize, offset: barLeftSize.width))
          ZStack { viewBuilder(modifiers).gesture(drag) }
      }
    }

    private func onDragChange(_ drag: DragGesture.Value,_ frame: CGRect) {
        let frameWidth = frame.size.width
        let knobWidth = knobWidth ?? frameWidth
        let xrange = (min: Double(0), max: Double(frameWidth - knobWidth))
        var value = Double(drag.startLocation.x + drag.translation.width) - (0.5 * knobWidth)
        value = min(max(value, xrange.min), xrange.max)
        value = value.convert(fromRange: (xrange.min, xrange.max), toRange: range)
        self.value = value
    }

    private func currentXOffsetFromValue(frame: CGRect) -> CGFloat {
        let width = (knob: knobWidth ?? frame.size.height, view: frame.size.width)
        let xrange: (Double, Double) = (0, Double(width.view - width.knob))
        let result = self.value.convert(fromRange: range, toRange: xrange)
        return CGFloat(result)
    }
}
