import FirebaseAuth
import FirebaseCore
import FirebaseFirestore
import Foundation

/// Firebase: invisible sign-in, creating purposes, and hearing when people purpose back.
enum Cloud {
    /// Pass `-useEmulator` as a launch argument to use `firebase emulators:start` on this Mac.
    static let useEmulator = ProcessInfo.processInfo.arguments.contains("-useEmulator")

    static func link(for purposeID: String) -> String {
        let base = useEmulator ? "http://localhost:5050/" : "https://nicholascirigliano.github.io/onpurpose/"
        return base + "?p=" + purposeID
    }

    private static var listener: ListenerRegistration?
    private static var purposes: CollectionReference { Firestore.firestore().collection("purposes") }

    static func configure() {
        FirebaseApp.configure()
        guard useEmulator else { return }
        Auth.auth().useEmulator(withHost: "127.0.0.1", port: 9099)
        let settings = Firestore.firestore().settings
        settings.host = "127.0.0.1:8080"
        settings.isSSLEnabled = false
        settings.cacheSettings = MemoryCacheSettings()
        Firestore.firestore().settings = settings
    }

    static func signIn() async throws -> String {
        if let user = Auth.auth().currentUser { return user.uid }
        return try await Auth.auth().signInAnonymously().user.uid
    }

    /// Creates the purpose and returns its id, which is the secret part of the link.
    /// Field limits mirror firestore.rules.
    static func createPurpose(senderName: String, recipientName: String, phrase: String,
                              replyWindowMinutes: Int) async throws -> String {
        let uid = try await signIn()
        let ref = purposes.document()
        try await ref.setData([
            "ownerUid": uid,
            "senderName": String(senderName.prefix(40)),
            "recipientName": String(recipientName.prefix(40)),
            "phrase": String(phrase.prefix(80)),
            "replyWindowMinutes": replyWindowMinutes,
            "createdAt": FieldValue.serverTimestamp(),
            "dueAt": Timestamp(date: Date().addingTimeInterval(Double(replyWindowMinutes) * 60)),
            "purposedBackAt": NSNull(),
            "reply": NSNull(),
        ])
        return ref.documentID
    }

    static func deletePurpose(_ id: String) {
        purposes.document(id).delete()
    }

    /// Calls `onPurposeBack` (on the main queue) for each of my purposes that has been purposed back.
    static func listenForPurposeBacks(_ onPurposeBack: @escaping (_ id: String, _ reply: String, _ at: Date) -> Void) {
        Task {
            guard let uid = try? await signIn() else { return }
            listener?.remove()
            listener = purposes.whereField("ownerUid", isEqualTo: uid).addSnapshotListener { snapshot, _ in
                for doc in snapshot?.documents ?? [] {
                    guard let at = (doc["purposedBackAt"] as? Timestamp)?.dateValue() else { continue }
                    onPurposeBack(doc.documentID, doc["reply"] as? String ?? "", at)
                }
            }
        }
    }
}
