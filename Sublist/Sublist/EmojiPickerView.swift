import SwiftUI

private struct EmojiSection {
    let title: String
    let emojis: [String]
}

private let sections: [EmojiSection] = [
    EmojiSection(title: "Video & Streaming", emojis: ["📺", "🎬", "🎥", "🍿", "📽️", "🎞️"]),
    EmojiSection(title: "Music & Audio",     emojis: ["🎵", "🎶", "🎧", "🎸", "🎹", "🎤"]),
    EmojiSection(title: "Gaming",            emojis: ["🎮", "🕹️", "👾", "🎯", "🏆", "🃏"]),
    EmojiSection(title: "Books & News",      emojis: ["📚", "📰", "📖", "🗞️", "📝", "✏️"]),
    EmojiSection(title: "Productivity",      emojis: ["💼", "📋", "🗂️", "✅", "📌", "📎"]),
    EmojiSection(title: "Fitness",           emojis: ["💪", "🏋️", "🧘", "🏃", "🚴", "⚽"]),
    EmojiSection(title: "Health",            emojis: ["❤️", "🩺", "💊", "🧬", "🏥", "🩹"]),
    EmojiSection(title: "Education",         emojis: ["🎓", "📐", "🔬", "🧪", "🏫", "📊"]),
    EmojiSection(title: "Tech & Software",   emojis: ["💻", "📱", "🖥️", "⌨️", "🔧", "⚙️"]),
    EmojiSection(title: "Cloud & Storage",   emojis: ["☁️", "💾", "🗄️", "📡", "🔄", "🗃️"]),
    EmojiSection(title: "Finance",           emojis: ["💰", "💳", "📊", "💹", "🏦", "💵"]),
    EmojiSection(title: "Security & VPN",    emojis: ["🔒", "🛡️", "🔐", "🔑", "🕵️", "🔏"]),
    EmojiSection(title: "Communication",     emojis: ["💬", "📧", "📞", "🗣️", "📲", "🤝"]),
    EmojiSection(title: "Food & Delivery",   emojis: ["🍕", "🥡", "🛵", "🍔", "🥗", "🍱"]),
    EmojiSection(title: "Shopping",          emojis: ["🛍️", "🛒", "📦", "🎁", "🏪", "🏷️"]),
    EmojiSection(title: "Travel",            emojis: ["✈️", "🏨", "🗺️", "🧳", "🚂", "🏖️"]),
]

struct EmojiPickerView: View {
    @Binding var selectedEmoji: String
    @Environment(\.dismiss) private var dismiss

    private let columns = Array(repeating: GridItem(.flexible()), count: 6)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    ForEach(sections, id: \.title) { section in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(section.title)
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 16)

                            LazyVGrid(columns: columns, spacing: 4) {
                                ForEach(section.emojis, id: \.self) { emoji in
                                    Button {
                                        selectedEmoji = emoji
                                        dismiss()
                                    } label: {
                                        Text(emoji)
                                            .font(.system(size: 30))
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 6)
                                            .background(
                                                selectedEmoji == emoji
                                                    ? Color.accentColor.opacity(0.15)
                                                    : Color.clear
                                            )
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 12)
                        }
                    }
                }
                .padding(.vertical, 12)
            }
            .navigationTitle("Choose Icon")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
