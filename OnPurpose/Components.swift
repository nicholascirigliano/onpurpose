import SwiftUI

struct Avatar: View {
    let person: Person?
    var size: CGFloat = 40

    var body: some View {
        Text(person?.emoji ?? "🙂")
            .font(.system(size: size * 0.5))
            .frame(width: size, height: size)
            .background(Color.accentColor.opacity(0.15), in: Circle())
    }
}

/// The message itself, styled like a text bubble.
struct PhraseBubble: View {
    let text: String
    var outgoing = true

    var body: some View {
        Text(text)
            .font(.body.weight(.medium))
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .foregroundStyle(outgoing ? .white : .primary)
            .background(outgoing ? Color.accentColor : Color(.secondarySystemFill),
                        in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

/// Phrase, schedule and reply-window fields shared by the person and plan editors.
struct PlanFields: View {
    @Environment(Store.self) private var store
    @Binding var plan: SendPlan

    var body: some View {
        Section {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(store.senderName) wants you to…").font(.caption).foregroundStyle(.secondary)
                TextField("have a good day", text: $plan.phrase)
                    .font(.body.weight(.medium))
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    ForEach(Phrases.all, id: \.self) { phrase in
                        Button(phrase) { plan.phrase = phrase }
                            .buttonStyle(.bordered)
                            .tint(plan.phrase == phrase ? .accentColor : .secondary)
                            .font(.footnote)
                    }
                }
            }
            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 8, trailing: 16))
            PhraseBubble(text: Phrases.text(from: store.senderName, plan.phrase,
                                            replyWindowMinutes: plan.replyWindowMinutes))
                .frame(maxWidth: .infinity, alignment: .trailing)
        } header: {
            Text("The purpose")
        } footer: {
            Text("…on purpose ✋. Pick one or write your own.")
        }

        Section("When") {
            Picker("Repeat", selection: $plan.repeatRule) {
                ForEach(RepeatRule.allCases) { Text($0.label).tag($0) }
            }
            .pickerStyle(.segmented)

            if plan.repeatRule == .once {
                DatePicker("Send on", selection: $plan.time, in: Date.now...)
            } else {
                DatePicker("Time", selection: $plan.time, displayedComponents: .hourAndMinute)
            }
            if plan.repeatRule == .weekly {
                Picker("Day", selection: $plan.weekday) {
                    ForEach(1...7, id: \.self) { Text(Calendar.current.weekdaySymbols[$0 - 1]).tag($0) }
                }
            }
        }

        Section {
            Picker("They must purpose back within", selection: $plan.replyWindowMinutes) {
                ForEach(ReplyWindow.options, id: \.minutes) { Text($0.label).tag($0.minutes) }
            }
        } header: {
            Text("The chain")
        } footer: {
            Text("If they don't purpose you back in time, they get nagged.")
        }
    }
}
