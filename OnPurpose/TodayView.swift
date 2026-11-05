import SwiftUI

struct TodayView: View {
    @Environment(Store.self) private var store
    @State private var addingPerson = false
    @State private var editingName = false

    var body: some View {
        @Bindable var store = store
        NavigationStack {
            List {
                if store.myName.trimmingCharacters(in: .whitespaces).isEmpty {
                    Section {
                        Button {
                            editingName = true
                        } label: {
                            Label("Add your name so people know who purposed them", systemImage: "signature")
                        }
                    }
                }

                if store.people.isEmpty {
                    emptyState
                }

                if !store.duePlans.isEmpty {
                    Section("Ready to purpose") {
                        ForEach(store.duePlans) { plan in
                            HStack(spacing: 12) {
                                Avatar(person: store.person(plan.personID))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(store.person(plan.personID)?.name ?? "Someone").font(.headline)
                                    Text("\(plan.phrase) on purpose").font(.subheadline).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Button("Purpose 'em") {
                                    store.pendingSend = SendRequest(personID: plan.personID, phrase: plan.phrase,
                                                                    replyWindowMinutes: plan.replyWindowMinutes,
                                                                    planID: plan.id)
                                }
                                .buttonStyle(.borderedProminent)
                            }
                        }
                    }
                }

                if !store.awaitingReply.isEmpty {
                    Section {
                        ForEach(store.awaitingReply) { message in
                            HStack(spacing: 12) {
                                Avatar(person: store.person(message.personID), size: 32)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(store.person(message.personID)?.name ?? "Someone").font(.subheadline.weight(.semibold))
                                    Group {
                                        if message.isOverdue(now: store.now) {
                                            Text("Leaving you on read · purposed \(message.date, format: .relative(presentation: .named))")
                                        } else {
                                            Text("Gets nagged \(message.replyDueAt, format: .relative(presentation: .named))")
                                        }
                                    }
                                    .font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Button("They did") { store.markReplied(message) }
                                    .buttonStyle(.bordered)
                                    .font(.caption)
                            }
                        }
                    } header: {
                        Text("Waiting to get purposed back")
                    }
                }

                if !store.upcoming.isEmpty {
                    Section("Coming up") {
                        ForEach(store.upcoming, id: \.plan.id) { item in
                            HStack(spacing: 12) {
                                Avatar(person: store.person(item.plan.personID), size: 32)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(store.person(item.plan.personID)?.name ?? "Someone").font(.subheadline.weight(.semibold))
                                    Text("\(item.plan.phrase) on purpose").font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(item.date, format: .dateTime.weekday(.abbreviated).hour().minute())
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                if !store.people.isEmpty && store.duePlans.isEmpty && store.upcoming.isEmpty && store.awaitingReply.isEmpty {
                    Section {
                        Text("Nobody's scheduled to be purposed. Tragic. Open People to fix it.")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("OnPurpose")
            .toolbar {
                Button { editingName = true } label: { Image(systemName: "signature") }
            }
            .alert("Who's doing the purposing?", isPresented: $editingName) {
                TextField("Your name", text: $store.myName)
                Button("Done") {}
            } message: {
                Text("Shows up as “\(store.senderName) wants you to…”")
            }
            .sheet(isPresented: $addingPerson) { PersonEditor(person: nil) }
        }
    }

    private var emptyState: some View {
        Section {
            VStack(spacing: 14) {
                PhraseBubble(text: Phrases.text(from: store.senderName, Phrases.all[0], replyWindowMinutes: 180))
                Text("It's a chain text, but for good days. Pick your people, pick how often, and OnPurpose tells you when to strike.")
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                Button("Pick someone to purpose") { addingPerson = true }
                    .buttonStyle(.borderedProminent)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
        }
    }
}
