//
//  PillPhotoSlot.swift
//  MyPharmacist
//

import PhotosUI
import SwiftUI

/// One photo of a tablet in the medication editor ("Front" or "Back"): the photo, or a
/// button to add one with the camera or from Photos. A new photo is cut down to the
/// tablet (`PillReferencePhoto`) and kept on the device (`MedicationPhotoStore`).
struct PillPhotoSlot: View {
    let title: String
    @Binding var photo: MedicationPhoto?
    /// Called with each photo this slot saves, so the editor can delete the ones it
    /// doesn't keep.
    var onSaved: (MedicationPhoto) -> Void = { _ in }

    @State private var isChoosing = false
    @State private var isTakingPhoto = false
    @State private var isPickingPhoto = false
    @State private var pickedItem: PhotosPickerItem?
    @State private var isWorking = false
    @State private var problem: String?
    @ScaledMetric(relativeTo: .title3) private var side: CGFloat = 120

    var body: some View {
        VStack(spacing: 8) {
            Button { isChoosing = true } label: { tile }
                .buttonStyle(.plain)
                .disabled(isWorking)
                .accessibilityLabel(photo == nil ? "Add a photo of the \(title.lowercased())" : "Photo of the \(title.lowercased())")
                .accessibilityHint(photo == nil ? "" : "Change or remove it")
            Text(title)
                .font(.body.weight(.semibold))
                .foregroundStyle(Palette.textSecondary)
            if let problem {
                Text(problem)
                    .font(.footnote)
                    .foregroundStyle(Palette.danger)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity)
        .confirmationDialog("Photo of the \(title.lowercased())", isPresented: $isChoosing, titleVisibility: .visible) {
            if CameraPicker.isAvailable {
                Button("Take a photo") { isTakingPhoto = true }
            }
            Button("Choose from Photos") { isPickingPhoto = true }
            if photo != nil {
                Button("Remove photo", role: .destructive) { photo = nil }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Put the pill alone on a plain surface.")
        }
        .fullScreenCover(isPresented: $isTakingPhoto) {
            CameraPicker { image in
                isTakingPhoto = false
                if let image { use(image) }
            }
            .ignoresSafeArea()
        }
        .photosPicker(isPresented: $isPickingPhoto, selection: $pickedItem, matching: .images)
        .onChange(of: pickedItem) { _, item in
            guard let item else { return }
            pickedItem = nil
            Task {
                guard let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) else {
                    problem = PillReferencePhoto.Failure.unreadable.message
                    return
                }
                use(image)
            }
        }
    }

    private var tile: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Palette.cardFill)
            if let photo, let image = MedicationPhotoStore.standard.image(photo) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .padding(10)
            } else {
                Image(systemName: "camera.fill")
                    .font(.system(size: side * 0.25))
                    .foregroundStyle(Palette.textMuted)
            }
            if isWorking {
                ProgressView()
                    .controlSize(.large)
            }
        }
        .frame(width: side, height: side)
    }

    /// Cuts the photo down to the tablet off the main thread, then keeps it.
    private func use(_ image: UIImage) {
        isWorking = true
        problem = nil
        Task {
            let result = await Task.detached(priority: .userInitiated) { PillReferencePhoto.make(from: image) }.value
            switch result {
            case .success(let cutOut):
                if let saved = try? MedicationPhotoStore.standard.save(cutOut) {
                    onSaved(saved)
                    photo = saved
                } else {
                    problem = PillReferencePhoto.Failure.unreadable.message
                }
            case .failure(let failure):
                problem = failure.message
            }
            isWorking = false
        }
    }
}
