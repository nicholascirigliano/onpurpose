import ContactsUI
import UIKit

/// Apple's contact picker. It runs outside the app, so it needs no Contacts permission:
/// we only ever see the one phone number the person taps.
enum ContactPicker {
    private static var delegate: Delegate?

    /// Presented from UIKit directly, since wrapping CNContactPickerViewController in a SwiftUI sheet is unreliable.
    static func present(onPick: @escaping (_ name: String, _ phone: String) -> Void) {
        let picker = CNContactPickerViewController()
        picker.displayedPropertyKeys = [CNContactPhoneNumbersKey]
        picker.predicateForEnablingContact = NSPredicate(format: "phoneNumbers.@count > 0")
        // Tapping a contact with one number picks it; with several, it opens their card to choose.
        picker.predicateForSelectionOfContact = NSPredicate(format: "phoneNumbers.@count == 1")

        let delegate = Delegate(onPick: onPick)
        Self.delegate = delegate
        picker.delegate = delegate
        topViewController()?.present(picker, animated: true)
    }

    private static func topViewController() -> UIViewController? {
        let scene = UIApplication.shared.connectedScenes.first { $0.activationState == .foregroundActive } as? UIWindowScene
        var top = scene?.windows.first { $0.isKeyWindow }?.rootViewController
        while let presented = top?.presentedViewController { top = presented }
        return top
    }

    private final class Delegate: NSObject, CNContactPickerDelegate {
        let onPick: (String, String) -> Void
        init(onPick: @escaping (String, String) -> Void) { self.onPick = onPick }

        func contactPicker(_ picker: CNContactPickerViewController, didSelect contact: CNContact) {
            guard let phone = contact.phoneNumbers.first?.value.stringValue else { return }
            finish(contact, phone)
        }

        func contactPicker(_ picker: CNContactPickerViewController, didSelect contactProperty: CNContactProperty) {
            guard let phone = (contactProperty.value as? CNPhoneNumber)?.stringValue else { return }
            finish(contactProperty.contact, phone)
        }

        func contactPickerDidCancel(_ picker: CNContactPickerViewController) {
            ContactPicker.delegate = nil
        }

        private func finish(_ contact: CNContact, _ phone: String) {
            // First name reads better in "Dave, Nick wants you to…".
            let name = contact.givenName.isEmpty
                ? CNContactFormatter.string(from: contact, style: .fullName) ?? ""
                : contact.givenName
            onPick(name, phone)
            ContactPicker.delegate = nil
        }
    }
}
