import SwiftUI

struct PeopleView: View {
    @Environment(Store.self) private var store
    @State private var addingPerson = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(store.people) { person in
                    NavigationLink(value: person.id) {
                        HStack(spacing: 12) {
                            Avatar(person: person)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(person.name).font(.headline)
                                let active = store.plans(for: person).filter(\.isActive)
                                Text(active.first?.scheduleText ?? "No schedule")
                                    .font(.subheadline).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .overlay {
                if store.people.isEmpty {
                    ContentUnavailableView {
                        Label("Nobody to purpose", systemImage: "person.2")
                    } description: {
                        Text("Add the people who need purposing. Everyone needs purposing.")
                    } actions: {
                        Button("Add someone to purpose") { addingPerson = true }.buttonStyle(.borderedProminent)
                    }
                }
            }
            .navigationTitle("People")
            .navigationDestination(for: UUID.self) { PersonDetailView(personID: $0) }
            .toolbar {
                Button { addingPerson = true } label: { Image(systemName: "plus") }
            }
            .sheet(isPresented: $addingPerson) { PersonEditor(person: nil) }
        }
    }
}

struct PersonDetailView: View {
    @Environment(Store.self) private var store
    let personID: UUID
    @State private var editingPerson = false
    @State private var editingPlan: SendPlan?

    var body: some View {
        if let person = store.person(personID) {
            List {
                Section {
                    VStack(spacing: 8) {
                        Avatar(person: person, size: 72)
                        Text(person.name).font(.title2.bold())
                        if !person.phone.isEmpty {
                            Text(person.phone).foregroundStyle(.secondary)
                        }
                        Button {
                            let plan = store.plans(for: person).first
                            store.pendingSend = SendRequest(personID: person.id,
                                                            phrase: plan?.phrase ?? Phrases.all[0],
                                                            replyWindowMinutes: plan?.replyWindowMinutes ?? 180)
                        } label: {
                            Label("Purpose them now", systemImage: "hand.raised.fill")
                        }
                        .buttonStyle(.borderedProminent)
                        .padding(.top, 6)
                    }
                    .frame(maxWidth: .infinity)
                }
                .listRowBackground(Color.clear)

                Section("Purpose schedules") {
                    ForEach(store.plans(for: person)) { plan in
                        Button { editingPlan = plan } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("\(plan.phrase) on purpose").foregroundStyle(Color.primary)
                                    Text("\(plan.scheduleText) · purpose back in \(ReplyWindow.label(plan.replyWindowMinutes))")
                                        .font(.caption).foregroundStyle(Color.secondary)
                                }
                                Spacer()
                                Toggle("Active", isOn: Binding(
                                    get: { plan.isActive },
                                    set: { var p = plan; p.isActive = $0; store.save(p) }
                                ))
                                .labelsHidden()
                            }
                        }
                    }
                    .onDelete { offsets in
                        let list = store.plans(for: person)
                        offsets.forEach { store.delete(list[$0]) }
                    }
                    Button {
                        editingPlan = SendPlan(personID: person.id)
                    } label: {
                        Label("Add schedule", systemImage: "plus")
                    }
                }

                let history = store.messages(for: person)
                if !history.isEmpty {
                    Section("History") {
                        ForEach(history) { message in
                            VStack(alignment: message.direction == .sent ? .trailing : .leading, spacing: 4) {
                                PhraseBubble(text: Phrases.line(from: message.direction == .sent ? store.senderName : person.name, message.phrase),
                                             outgoing: message.direction == .sent)
                                if let reply = message.reply {
                                    PhraseBubble(text: reply, outgoing: message.direction == .received)
                                }
                                Text(message.date, format: .dateTime.month().day().hour().minute())
                                    .font(.caption2).foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: message.direction == .sent ? .trailing : .leading)
                            .listRowSeparator(.hidden)
                        }
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { Button("Edit") { editingPerson = true } }
            .sheet(isPresented: $editingPerson) { PersonEditor(person: person) }
            .sheet(item: $editingPlan) { PlanEditor(plan: $0) }
        } else {
            ContentUnavailableView("Removed", systemImage: "person.slash")
        }
    }
}

struct PersonEditor: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    let original: Person?
    @State private var person: Person
    @State private var schedule = true
    @State private var plan: SendPlan

    init(person: Person?) {
        original = person
        let p = person ?? Person(name: "", phone: "")
        _person = State(initialValue: p)
        _plan = State(initialValue: SendPlan(personID: p.id))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $person.name)
                        .textContentType(.name)
                    TextField("Phone number", text: $person.phone)
                        .keyboardType(.phonePad)
                        .textContentType(.telephoneNumber)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(Person.emojis, id: \.self) { emoji in
                                Text(emoji)
                                    .font(.title2)
                                    .frame(width: 40, height: 40)
                                    .background(person.emoji == emoji ? Color.accentColor.opacity(0.25) : .clear, in: Circle())
                                    .onTapGesture { person.emoji = emoji }
                            }
                        }
                    }
                }

                if original == nil {
                    Section {
                        Toggle("Purpose them on a schedule", isOn: $schedule)
                    }
                    if schedule {
                        PlanFields(plan: $plan)
                    }
                } else {
                    Section {
                        Button("Stop purposing \(person.name)", role: .destructive) {
                            store.delete(person)
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle(original == nil ? "New purposee" : "Edit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        store.save(person)
                        if original == nil && schedule { store.save(plan) }
                        dismiss()
                    }
                    .disabled(person.name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

struct PlanEditor: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State var plan: SendPlan

    var body: some View {
        NavigationStack {
            Form {
                PlanFields(plan: $plan)
                if store.plans.contains(where: { $0.id == plan.id }) {
                    Section {
                        Button("Delete schedule", role: .destructive) {
                            store.delete(plan)
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle("Purpose schedule")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        var p = plan
                        // Editing the timing restarts it from now, so a past time today isn't instantly due.
                        p.createdAt = .now
                        p.isActive = true
                        store.save(p)
                        dismiss()
                    }
                    .disabled(plan.phrase.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}
