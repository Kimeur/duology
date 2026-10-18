import Foundation

struct Message: Identifiable, Hashable {
    let id: Int
    let sender: String
    let subject: String
    let preview: String
    let body: String
    let date: String
    var isUnread = false
}

extension Message {
    static let samples: [Message] = [
        Message(id: 1, sender: "Priya Raman", subject: "Lunch on Friday",
                preview: "Shall we try the new place by the station? I can book for 12:30.",
                body: "Shall we try the new place by the station? I can book for 12:30 if that works for you. They do a set menu at lunch, and the terrace should be open if the weather holds.",
                date: "09:41", isUnread: true),
        Message(id: 2, sender: "Facilities Team", subject: "Lift maintenance next week",
                preview: "The east lift will be out of service on Tuesday and Wednesday.",
                body: "The east lift will be out of service on Tuesday and Wednesday while the doors are replaced. Please use the west lift or the stairs. Deliveries will come through the loading bay.",
                date: "08:15", isUnread: true),
        Message(id: 3, sender: "Tom Becker", subject: "Draft for the quarterly review",
                preview: "Here is the first draft. The numbers in section 3 still need a check.",
                body: "Here is the first draft. The numbers in section 3 still need a check, and I left two questions for you in the comments. Could you look before Thursday?",
                date: "Yesterday"),
        Message(id: 4, sender: "Library", subject: "Your reservation is ready",
                preview: "The book you reserved is waiting at the front desk until 28 October.",
                body: "The book you reserved is waiting at the front desk until 28 October. Bring your library card to collect it. You can extend the loan online.",
                date: "Yesterday"),
        Message(id: 5, sender: "Ana Lima", subject: "Photos from the hike",
                preview: "Uploaded the photos from Saturday. The one at the waterfall came out great.",
                body: "Uploaded the photos from Saturday. The one at the waterfall came out great. Let me know if you want the full-size files for printing.",
                date: "Sat"),
        Message(id: 6, sender: "Rail Services", subject: "Your ticket for 3 November",
                preview: "Your seat is reserved in coach C, seat 42. Departure at 07:55.",
                body: "Your seat is reserved in coach C, seat 42. The train leaves at 07:55 from platform 4. Show the barcode in this message at the gate.",
                date: "Fri"),
    ]
}
