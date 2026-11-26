//
//  Report.swift
//  pill-bench
//
//  The results as a table (results.csv), a page with every photo's picture
//  (report.html, opened from the folder), and a summary by surface.
//

import Foundation

enum Report {
    static func write(_ rows: [Row], to out: URL) {
        let csv = (["file,surface,really,found,circled,outcome,status,ms,details"] + rows.map { row in
            [row.file, row.surface, row.truth.map(String.init) ?? "", String(row.found), row.circled.map(String.init) ?? "",
             row.outcome, row.status.rawValue, String(format: "%.0f", row.milliseconds), row.details.joined(separator: " | ")]
                .map(quoted).joined(separator: ",")
        }).joined(separator: "\n") + "\n"
        try? csv.write(to: out.appending(path: "results.csv"), atomically: true, encoding: .utf8)
        try? page(rows).write(to: out.appending(path: "report.html"), atomically: true, encoding: .utf8)
    }

    /// Per surface: how many photos came out right, how many lost a pill without a word,
    /// how many asked for a retake, and, of the real pills in photos that went on to the
    /// question "Is every pill circled?", how many weren't circled.
    static func summary(_ rows: [Row]) -> String {
        let surfaces = Array(Set(rows.map(\.surface))).sorted()
        var lines = ["surface  photos  right  missed(silent)  retake  no-pills  extra  failed  pills lost silently"]
        for surface in surfaces + ["all"] {
            let group = surface == "all" ? rows : rows.filter { $0.surface == surface }
            func count(_ statuses: Row.Status...) -> Int { group.filter { statuses.contains($0.status) }.count }
            let wentOn = group.filter { $0.truth != nil && $0.outcome.hasPrefix("found") }
            let real = wentOn.reduce(0) { $0 + ($1.truth ?? 0) }
            let lost = wentOn.reduce(0) { $0 + max(0, ($1.truth ?? 0) - ($1.circled ?? 0)) }
            let share = real > 0 ? String(format: "%d of %d (%.0f%%)", lost, real, Double(lost) / Double(real) * 100) : "-"
            lines.append([surface.padding(toLength: 8, withPad: " ", startingAt: 0), String(format: "%6d", group.count),
                          String(format: "%6d", count(.right, .rightRetake)), String(format: "%15d", count(.missed)),
                          String(format: "%7d", count(.retake)), String(format: "%9d", count(.noPills)),
                          String(format: "%6d", count(.extra)), String(format: "%7d", count(.failed)), "  " + share]
                .joined(separator: " "))
        }
        let times = rows.map(\.milliseconds).sorted()
        if !times.isEmpty {
            lines.append(String(format: "search time on this Mac: median %.0f ms, slowest %.0f ms", times[times.count / 2], times.last ?? 0))
        }
        return lines.joined(separator: "\n")
    }

    private static func quoted(_ field: String) -> String {
        field.contains(where: { $0 == "," || $0 == "\"" || $0 == "\n" }) ? "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\"" : field
    }

    private static func escaped(_ text: String) -> String {
        text.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "<", with: "&lt;").replacingOccurrences(of: ">", with: "&gt;")
    }

    private static func page(_ rows: [Row]) -> String {
        let cards = rows.map { row in
            """
            <figure class="\(row.status == .right || row.status == .rightRetake ? "ok" : row.status == .unlabelled ? "" : "bad")">
              <a href="overlays/\(escaped(row.overlayName))"><img src="overlays/\(escaped(row.overlayName))" loading="lazy" alt=""></a>
              <figcaption><b>\(escaped(row.file))</b> · \(escaped(row.surface)) · \(escaped(row.outcome))\(row.truth.map { " of \($0)" } ?? "") · <b>\(escaped(row.status.rawValue))</b> · \(String(format: "%.0f", row.milliseconds)) ms
              <ul>\(row.details.map { "<li>\(escaped($0))</li>" }.joined())</ul></figcaption>
            </figure>
            """
        }.joined(separator: "\n")
        return """
            <!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
            <title>Pill finding bench</title>
            <style>
            :root { color-scheme: light dark; --bg: #f7f5f0; --fg: #1d1a16; --muted: #6b645a; --card: #fff; --ok: #1f7a3a; --bad: #b3261e }
            @media (prefers-color-scheme: dark) { :root { --bg: #171512; --fg: #eee9e0; --muted: #a59d90; --card: #221f1a; --ok: #5cc97c; --bad: #ff8a80 } }
            body { margin: 0; padding: 24px max(16px, 3vw); background: var(--bg); color: var(--fg); font: 14px/1.45 -apple-system, system-ui, sans-serif }
            h1 { font-size: 22px; margin: 0 0 8px }
            pre { background: var(--card); padding: 12px; border-radius: 8px; overflow-x: auto; font-size: 12.5px }
            .legend { color: var(--muted); max-width: 80ch }
            .grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(300px, 1fr)); gap: 16px; margin-top: 16px }
            figure { margin: 0; background: var(--card); border-radius: 10px; overflow: hidden; border-top: 4px solid transparent }
            figure.ok { border-top-color: var(--ok) } figure.bad { border-top-color: var(--bad) }
            img { width: 100%; display: block }
            figcaption { padding: 10px 12px; font-size: 12.5px } ul { margin: 6px 0 0; padding-left: 18px; color: var(--muted) }
            </style></head><body>
            <h1>Pill finding bench</h1>
            <p class="legend">Blue: the surface Vision found. Cyan outline: Vision's pill-sized objects. Magenta: clearly a different colour from the surface; yellow: faintly. Ellipses: pill-sized areas (green kept, grey dashed ignored, orange asked for a retake). Green boxes: what the app circles. Red dashed rings: real pills not circled.</p>
            <pre>\(escaped(summary(rows)))</pre>
            <div class="grid">
            \(cards)
            </div></body></html>
            """
    }
}
