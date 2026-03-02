import SwiftUI

#if os(iOS) && canImport(PencilKit)
import PencilKit

struct DrawingOverlayView: View {
    @Binding var drawingData: Data
    let isEnabled: Bool
    let onSave: () -> Void

    var body: some View {
        DrawingCanvasRepresentable(drawingData: $drawingData, isEnabled: isEnabled, onSave: onSave)
            .allowsHitTesting(isEnabled)
    }
}

private struct DrawingCanvasRepresentable: UIViewRepresentable {
    @Binding var drawingData: Data
    let isEnabled: Bool
    let onSave: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(drawingData: $drawingData, onSave: onSave)
    }

    func makeUIView(context: Context) -> PKCanvasView {
        let view = PKCanvasView()
        view.backgroundColor = .clear
        view.delegate = context.coordinator
        view.drawingPolicy = .anyInput
        view.tool = PKInkingTool(.pen, color: .label, width: 4)
        context.coordinator.applyDrawingIfNeeded(to: view)
        return view
    }

    func updateUIView(_ uiView: PKCanvasView, context: Context) {
        uiView.isUserInteractionEnabled = isEnabled
        context.coordinator.applyDrawingIfNeeded(to: uiView)
    }
}

private final class Coordinator: NSObject, PKCanvasViewDelegate {
    @Binding private var drawingData: Data
    private let onSave: () -> Void

    init(drawingData: Binding<Data>, onSave: @escaping () -> Void) {
        self._drawingData = drawingData
        self.onSave = onSave
    }

    func applyDrawingIfNeeded(to canvasView: PKCanvasView) {
        let loadedDrawing = (try? PKDrawing(data: drawingData)) ?? PKDrawing()
        guard canvasView.drawing.dataRepresentation() != loadedDrawing.dataRepresentation() else { return }
        canvasView.drawing = loadedDrawing
    }

    func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
        drawingData = canvasView.drawing.dataRepresentation()
        onSave()
    }
}
#else

struct DrawingOverlayView: View {
    @Binding var drawingData: Data
    let isEnabled: Bool
    let onSave: () -> Void

    var body: some View {
        Color.clear
    }
}

#endif
