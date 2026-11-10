//
//  AppRoute.swift
//  MyPharmacist
//

/// A page pushed over the home screen. The app has one navigation path made of these, and
/// `RootView` says which view each one shows.
enum AppRoute: Hashable {
    /// "My Medications".
    case medications
    /// One medication's page, to change it or remove it.
    case medication(id: String)
    /// An empty medication page, to add a new one.
    case newMedication
    /// "About & privacy".
    case about
}
