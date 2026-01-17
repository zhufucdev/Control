import Foundation
import SwiftUI

#if os(iOS)
    struct CameraView: UIViewControllerRepresentable {
        let allowsEditing: Bool = true
        let result: (Optional<UIImage>) -> Void

        func updateUIViewController(_ uiViewController: UIImagePickerController, context: UIViewControllerRepresentableContext<CameraView>) {
            uiViewController.allowsEditing = allowsEditing
        }

        func makeCoordinator() -> ImagePickerCoordinator {
            return ImagePickerCoordinator(result)
        }

        func makeUIViewController(context: UIViewControllerRepresentableContext<CameraView>) -> UIImagePickerController {
            let picker = UIImagePickerController()
            picker.delegate = context.coordinator
            picker.allowsEditing = true
            
            if !UIImagePickerController.isSourceTypeAvailable(.camera) {
                picker.sourceType = .photoLibrary
            } else {
                picker.sourceType = .camera
            }
            return picker
        }
    }

    class ImagePickerCoordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let result: (Optional<UIImage>) -> Void

        init(_ result: @escaping (Optional<UIImage>) -> Void) {
            self.result = result
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            let uiImage = info[UIImagePickerController.InfoKey.originalImage] as! UIImage
            result(.some(uiImage))
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            result(.none)
        }
    }
#endif
