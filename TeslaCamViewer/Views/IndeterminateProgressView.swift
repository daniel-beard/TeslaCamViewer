//
//  IndeterminateProgressView.swift
//  TeslaCamViewer
//
//  Created by Daniel Beard on 7/28/19.
//  Copyright © 2019 dbeard. All rights reserved.
//

import Cocoa

#warning("Not working yet")
//TODO: This view doesn't work yet...

class IndeterminateProgressView: NSView {

    var progressView: NSProgressIndicator!
    var label: NSTextField!

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        progressView = NSProgressIndicator(frame: .zero)
        label = NSTextField(labelWithString: "Loading...")

        //TODO: Replace this with that franken-monster of a single layout func
        label.topAnchor.constraint(equalTo: self.topAnchor).isActive = true
        label.leftAnchor.constraint(equalTo: self.leftAnchor).isActive = true
        label.rightAnchor.constraint(equalTo: self.rightAnchor).isActive = true

    }

    required init?(coder decoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

}
