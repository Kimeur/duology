#!/usr/bin/env python3
"""Tests for single_owner.py: correct fixes must pass, broken ones must fail.

usage: python3 evals/lib/checks/test_single_owner.py [--typecheck]

Each case is a tiny SwiftUI app. With --typecheck, every case is also typechecked
against the iOS 27.1 simulator SDK (needs Xcode 27.1; DEVELOPER_DIR defaults to
/Applications/Xcode-27.1.app/Contents/Developer), so the cases stay real Swift.
"""
import os
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
CHECK = os.path.join(HERE, "single_owner.py")

APP = """
@main
struct DemoApp: App {
    var body: some Scene {
        WindowGroup { Screen() }
    }
}
"""

QUERY = r"\bvar +(query|searchText|searchQuery|searchTerm)\b"
PLAYER = r"AVPlayer\(|AVQueuePlayer\("

CASES = [
    # name, pattern, expected exit, Swift source
    ("each-layout-owns-its-state", QUERY, 1, """
import SwiftUI
""" + APP + """
struct Screen: View {
    @Environment(\\.horizontalSizeClass) private var sizeClass
    var body: some View {
        if sizeClass == .regular { Wide() } else { Narrow() }
    }
}
struct Wide: View {
    @State private var query = ""
    var body: some View { TextField("Search", text: $query) }
}
struct Narrow: View {
    @State private var query = ""
    var body: some View { TextField("Search", text: $query).padding() }
}
"""),
    ("state-lifted-above-switch", QUERY, 0, """
import SwiftUI
""" + APP + """
struct Screen: View {
    @Environment(\\.horizontalSizeClass) private var sizeClass
    @State private var query = ""
    var body: some View {
        if sizeClass == .regular { Wide(query: $query) } else { Narrow(query: $query) }
    }
}
struct Wide: View {
    @Binding var query: String
    var body: some View { TextField("Search", text: $query) }
}
struct Narrow: View {
    @Binding var query: String
    var body: some View { TextField("Search", text: $query).padding() }
}
"""),
    ("scene-storage-above-switch", QUERY, 0, """
import SwiftUI
""" + APP + """
struct Screen: View {
    @Environment(\\.horizontalSizeClass) private var sizeClass
    @SceneStorage("query") private var query = ""
    var body: some View {
        if sizeClass == .regular { Wide(query: $query) } else { Narrow(query: $query) }
    }
}
struct Wide: View {
    @Binding var query: String
    var body: some View { TextField("Search", text: $query) }
}
struct Narrow: View {
    @Binding var query: String
    var body: some View { TextField("Search", text: $query).padding() }
}
"""),
    ("observable-model-in-state", QUERY, 0, """
import SwiftUI
import Observation
""" + APP + """
@Observable
final class SearchModel {
    var query = ""
}
struct Screen: View {
    @Environment(\\.horizontalSizeClass) private var sizeClass
    @State private var model = SearchModel()
    var body: some View {
        if sizeClass == .regular { Wide(model: model) } else { Narrow(model: model) }
    }
}
struct Wide: View {
    @Bindable var model: SearchModel
    var body: some View { TextField("Search", text: $model.query) }
}
struct Narrow: View {
    @Bindable var model: SearchModel
    var body: some View { TextField("Search", text: $model.query).padding() }
}
"""),
    ("state-object-model", QUERY, 0, """
import SwiftUI
import Combine
""" + APP + """
final class SearchStore: ObservableObject {
    @Published var query = ""
}
struct Screen: View {
    @Environment(\\.horizontalSizeClass) private var sizeClass
    @StateObject private var store = SearchStore()
    var body: some View {
        if sizeClass == .regular { Wide(store: store) } else { Narrow(store: store) }
    }
}
struct Wide: View {
    @ObservedObject var store: SearchStore
    var body: some View { TextField("Search", text: $store.query) }
}
struct Narrow: View {
    @ObservedObject var store: SearchStore
    var body: some View { TextField("Search", text: $store.query).padding() }
}
"""),
    ("value-container-in-state", QUERY, 0, """
import SwiftUI
""" + APP + """
struct SearchState {
    var query = ""
    var ascending = true
}
struct Screen: View {
    @Environment(\\.horizontalSizeClass) private var sizeClass
    @State private var state = SearchState()
    var body: some View {
        if sizeClass == .regular {
            TextField("Search", text: $state.query)
        } else {
            TextField("Search", text: $state.query).padding()
        }
    }
}
"""),
    ("model-created-in-a-branch", QUERY, 1, """
import SwiftUI
import Observation
""" + APP + """
@Observable
final class SearchModel {
    var query = ""
}
struct Screen: View {
    @Environment(\\.horizontalSizeClass) private var sizeClass
    var body: some View {
        if sizeClass == .regular { Wide(model: SearchModel()) } else { Text("Narrow") }
    }
}
struct Wide: View {
    @Bindable var model: SearchModel
    var body: some View { TextField("Search", text: $model.query) }
}
"""),
    ("owner-view-created-in-each-branch", QUERY, 1, """
import SwiftUI
""" + APP + """
struct Screen: View {
    @Environment(\\.horizontalSizeClass) private var sizeClass
    var body: some View {
        if sizeClass == .regular {
            HStack { SearchBox(); Text("Detail") }
        } else {
            VStack { SearchBox() }
        }
    }
}
struct SearchBox: View {
    @State private var query = ""
    var body: some View { TextField("Search", text: $query) }
}
"""),
    ("player-per-branch", PLAYER, 1, """
import AVKit
import SwiftUI
""" + APP + """
struct Screen: View {
    @Environment(\\.horizontalSizeClass) private var sizeClass
    var body: some View {
        if sizeClass == .regular {
            HStack { VideoPane(); Text("Up next") }
        } else {
            VStack { VideoPane(); Text("Up next") }
        }
    }
}
struct VideoPane: View {
    @State private var player = AVPlayer()
    var body: some View { VideoPlayer(player: player) }
}
"""),
    ("player-in-plain-let-of-a-view", PLAYER, 1, """
import AVKit
import SwiftUI
""" + APP + """
struct Screen: View {
    var body: some View { VideoPane() }
}
struct VideoPane: View {
    private let player = AVPlayer()
    var body: some View { VideoPlayer(player: player) }
}
"""),
    ("player-model-above-switch", PLAYER, 0, """
import AVKit
import SwiftUI
import Observation
""" + APP + """
@Observable
final class Playback {
    let player = AVPlayer()
}
struct Screen: View {
    @Environment(\\.horizontalSizeClass) private var sizeClass
    @State private var playback = Playback()
    var body: some View {
        if sizeClass == .regular {
            HStack { VideoPlayer(player: playback.player); Text("Up next") }
        } else {
            VStack { VideoPlayer(player: playback.player); Text("Up next") }
        }
    }
}
"""),
    ("player-in-static-shared", PLAYER, 0, """
import AVKit
import SwiftUI
""" + APP + """
@MainActor
final class Playback {
    static let shared = Playback()
    let player = AVPlayer()
}
struct Screen: View {
    @Environment(\\.horizontalSizeClass) private var sizeClass
    var body: some View {
        if sizeClass == .regular {
            HStack { VideoPlayer(player: Playback.shared.player); Text("Up next") }
        } else {
            VStack { VideoPlayer(player: Playback.shared.player); Text("Up next") }
        }
    }
}
"""),
    ("player-view-kept-by-anylayout", PLAYER, 0, """
import AVKit
import SwiftUI
""" + APP + """
struct Screen: View {
    @Environment(\\.horizontalSizeClass) private var sizeClass
    var body: some View {
        let layout = sizeClass == .regular ? AnyLayout(HStackLayout()) : AnyLayout(VStackLayout())
        layout {
            VideoPane()
            Text("Up next")
        }
    }
}
struct VideoPane: View {
    @State private var player = AVPlayer()
    var body: some View { VideoPlayer(player: player) }
}
"""),
]


def typecheck(path):
    env = dict(os.environ)
    env.setdefault("DEVELOPER_DIR", "/Applications/Xcode-27.1.app/Contents/Developer")
    r = subprocess.run(["xcrun", "-sdk", "iphonesimulator", "swiftc", "-typecheck", "-parse-as-library",
                        "-target", "arm64-apple-ios27.1-simulator", path],
                       capture_output=True, text=True, env=env)
    return r.returncode, (r.stdout + r.stderr).strip()


def main(argv):
    do_typecheck = "--typecheck" in argv
    failures = 0
    with tempfile.TemporaryDirectory() as tmp:
        for name, pattern, expected, source in CASES:
            case_dir = os.path.join(tmp, name)
            os.makedirs(case_dir)
            path = os.path.join(case_dir, "App.swift")
            with open(path, "w", encoding="utf-8") as f:
                f.write(source.lstrip())
            if do_typecheck:
                code, out = typecheck(path)
                if code != 0:
                    failures += 1
                    print("FAIL %-36s does not typecheck:\n%s" % (name, out))
                    continue
            r = subprocess.run([sys.executable, CHECK, pattern, case_dir], capture_output=True, text=True)
            ok = r.returncode == expected
            failures += 0 if ok else 1
            print("%s %-36s expected %s, got %s: %s" % (
                "ok  " if ok else "FAIL", name, "pass" if expected == 0 else "fail",
                "pass" if r.returncode == 0 else "fail", r.stdout.strip()[:140]))
    print("%d case(s), %d failure(s)%s" % (len(CASES), failures, ", typechecked" if do_typecheck else ""))
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
