//
//  DebugSharing.swift
//  MyPharmacist
//

#if DEBUG
import Foundation

/// Debug builds only: trying sharing without typing on the Simulator.
/// - `-pharmacyURL http://localhost:3000 -pharmacyToken <APP_TOKEN>` shares with the
///   dashboard running on this Mac (`npm run dev` in my-pharmacist-dashboard) instead of
///   the one in Secrets.plist (`PharmacyShareClient.Configuration.current`).
/// - `-shareAs <name>` starts sharing under that name on launch, if not sharing yet.
/// - `-resetWithSampleWeek` does "Reset demo → With a sample week" on launch, first.
enum DebugSharing {
    static func apply(to model: AppModel) {
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("-resetWithSampleWeek") {
            model.resetDemo(sampleWeek: true)
        }
        if let index = arguments.firstIndex(of: "-shareAs"), arguments.indices.contains(index + 1),
           model.share.session == nil {
            let name = arguments[index + 1]
            Task { await model.share.start(name: name) }
        }
    }
}

/// The pharmacy demo for the screenshots of `DemoScan`: answers at once, sending nothing
/// anywhere. With `endsSharing`, every sending answers that the demo was reset.
struct DemoPharmacy: PharmacyDemo {
    var endsSharing = false

    func join(name: String) async throws(ShareFailure) -> String { "demo" }

    func send(_ snapshot: ShareSnapshot, as id: String) async throws(ShareFailure) {
        if endsSharing { throw .gone }
    }

    func sendPhoto(_ jpeg: Data, photoID: UUID, as id: String) async throws(ShareFailure) {
        if endsSharing { throw .gone }
    }

    func leave(_ id: String) async throws(ShareFailure) {}
}
#endif
