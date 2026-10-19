// duo-pose-ax: the macOS Accessibility half of duo-pose.
//
// It finds Device Hub's pose buttons and presses them with
// AXUIElementPerformAction(kAXPressAction). It never asks for, opens or
// changes any permission: the trust check passes kAXTrustedCheckOptionPrompt
// = false, so macOS shows no prompt. duo-pose (Python) builds this file on
// first use into the user's cache folder and calls it. Run it directly only
// to debug.
//
//   duo-pose-ax trust
//   duo-pose-ax buttons <DeviceHub pid> <simulator UDID> [<simulator name>]
//   duo-pose-ax press   <DeviceHub pid> <simulator UDID> <button label> [<simulator name>]
//   duo-pose-ax readout <DeviceHub pid> <simulator UDID> <accessibility identifier> [<simulator name>]
//
// Every command prints one JSON object on stdout.
// Exit codes: 0 done, 1 not found or press failed, 2 usage,
// 3 this process is not trusted for Accessibility, 5 no Device Hub window
// shows this simulator.
//
// Part of Duology (MIT license). https://github.com/Kimeur/duology

import ApplicationServices
import Foundation

let poseLabels = ["Closed", "Partially Open", "Open"]
let knownLabels = poseLabels + ["Rotate Right", "Rotate Left"]

func emit(_ object: [String: Any], exitCode: Int32) -> Never {
    if let data = try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]),
       let text = String(data: data, encoding: .utf8) {
        print(text)
    }
    exit(exitCode)
}

func attribute(_ element: AXUIElement, _ name: String) -> AnyObject? {
    var value: AnyObject?
    return AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success ? value : nil
}

func text(_ element: AXUIElement, _ name: String) -> String {
    guard let value = attribute(element, name) else { return "" }
    if let string = value as? String { return string }
    if let number = value as? NSNumber { return number.stringValue }
    return ""
}

func children(_ element: AXUIElement) -> [AXUIElement] {
    attribute(element, kAXChildrenAttribute) as? [AXUIElement] ?? []
}

/// Depth-first walk. `visit` returns true to stop.
@discardableResult
func walk(_ element: AXUIElement, depth: Int = 0, maxDepth: Int = 40,
          _ visit: (AXUIElement, Int) -> Bool) -> Bool {
    if visit(element, depth) { return true }
    guard depth < maxDepth else { return false }
    for child in children(element) where walk(child, depth: depth + 1, maxDepth: maxDepth, visit) {
        return true
    }
    return false
}

/// How a window was matched to the simulator: its sidebar row for this UDID
/// is selected ("selected-row"), or its title starts with the simulator's
/// name ("title"). A window whose selected row belongs to another device
/// never matches.
func matchWindow(app: AXUIElement, udid: String, name: String?) -> (AXUIElement, String)? {
    let wanted = "TableRow.Device.\(udid)"
    var byTitle: AXUIElement?
    for window in attribute(app, kAXWindowsAttribute) as? [AXUIElement] ?? [] {
        var selectedRowIDs: [String] = []
        walk(window, maxDepth: 14) { element, _ in
            guard text(element, kAXRoleAttribute) == "AXRow",
                  text(element, kAXSelectedAttribute) == "1" else { return false }
            walk(element, maxDepth: 4) { inner, _ in
                let id = text(inner, kAXIdentifierAttribute)
                if id.hasPrefix("TableRow.Device.") { selectedRowIDs.append(id); return true }
                return false
            }
            return false
        }
        if selectedRowIDs.contains(wanted) { return (window, "selected-row") }
        if !selectedRowIDs.isEmpty { continue }   // another device is selected here
        if let name, !name.isEmpty, text(window, kAXTitleAttribute).hasPrefix(name), byTitle == nil {
            byTitle = window
        }
    }
    return byTitle.map { ($0, "title") }
}

/// Device Hub's own pose buttons carry the same text as description and help.
/// Buttons mirrored from the app on screen don't, so an app button labelled
/// "Open" is never pressed. Prefer the group that holds all three pose buttons.
func findButtons(in window: AXUIElement) -> [String: AXUIElement] {
    func isDeviceHubButton(_ element: AXUIElement) -> String? {
        guard text(element, kAXRoleAttribute) == "AXButton" else { return nil }
        let label = text(element, kAXDescriptionAttribute)
        guard knownLabels.contains(label), text(element, kAXHelpAttribute) == label else { return nil }
        return label
    }
    var found: [String: AXUIElement] = [:]
    walk(window) { element, _ in
        let kids = children(element)
        var group: [String: AXUIElement] = [:]
        for kid in kids { if let label = isDeviceHubButton(kid) { group[label] = kid } }
        if poseLabels.allSatisfy({ group[$0] != nil }) { found = group; return true }
        return false
    }
    if found.isEmpty {
        walk(window) { element, _ in
            if let label = isDeviceHubButton(element), found[label] == nil { found[label] = element }
            return false
        }
    }
    return found
}

/// Labels of other Device Hub buttons, to show what changed when the pose
/// buttons can't be found (for example after an Xcode update).
func otherButtonLabels(in window: AXUIElement) -> [String] {
    var labels: [String] = []
    walk(window) { element, _ in
        if text(element, kAXRoleAttribute) == "AXButton", !text(element, kAXHelpAttribute).isEmpty {
            let label = text(element, kAXDescriptionAttribute)
            if !label.isEmpty, !labels.contains(label) { labels.append(label) }
        }
        return labels.count >= 40
    }
    return labels
}

// MARK: - Main

let args = Array(CommandLine.arguments.dropFirst())
guard let command = args.first else {
    emit(["error": "usage: duo-pose-ax trust | buttons | press | readout"], exitCode: 2)
}

let noPrompt = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false] as CFDictionary
let trusted = AXIsProcessTrustedWithOptions(noPrompt)
if command == "trust" { emit(["trusted": trusted], exitCode: 0) }
guard trusted else { emit(["trusted": false, "error": "not trusted for Accessibility"], exitCode: 3) }

let needed = ["buttons": 3, "press": 4, "readout": 4][command]
guard let needed, args.count >= needed, let pid = Int32(args[1]), pid > 0 else {
    emit(["error": "usage: duo-pose-ax \(command) <pid> <udid> ..."], exitCode: 2)
}
let udid = args[2]
let name: String? = args.count > needed ? args[needed] : nil
let app = AXUIElementCreateApplication(pid)
AXUIElementSetMessagingTimeout(app, 5)

guard let (window, match) = matchWindow(app: app, udid: udid, name: name) else {
    let titles = (attribute(app, kAXWindowsAttribute) as? [AXUIElement] ?? []).map { text($0, kAXTitleAttribute) }
    emit(["trusted": true, "window": NSNull(), "windows": titles,
          "error": "no Device Hub window shows this simulator"], exitCode: 5)
}
let windowTitle = text(window, kAXTitleAttribute)
let buttons = findButtons(in: window)

switch command {
case "buttons":
    // "value" and "selected" are reported as Device Hub sets them (often empty),
    // so a newer Device Hub that marks the current pose shows up here.
    let list = knownLabels.compactMap { label -> [String: Any]? in
        guard let button = buttons[label] else { return nil }
        return ["label": label, "enabled": text(button, kAXEnabledAttribute) != "0",
                "value": text(button, kAXValueAttribute), "selected": text(button, kAXSelectedAttribute)]
    }
    var out: [String: Any] = ["trusted": true, "window": windowTitle, "match": match, "buttons": list]
    if buttons.isEmpty { out["otherButtons"] = otherButtonLabels(in: window) }
    emit(out, exitCode: buttons.isEmpty ? 1 : 0)

case "press":
    let label = args[3]
    guard let button = buttons[label] else {
        emit(["trusted": true, "window": windowTitle, "match": match, "pressed": false,
              "error": "no \(label) button in Device Hub"], exitCode: 1)
    }
    let result = AXUIElementPerformAction(button, kAXPressAction as CFString)
    emit(["trusted": true, "window": windowTitle, "match": match, "label": label,
          "pressed": result == .success, "axError": Int(result.rawValue)],
         exitCode: result == .success ? 0 : 1)

case "readout":
    let identifier = args[3]
    var hit: AXUIElement?
    walk(window, maxDepth: 60) { element, _ in
        if text(element, kAXIdentifierAttribute) == identifier { hit = element; return true }
        return false
    }
    guard let hit else {
        emit(["trusted": true, "window": windowTitle, "match": match, "found": false], exitCode: 1)
    }
    emit(["trusted": true, "window": windowTitle, "match": match, "found": true,
          "value": text(hit, kAXValueAttribute), "label": text(hit, kAXDescriptionAttribute),
          "title": text(hit, kAXTitleAttribute)], exitCode: 0)

default:
    emit(["error": "unknown command \(command)"], exitCode: 2)
}
