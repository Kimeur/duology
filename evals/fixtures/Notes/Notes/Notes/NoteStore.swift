import Foundation
import Observation

/// Every note in the app.
@Observable
final class NoteStore {
    var notes: [Note] = [
        Note(title: "Groceries", text: "Oat milk\nLemons\nSourdough\nCoffee beans"),
        Note(title: "Trip to Porto", text: "Train at 08:10 from Lisbon.\nHotel near Ribeira.\nBook the port cellar tour."),
        Note(title: "Gift ideas", text: "Mum: gardening gloves\nLeo: the new puzzle book\nSam: concert tickets"),
        Note(title: "Book club", text: "Next meeting on the 14th. Read chapters 6 to 10."),
    ]

    func note(_ id: Note.ID) -> Note? {
        notes.first { $0.id == id }
    }

    func update(_ id: Note.ID, text: String) {
        guard let index = notes.firstIndex(where: { $0.id == id }) else { return }
        notes[index].text = text
        notes[index].title = text.split(separator: "\n").first.map(String.init) ?? "New Note"
        notes[index].edited = Date()
    }

    @discardableResult
    func add() -> Note {
        let note = Note(title: "New Note", text: "")
        notes.insert(note, at: 0)
        return note
    }

    func duplicate(_ id: Note.ID) {
        guard let original = note(id), let index = notes.firstIndex(of: original) else { return }
        notes.insert(Note(title: original.title, text: original.text), at: index + 1)
    }

    func delete(_ id: Note.ID) {
        notes.removeAll { $0.id == id }
    }
}
