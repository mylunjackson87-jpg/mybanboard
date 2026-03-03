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
import CoreGraphics
#endif

private enum CanvasPointerMode {
    case idle
    case panning
    case lasso
}

struct CanvasView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.undoManager) private var undoManager
    @Bindable var board: Board
    var isDrawingMode: Bool
    var isSnapEnabled: Bool

    @State private var dragTranslation: CGSize = .zero
    @State private var pinchScale: CGFloat = 1

    @State private var selectedCardIDs = Set<UUID>()
    @State private var groupDragCardIDs = Set<UUID>()
    @State private var groupDragTranslation: CGSize = .zero

    @State private var pointerMode: CanvasPointerMode = .idle
    @State private var lassoStartPoint: CGPoint?
    @State private var lassoCurrentPoint: CGPoint?
    @State private var lassoBaseSelection = Set<UUID>()

    @State private var showDeleteSelectionConfirmation = false

    private let surfaceSize: CGFloat = 5000
    private let gridSnapStep: Double = 40

    var body: some View {
        GeometryReader { proxy in
            let viewportSize = proxy.size

            ZStack {
                Color(platformBackgroundColor)
                    .ignoresSafeArea()

                ZStack {
                    CanvasGridView()
                        .frame(width: surfaceSize, height: surfaceSize)

                    DrawingOverlayView(
                        drawingData: $board.drawingData,
                        isEnabled: isDrawingMode,
                        onSave: saveDrawing
                    )
                    .frame(width: surfaceSize, height: surfaceSize)

                    ForEach(canvasCards) { card in
                        CanvasCardView(
                            card: card,
                            zoomScale: effectiveScale,
                            isSelected: selectedCardIDs.contains(card.id),
                            groupDragOffset: groupDragOffset(for: card.id),
                            usesGroupDrag: selectedCardIDs.count > 1 && selectedCardIDs.contains(card.id),
                            onSelect: { selectCard(card.id) },
                            onToggleSelection: { toggleCardSelection(card.id) },
                            onFrameCommit: registerCardFrameChange,
                            onTextCommit: registerCardTextChange,
                            onGroupMoveChanged: handleGroupMoveChanged,
                            onGroupMoveEnded: handleGroupMoveEnded,
                            onDelete: { deleteCard(card) },
                            onSendToKanban: { sendCardToKanban(card) }
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

                if let lassoRect {
                    Rectangle()
                        .fill(Color.accentColor.opacity(0.12))
                        .overlay {
                            Rectangle()
                                .stroke(style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                                .foregroundStyle(Color.accentColor)
                        }
                        .frame(width: lassoRect.width, height: lassoRect.height)
                        .position(x: lassoRect.midX, y: lassoRect.midY)
                        .allowsHitTesting(false)
                }
            }
            .contentShape(Rectangle())
            .gesture(panGesture)
            .simultaneousGesture(zoomGesture)
#if os(iOS)
            .simultaneousGesture(iPadLassoGesture)
#endif
            .alert(deleteSelectionTitle, isPresented: $showDeleteSelectionConfirmation) {
                Button("Delete", role: .destructive) {
                    deleteSelectedCards()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This action cannot be undone from the deletion prompt. You can still use Undo after deletion.")
            }
            .background(deleteSelectionShortcutButton)
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
                clearTransientInteractionState(keepSelection: false)
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
                clearTransientInteractionState(keepSelection: true)
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

    private var undoService: UndoService? {
        guard let undoManager else { return nil }
        return UndoService(modelContext: modelContext, undoManager: undoManager)
    }

    private var effectiveOffset: CGSize {
        CGSize(
            width: board.viewportOffsetX + dragTranslation.width,
            height: board.viewportOffsetY + dragTranslation.height
        )
    }

    private var lassoRect: CGRect? {
        guard let lassoStartPoint, let lassoCurrentPoint else { return nil }
        return CGRect(
            x: min(lassoStartPoint.x, lassoCurrentPoint.x),
            y: min(lassoStartPoint.y, lassoCurrentPoint.y),
            width: abs(lassoCurrentPoint.x - lassoStartPoint.x),
            height: abs(lassoCurrentPoint.y - lassoStartPoint.y)
        )
    }

    private var deleteSelectionTitle: String {
        let suffix = selectedCardIDs.count == 1 ? "" : "s"
        return "Delete \(selectedCardIDs.count) Selected Card\(suffix)?"
    }

    private var deleteSelectionShortcutButton: some View {
        Button("Delete Selected") {
            guard !selectedCardIDs.isEmpty else { return }
            showDeleteSelectionConfirmation = true
        }
        .keyboardShortcut(.delete, modifiers: [])
        .disabled(selectedCardIDs.isEmpty)
        .opacity(0)
        .frame(width: 0, height: 0)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var panGesture: some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { value in
                if pointerMode == .lasso {
                    updateLassoSelection(current: value.location, additive: true)
                    return
                }

                if shouldStartMacLasso(from: value.startLocation) {
                    if pointerMode != .lasso {
                        beginLasso(at: value.startLocation, additive: true)
                    }
                    updateLassoSelection(current: value.location, additive: true)
                    return
                }

                pointerMode = .panning
                dragTranslation = value.translation
            }
            .onEnded { value in
                if pointerMode == .lasso {
                    finishLasso()
                    return
                }

                if pointerMode == .panning {
                    board.viewportOffsetX += value.translation.width
                    board.viewportOffsetY += value.translation.height
                    dragTranslation = .zero
                    pointerMode = .idle
                    saveViewport()
                } else {
                    dragTranslation = .zero
                }
            }
    }

#if os(iOS)
    private var iPadLassoGesture: some Gesture {
        LongPressGesture(minimumDuration: 0.35)
            .sequenced(before: DragGesture(minimumDistance: 0))
            .onChanged { value in
                guard case .second(true, let dragValue?) = value else { return }
                guard !isPointOverCard(dragValue.startLocation) else { return }

                if pointerMode != .lasso {
                    beginLasso(at: dragValue.startLocation, additive: false)
                }
                updateLassoSelection(current: dragValue.location, additive: false)
            }
            .onEnded { _ in
                if pointerMode == .lasso {
                    finishLasso()
                }
            }
    }
#endif

    private var zoomGesture: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                pinchScale = value.magnification
            }
            .onEnded { value in
                board.viewportScale = max(0.5, min(2.5, board.viewportScale * value.magnification))
                pinchScale = 1
                clearTransientInteractionState(keepSelection: true)
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

    private func saveDrawing() {
        board.updatedAt = .now
        modelContext.saveWithLogging("CanvasView.saveDrawing")
    }

    private func groupDragOffset(for cardID: UUID) -> CGSize {
        groupDragCardIDs.contains(cardID) ? groupDragTranslation : .zero
    }

    private func selectCard(_ cardID: UUID) {
#if os(macOS)
        if isShiftSelectionModifierActive {
            toggleCardSelection(cardID)
            return
        }
#endif
        selectedCardIDs = [cardID]
    }

    private func toggleCardSelection(_ cardID: UUID) {
        if selectedCardIDs.contains(cardID) {
            selectedCardIDs.remove(cardID)
        } else {
            selectedCardIDs.insert(cardID)
        }
    }

    private func shouldStartMacLasso(from startLocation: CGPoint) -> Bool {
#if os(macOS)
        isShiftSelectionModifierActive && !isPointOverCard(startLocation)
#else
        false
#endif
    }

#if os(macOS)
    private var isShiftSelectionModifierActive: Bool {
        CGEventSource.flagsState(.combinedSessionState).contains(.maskShift)
    }
#endif

    private func beginLasso(at start: CGPoint, additive: Bool) {
        pointerMode = .lasso
        lassoStartPoint = start
        lassoCurrentPoint = start
        lassoBaseSelection = additive ? selectedCardIDs : []
        if !additive {
            selectedCardIDs.removeAll()
        }
        dragTranslation = .zero
    }

    private func updateLassoSelection(current: CGPoint, additive: Bool) {
        lassoCurrentPoint = current
        guard let lassoRect else { return }

        let hitIDs = Set(
            canvasCards
                .filter { lassoRect.intersects(cardFrameInViewport($0)) }
                .map(\.id)
        )

        if additive {
            selectedCardIDs = lassoBaseSelection.union(hitIDs)
        } else {
            selectedCardIDs = hitIDs
        }
    }

    private func finishLasso() {
        pointerMode = .idle
        lassoStartPoint = nil
        lassoCurrentPoint = nil
        lassoBaseSelection.removeAll()
        dragTranslation = .zero
    }

    private func clearTransientInteractionState(keepSelection: Bool) {
        pointerMode = .idle
        lassoStartPoint = nil
        lassoCurrentPoint = nil
        lassoBaseSelection.removeAll()
        groupDragCardIDs.removeAll()
        groupDragTranslation = .zero
        dragTranslation = .zero
        if !keepSelection {
            selectedCardIDs.removeAll()
        }
    }

    private func isPointOverCard(_ point: CGPoint) -> Bool {
        canvasCards.contains { cardFrameInViewport($0).contains(point) }
    }

    private func cardFrameInViewport(_ card: Card) -> CGRect {
        let width = CGFloat(card.width) * effectiveScale
        let height = CGFloat(card.height) * effectiveScale
        let centerX = (surfaceSize / 2 + CGFloat(card.x)) * effectiveScale + effectiveOffset.width
        let centerY = (surfaceSize / 2 + CGFloat(card.y)) * effectiveScale + effectiveOffset.height

        return CGRect(
            x: centerX - (width / 2),
            y: centerY - (height / 2),
            width: width,
            height: height
        )
    }

    private func handleGroupMoveChanged(cardID: UUID, translation: CGSize) {
        guard selectedCardIDs.count > 1, selectedCardIDs.contains(cardID) else { return }
        if groupDragCardIDs.isEmpty {
            groupDragCardIDs = selectedCardIDs
        }
        groupDragTranslation = translation
    }

    private func handleGroupMoveEnded(cardID: UUID, translation: CGSize) {
        guard selectedCardIDs.count > 1, selectedCardIDs.contains(cardID) else { return }
        let movingIDs = groupDragCardIDs.isEmpty ? selectedCardIDs : groupDragCardIDs
        guard !movingIDs.isEmpty else { return }

        let scale = max(effectiveScale, 0.5)
        let deltaX = Double(translation.width / scale)
        let deltaY = Double(translation.height / scale)

        var changes: [CardFrameChange] = []
        for card in canvasCards where movingIDs.contains(card.id) {
            let before = CardFrameSnapshot(x: card.x, y: card.y, width: card.width, height: card.height)
            let movedX = card.x + deltaX
            let movedY = card.y + deltaY
            if isSnapEnabled {
                card.x = snappedCoordinate(movedX)
                card.y = snappedCoordinate(movedY)
            } else {
                card.x = movedX
                card.y = movedY
            }
            let after = CardFrameSnapshot(x: card.x, y: card.y, width: card.width, height: card.height)
            changes.append(CardFrameChange(cardID: card.id, from: before, to: after))
        }

        groupDragCardIDs.removeAll()
        groupDragTranslation = .zero

        guard !changes.isEmpty else { return }
        saveCardMutation()
        undoService?.registerCardFrameBatchChange(actionName: "Move Cards", changes: changes)
    }

    private func sendCardToKanban(_ card: Card) {
        let beforeOrder = board.cards.map(CardOrderSnapshot.init(card:))
        let column: Column
        if let firstColumn = board.columns.sorted(by: { $0.order < $1.order }).first {
            column = firstColumn
        } else {
            let newColumn = Column(board: board, title: "Inbox", order: 0)
            modelContext.insert(newColumn)
            column = newColumn
        }

        let existing = board.cards.filter { $0.kanbanColumn?.id == column.id }
        card.kanbanColumn = column
        card.orderInColumn = existing.count
        selectedCardIDs.remove(card.id)
        board.updatedAt = .now
        modelContext.saveWithLogging("CanvasView.sendCardToKanban")
        let afterOrder = board.cards.map(CardOrderSnapshot.init(card:))
        undoService?.registerCardOrderChange(
            actionName: "Send to Kanban",
            before: beforeOrder,
            after: afterOrder,
            boardID: board.id
        )
    }

    private func deleteCard(_ card: Card) {
        let snapshot = CardSnapshot(card: card)
        selectedCardIDs.remove(card.id)
        modelContext.delete(card)
        board.updatedAt = .now
        modelContext.saveWithLogging("CanvasView.deleteCard")
        undoService?.registerCardDeleted(snapshot)
    }

    private func deleteSelectedCards() {
        let cardsToDelete = canvasCards.filter { selectedCardIDs.contains($0.id) }
        guard !cardsToDelete.isEmpty else { return }

        let snapshots = cardsToDelete.map(CardSnapshot.init(card:))
        for card in cardsToDelete {
            modelContext.delete(card)
        }

        selectedCardIDs.removeAll()
        board.updatedAt = .now
        modelContext.saveWithLogging("CanvasView.deleteSelectedCards")

        for snapshot in snapshots {
            undoService?.registerCardDeleted(snapshot)
        }
    }

    private func registerCardFrameChange(cardID: UUID, before: CardFrameSnapshot, after: CardFrameSnapshot) {
        let moved = before.x != after.x || before.y != after.y
        let resized = before.width != after.width || before.height != after.height

        let committedAfter: CardFrameSnapshot
        if isSnapEnabled, moved, !resized {
            committedAfter = CardFrameSnapshot(
                x: snappedCoordinate(after.x),
                y: snappedCoordinate(after.y),
                width: after.width,
                height: after.height
            )
            if let card = canvasCards.first(where: { $0.id == cardID }) {
                card.x = committedAfter.x
                card.y = committedAfter.y
            }
        } else {
            committedAfter = after
        }

        guard before.x != committedAfter.x || before.y != committedAfter.y || before.width != committedAfter.width || before.height != committedAfter.height else {
            return
        }
        saveCardMutation()
        undoService?.registerCardFrameChange(cardID: cardID, from: before, to: committedAfter)
    }

    private func registerCardTextChange(cardID: UUID, before: CardTextSnapshot, after: CardTextSnapshot) {
        guard before.title != after.title || before.content != after.content else { return }
        saveCardMutation()
        undoService?.registerCardTextChange(cardID: cardID, from: before, to: after)
    }

    private func snappedCoordinate(_ value: Double) -> Double {
        (value / gridSnapStep).rounded() * gridSnapStep
    }
}

private struct CanvasCardView: View {
    @Bindable var card: Card
    let zoomScale: CGFloat
    let isSelected: Bool
    let groupDragOffset: CGSize
    let usesGroupDrag: Bool
    let onSelect: () -> Void
    let onToggleSelection: () -> Void
    let onFrameCommit: (UUID, CardFrameSnapshot, CardFrameSnapshot) -> Void
    let onTextCommit: (UUID, CardTextSnapshot, CardTextSnapshot) -> Void
    let onGroupMoveChanged: (UUID, CGSize) -> Void
    let onGroupMoveEnded: (UUID, CGSize) -> Void
    let onDelete: () -> Void
    let onSendToKanban: () -> Void

    @State private var dragTranslation: CGSize = .zero
    @State private var resizeTranslation: CGSize = .zero
    @State private var gestureStartFrame: CardFrameSnapshot?
    @State private var textBaseline: CardTextSnapshot?
    @State private var textDebounceTask: DispatchWorkItem?

    private let minWidth: CGFloat = 180
    private let minHeight: CGFloat = 120

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("Title", text: $card.title)
                .font(.headline)
                .textFieldStyle(.plain)
                .onSubmit(flushTextChanges)

            TextEditor(text: $card.content)
                .font(.subheadline)
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                .frame(maxHeight: .infinity)
        }
        .padding(12)
        .frame(width: effectiveWidth, height: effectiveHeight, alignment: .topLeading)
        .background(.thickMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
        }
        .overlay(alignment: .bottomTrailing) {
            Circle()
                .fill(.tint)
                .frame(width: 14, height: 14)
                .padding(8)
                .gesture(resizeGesture)
        }
        .shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: 4)
        .offset(
            x: dragTranslation.width + groupDragOffset.width,
            y: dragTranslation.height + groupDragOffset.height
        )
        .gesture(moveGesture)
        .onTapGesture {
            onSelect()
        }
        .contextMenu {
            Button("Send to Kanban", action: onSendToKanban)
            Button("Delete Card", role: .destructive, action: onDelete)
        }
#if os(iOS)
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.35)
                .onEnded { _ in
                    onToggleSelection()
                }
        )
#endif
        .onChange(of: card.title) { oldValue, _ in
            beginTextSessionIfNeeded(previousTitle: oldValue, previousContent: card.content)
            scheduleTextCommit()
        }
        .onChange(of: card.content) { oldValue, _ in
            beginTextSessionIfNeeded(previousTitle: card.title, previousContent: oldValue)
            scheduleTextCommit()
        }
        .onDisappear {
            flushTextChanges()
        }
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
                if usesGroupDrag {
                    onGroupMoveChanged(card.id, value.translation)
                } else {
                    if gestureStartFrame == nil {
                        gestureStartFrame = currentFrameSnapshot
                    }
                    dragTranslation = value.translation
                }
            }
            .onEnded { value in
                if usesGroupDrag {
                    onGroupMoveEnded(card.id, value.translation)
                    dragTranslation = .zero
                    gestureStartFrame = nil
                    return
                }

                card.x += value.translation.width / max(zoomScale, 0.5)
                card.y += value.translation.height / max(zoomScale, 0.5)
                dragTranslation = .zero
                if let start = gestureStartFrame {
                    onFrameCommit(card.id, start, currentFrameSnapshot)
                }
                gestureStartFrame = nil
            }
    }

    private var resizeGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                if gestureStartFrame == nil {
                    gestureStartFrame = currentFrameSnapshot
                }
                resizeTranslation = value.translation
            }
            .onEnded { _ in
                card.width = Double(effectiveWidth)
                card.height = Double(effectiveHeight)
                resizeTranslation = .zero
                if let start = gestureStartFrame {
                    onFrameCommit(card.id, start, currentFrameSnapshot)
                }
                gestureStartFrame = nil
            }
    }

    private var currentFrameSnapshot: CardFrameSnapshot {
        CardFrameSnapshot(x: card.x, y: card.y, width: card.width, height: card.height)
    }

    private func beginTextSessionIfNeeded(previousTitle: String, previousContent: String) {
        guard textBaseline == nil else { return }
        textBaseline = CardTextSnapshot(title: previousTitle, content: previousContent)
    }

    private func scheduleTextCommit() {
        textDebounceTask?.cancel()
        let work = DispatchWorkItem {
            flushTextChanges()
        }
        textDebounceTask = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6, execute: work)
    }

    private func flushTextChanges() {
        textDebounceTask?.cancel()
        textDebounceTask = nil
        guard let baseline = textBaseline else { return }
        textBaseline = nil
        let updated = CardTextSnapshot(title: card.title, content: card.content)
        onTextCommit(card.id, baseline, updated)
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
