//
//  CanvasView.swift
//  MyBanBoard
//
//  Created by Mylun Jackson on 3/2/26.
//

import SwiftUI
import SwiftData
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

struct CanvasView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var board: Board

    @State private var dragTranslation: CGSize = .zero
    @State private var pinchScale: CGFloat = 1

    var body: some View {
        GeometryReader { proxy in
            let viewportSize = proxy.size

            ZStack {
                Color(platformBackgroundColor)
                    .ignoresSafeArea()

                CanvasGridView()
                    .frame(width: 5000, height: 5000)
                    .scaleEffect(effectiveScale, anchor: .center)
                    .offset(x: effectiveOffset.width, y: effectiveOffset.height)
            }
            .contentShape(Rectangle())
            .gesture(panGesture)
            .simultaneousGesture(zoomGesture)
            .overlay(alignment: .topTrailing) {
                Text("Zoom \(Int(effectiveScale * 100))%")
                    .font(.caption)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.thinMaterial, in: Capsule())
                    .padding()
            }
            .onDisappear {
                saveViewport()
            }
            .animation(.interactiveSpring(response: 0.2, dampingFraction: 0.85), value: dragTranslation)
            .onTapGesture(count: 2) {
                withAnimation {
                    board.viewportScale = 1
                    board.viewportOffsetX = 0
                    board.viewportOffsetY = 0
                    pinchScale = 1
                    dragTranslation = .zero
                }
                modelContext.saveWithLogging("CanvasView.resetViewport")
            }
            .overlay(alignment: .bottomTrailing) {
                Text("\(Int(viewportSize.width))x\(Int(viewportSize.height))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(8)
            }
        }
    }

    private var effectiveScale: CGFloat {
        max(0.5, min(2.5, CGFloat(board.viewportScale) * pinchScale))
    }

    private var effectiveOffset: CGSize {
        CGSize(
            width: board.viewportOffsetX + dragTranslation.width,
            height: board.viewportOffsetY + dragTranslation.height
        )
    }

    private var panGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                dragTranslation = value.translation
            }
            .onEnded { value in
                board.viewportOffsetX += value.translation.width
                board.viewportOffsetY += value.translation.height
                dragTranslation = .zero
                saveViewport()
            }
    }

    private var zoomGesture: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                pinchScale = value.magnification
            }
            .onEnded { value in
                board.viewportScale = max(0.5, min(2.5, board.viewportScale * value.magnification))
                pinchScale = 1
                saveViewport()
            }
    }

    private func saveViewport() {
        board.updatedAt = .now
        modelContext.saveWithLogging("CanvasView.saveViewport")
    }
}

private var platformBackgroundColor: Color {
#if os(iOS)
    return Color(uiColor: .systemBackground)
#elseif os(macOS)
    return Color(nsColor: .windowBackgroundColor)
#else
    return Color(.systemBackground)
#endif
}

private struct CanvasGridView: View {
    var body: some View {
        Canvas { context, size in
            let fineStep: CGFloat = 40
            let majorStep: CGFloat = 200

            for x in stride(from: 0, through: size.width, by: fineStep) {
                var path = Path()
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
                context.stroke(path, with: .color(.gray.opacity(0.12)), lineWidth: 1)
            }

            for y in stride(from: 0, through: size.height, by: fineStep) {
                var path = Path()
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                context.stroke(path, with: .color(.gray.opacity(0.12)), lineWidth: 1)
            }

            for x in stride(from: 0, through: size.width, by: majorStep) {
                var path = Path()
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
                context.stroke(path, with: .color(.gray.opacity(0.25)), lineWidth: 1.25)
            }

            for y in stride(from: 0, through: size.height, by: majorStep) {
                var path = Path()
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                context.stroke(path, with: .color(.gray.opacity(0.25)), lineWidth: 1.25)
            }
        }
    }
}
