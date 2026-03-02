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

    private let surfaceSize: CGFloat = 5000

    var body: some View {
        GeometryReader { proxy in
            let viewportSize = proxy.size

            ZStack {
                Color(platformBackgroundColor)
                    .ignoresSafeArea()

                ZStack {
                    CanvasGridView()
                        .frame(width: surfaceSize, height: surfaceSize)

                    ForEach(canvasCards) { card in
                        CanvasCardView(
                            card: card,
                            zoomScale: effectiveScale,
                            onCommit: saveCardMutation
                        )
                        .position(
                            x: surfaceSize / 2 + CGFloat(card.x),
                            y: surfaceSize / 2 + CGFloat(card.y)
                        )
                    }
                }
                .frame(width: surfaceSize, height: surfaceSize)
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

    private var canvasCards: [Card] {
        board.cards
            .filter { $0.kanbanColumn == nil }
            .sorted { $0.title.localizedCompare($1.title) == .orderedAscending }
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

    private func saveCardMutation() {
        board.updatedAt = .now
        modelContext.saveWithLogging("CanvasView.cardMutation")
    }
}

private struct CanvasCardView: View {
    @Bindable var card: Card
    let zoomScale: CGFloat
    let onCommit: () -> Void

    @State private var dragTranslation: CGSize = .zero
    @State private var resizeTranslation: CGSize = .zero

    private let minWidth: CGFloat = 180
    private let minHeight: CGFloat = 120

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(card.title)
                .font(.headline)
                .lineLimit(1)

            if !card.content.isEmpty {
                Text(card.content)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(4)
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(width: effectiveWidth, height: effectiveHeight, alignment: .topLeading)
        .background(.thickMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(alignment: .bottomTrailing) {
            Circle()
                .fill(.tint)
                .frame(width: 14, height: 14)
                .padding(8)
                .gesture(resizeGesture)
        }
        .shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: 4)
        .offset(dragTranslation)
        .gesture(moveGesture)
    }

    private var effectiveWidth: CGFloat {
        max(minWidth, CGFloat(card.width) + resizeTranslation.width / max(zoomScale, 0.5))
    }

    private var effectiveHeight: CGFloat {
        max(minHeight, CGFloat(card.height) + resizeTranslation.height / max(zoomScale, 0.5))
    }

    private var moveGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                dragTranslation = value.translation
            }
            .onEnded { value in
                card.x += value.translation.width / max(zoomScale, 0.5)
                card.y += value.translation.height / max(zoomScale, 0.5)
                dragTranslation = .zero
                onCommit()
            }
    }

    private var resizeGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                resizeTranslation = value.translation
            }
            .onEnded { value in
                card.width = Double(effectiveWidth)
                card.height = Double(effectiveHeight)
                resizeTranslation = .zero
                onCommit()
            }
    }
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

private var platformBackgroundColor: Color {
#if os(iOS)
    return Color(uiColor: .systemBackground)
#elseif os(macOS)
    return Color(nsColor: .windowBackgroundColor)
#else
    return Color(.systemBackground)
#endif
}
