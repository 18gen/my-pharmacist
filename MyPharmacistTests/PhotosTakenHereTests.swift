//
//  PhotosTakenHereTests.swift
//  MyPharmacistTests
//

import Foundation
import Testing
@testable import MyPharmacist

@MainActor
struct PhotosTakenHereTests {
    private func exists(_ photo: MedicationPhoto, in photos: MedicationPhotoStore) -> Bool {
        guard case .file(let name) = photo else { return false }
        return FileManager.default.fileExists(atPath: photos.directory.appending(path: name).path)
    }

    @Test func photosTakenForANewMedicationAreKeptWhenItIsAdded() throws {
        let photos = temporaryPhotoStore()
        let front = try photos.save(testImage()), back = try photos.save(testImage()), retaken = try photos.save(testImage())
        let takenHere = PhotosTakenHere(photoStore: photos)
        [retaken, front, back].forEach(takenHere.add)
        // The first front photo was taken again; the medication keeps the other two.
        takenHere.keep([front, back])
        #expect(exists(front, in: photos) && exists(back, in: photos))
        #expect(!exists(retaken, in: photos))
    }

    @Test func leavingANewMedicationDeletesItsPhotos() throws {
        let photos = temporaryPhotoStore()
        let front = try photos.save(testImage())
        let takenHere = PhotosTakenHere(photoStore: photos)
        takenHere.add(front)
        takenHere.keep([])
        #expect(!exists(front, in: photos))
    }
}
