#if os(iOS)
import SwiftUI
import UIKit

struct ScanCameraCapturePresenter: ViewModifier {
    @Binding var isPresented: Bool
    let isInteractiveDismissDisabled: Bool
    let action: (UIImage) async -> Void
    let onCancel: () -> Void

    func body(content view: Content) -> some View {
        view.sheet(isPresented: $isPresented) {
            CameraImagePicker(
                onImagePicked: { image in
                    isPresented = false
                    Task {
                        await action(image)
                    }
                },
                onCancel: {
                    isPresented = false
                    onCancel()
                }
            )
            .interactiveDismissDisabled(isInteractiveDismissDisabled)
        }
    }
}

extension View {
    func scanCameraCaptureSheet(
        isPresented: Binding<Bool>,
        isInteractiveDismissDisabled: Bool = false,
        action: @escaping (UIImage) async -> Void,
        onCancel: @escaping () -> Void = {}
    ) -> some View {
        modifier(
            ScanCameraCapturePresenter(
                isPresented: isPresented,
                isInteractiveDismissDisabled: isInteractiveDismissDisabled,
                action: action,
                onCancel: onCancel
            ))
    }
}
#endif
