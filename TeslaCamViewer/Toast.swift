//
//  Toast.swift
//  TeslaCamViewer
//
//  Created by Daniel Beard on 6/7/23.
//  Copyright © 2023 dbeard. All rights reserved.
//

import SwiftUI

enum ToastLayout: Equatable {
    case none
    case text(String)
    case image(Image)
    case textAndImage(String, Image)
}

struct Toast: View {

    @Binding var layout: ToastLayout

    var body: some View {
        VStack {
            switch layout {
                case .none:
                    EmptyView()
                case .text(let text):
                    Text(text)
                case .image(let image):
                    image
                        .font(.system(size: 100))
                        .foregroundStyle(.secondary)
                case .textAndImage(let text, let image):
                    Text(text)
                    image
                        .font(.system(size: 100))
                        .foregroundStyle(.regularMaterial)
            }
        }
        .opacity(layout == .none ? 0 : 1)
        .padding(16)
        .frame(minWidth: 100, minHeight: 100)
        .background(.ultraThinMaterial)
        .cornerRadius(10)

    }
}

struct Toast_Preview: PreviewProvider {
    static var previews: some View {
        VStack {
            Toast(layout: .constant(.none))
            Toast(layout: .constant(.image(Image(systemName: "play.circle"))))
        }
    }
}
