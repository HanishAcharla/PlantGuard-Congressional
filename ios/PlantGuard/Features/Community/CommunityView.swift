import SwiftData
import SwiftUI

struct CommunityView: View {
    private enum Filter: Hashable {
        case all, mine, questions, disease(Disease)
        var label: String {
            switch self {
            case .all: "All"
            case .mine: "Mine"
            case .questions: "Questions"
            case .disease(let d): d.shortName
            }
        }
    }
    private enum Sort: String, CaseIterable { case top = "Top", new = "New" }

    @Query(sort: \CommunityNote.createdAt, order: .reverse) private var notes: [CommunityNote]
    @State private var filter: Filter = .all
    @State private var sort: Sort = .new
    @State private var search = ""
    @State private var composing = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                filters
                if visible.isEmpty {
                    GlassCard {
                        EmptyStateView(symbol: "bubble.left.and.bubble.right", title: "Nothing here yet",
                                       message: filter == .mine ? "Share what you're seeing in your orchard." : "Try another filter.")
                    }
                } else {
                    LazyVStack(spacing: 14) {
                        ForEach(visible) { note in
                            NavigationLink(value: Route.note(note.id)) { NoteCard(note: note) }
                                .buttonStyle(PressableStyle())
                        }
                    }
                }
                Label("Sample community — posts from fictional growers, stored on this device. Your own notes are saved locally.", systemImage: "info.circle")
                    .font(.system(size: 11)).foregroundStyle(Theme.textTertiary)
                    .padding(.top, 6)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
        }
        .searchable(text: $search, placement: .navigationBarDrawer(displayMode: .automatic), prompt: "Search notes")
        .tabBarSafeArea()
        .screenBackground()
        .navigationTitle("")
        .sheet(isPresented: $composing) { ComposeNoteView() }
    }

    private var header: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Grower network").kickerStyle()
                Text("Community").font(.display(34)).foregroundStyle(Theme.textPrimary)
            }
            Spacer()
            Button { composing = true } label: {
                Label("Post", systemImage: "square.and.pencil")
                    .font(.system(size: 14, weight: .semibold))
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .foregroundStyle(.white)
                    .background(Capsule().fill(Theme.rustGradient))
            }
            .buttonStyle(PressableStyle())
        }
    }

    private var filters: some View {
        VStack(alignment: .leading, spacing: 10) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach([Filter.all, .questions, .mine], id: \.self) { f in
                        FilterChip(title: f.label, isOn: filter == f) { filter = f }
                    }
                    ForEach(Disease.diseases) { d in
                        FilterChip(title: d.shortName, color: d.color, isOn: filter == .disease(d)) { filter = .disease(d) }
                    }
                }
            }
            .scrollClipDisabled()
            HStack(spacing: 4) {
                ForEach(Sort.allCases, id: \.self) { s in
                    Button {
                        Haptics.tap()
                        withAnimation(.snappy) { sort = s }
                    } label: {
                        Text(s.rawValue).font(.system(size: 12, weight: .semibold))
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .foregroundStyle(sort == s ? Theme.textPrimary : Theme.textTertiary)
                            .background(Capsule().fill(sort == s ? Theme.parchment.opacity(0.1) : .clear))
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
                Text("\(visible.count) notes").font(.system(size: 12)).foregroundStyle(Theme.textTertiary)
            }
        }
    }

    private var visible: [CommunityNote] {
        var list = notes.filter { note in
            switch filter {
            case .all: true
            case .mine: note.isMine
            case .questions: note.tags.contains("question") || note.title.hasSuffix("?")
            case .disease(let d): note.disease == d
            }
        }
        if !search.isEmpty {
            list = list.filter { $0.title.localizedCaseInsensitiveContains(search) || $0.body.localizedCaseInsensitiveContains(search)
                || $0.tags.contains { $0.localizedCaseInsensitiveContains(search) } }
        }
        if sort == .top { list.sort { $0.upvotes > $1.upvotes } }
        return list
    }
}

struct NoteCard: View {
    @Bindable var note: CommunityNote

    var body: some View {
        GlassCard(padding: 16, cornerRadius: 24) {
            VStack(alignment: .leading, spacing: 12) {
                NoteAuthorRow(note: note)
                Text(note.title).font(.display(19)).foregroundStyle(Theme.textPrimary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Text(note.body).font(.system(size: 14)).foregroundStyle(Theme.textSecondary)
                    .lineLimit(3).multilineTextAlignment(.leading)
                HStack(spacing: 8) {
                    if let d = note.disease { DiseaseBadge(disease: d, compact: true) }
                    ForEach(note.tags.filter { $0 != "question" }.prefix(2), id: \.self) { tag in
                        Text("#\(tag)").font(.system(size: 11, weight: .medium)).foregroundStyle(Theme.textTertiary)
                    }
                    Spacer()
                }
                HStack(spacing: 18) {
                    UpvoteButton(note: note)
                    Label("\(note.comments.count)", systemImage: "bubble.left").font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Theme.textTertiary)
                    if let code = note.linkedTreeCode {
                        Label(code, systemImage: "tree").font(.mono(12)).foregroundStyle(Theme.sage)
                    }
                    Spacer()
                }
            }
        }
    }
}

struct NoteAuthorRow: View {
    let note: CommunityNote

    var body: some View {
        HStack(spacing: 10) {
            InitialsAvatar(name: note.authorName, hue: note.avatarHue, size: 36)
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 5) {
                    Text(note.authorName).font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.textPrimary)
                    if note.authorRole.contains("Extension") {
                        Image(systemName: "checkmark.seal.fill").font(.system(size: 11)).foregroundStyle(Color(hex: 0x6FA8DC))
                    }
                }
                Text("\(note.authorRole) · \(note.authorRegion)").font(.system(size: 11)).foregroundStyle(Theme.textTertiary)
            }
            Spacer()
            Text(note.createdAt.relativeShort).font(.system(size: 12)).foregroundStyle(Theme.textTertiary)
        }
    }
}

struct UpvoteButton: View {
    @Bindable var note: CommunityNote

    var body: some View {
        Button {
            Haptics.tap()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                note.hasUpvoted.toggle()
                note.upvotes += note.hasUpvoted ? 1 : -1
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: note.hasUpvoted ? "arrowshape.up.fill" : "arrowshape.up")
                    .symbolEffect(.bounce, value: note.hasUpvoted)
                Text("\(note.upvotes)").contentTransition(.numericText())
            }
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(note.hasUpvoted ? Theme.rustLight : Theme.textTertiary)
        }
        .buttonStyle(.plain)
    }
}

struct NoteDetailView: View {
    @Bindable var note: CommunityNote
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @AppStorage("growerName") private var growerName = ""
    @State private var reply = ""
    @FocusState private var replyFocused: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                NoteAuthorRow(note: note)
                Text(note.title).font(.display(28)).foregroundStyle(Theme.textPrimary)
                if let d = note.disease {
                    NavigationLink(value: Route.disease(d)) { DiseaseBadge(disease: d) }
                }
                Text(note.body).font(.system(size: 16)).foregroundStyle(Theme.textPrimary.opacity(0.88)).lineSpacing(4)
                HStack(spacing: 8) {
                    ForEach(note.tags, id: \.self) { tag in
                        Text("#\(tag)").font(.system(size: 12, weight: .medium))
                            .padding(.horizontal, 10).padding(.vertical, 5)
                            .foregroundStyle(Theme.textSecondary)
                            .background(Capsule().fill(Theme.parchment.opacity(0.07)))
                    }
                }
                if let code = note.linkedTreeCode {
                    NavigationLink(value: Route.tree(code)) {
                        Label("Linked tree \(code)", systemImage: "tree.fill").font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.sage)
                    }
                }
                HStack { UpvoteButton(note: note); Spacer() }

                Divider().overlay(Theme.hairline)
                Text("\(note.comments.count) replies").kickerStyle(Theme.textTertiary)
                ForEach(note.sortedComments) { comment in
                    HStack(alignment: .top, spacing: 10) {
                        InitialsAvatar(name: comment.authorName, hue: Double(abs(comment.authorName.hashValue) % 100) / 100, size: 30)
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(comment.authorName).font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.textPrimary)
                                Text(comment.createdAt.relativeShort).font(.system(size: 11)).foregroundStyle(Theme.textTertiary)
                            }
                            Text(comment.body).font(.system(size: 14)).foregroundStyle(Theme.textSecondary)
                        }
                        Spacer()
                    }
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Theme.parchment.opacity(comment.isMine ? 0.08 : 0.04)))
                }
                if note.isMine {
                    Button(role: .destructive) {
                        context.delete(note)
                        dismiss()
                    } label: { Label("Delete note", systemImage: "trash") }
                        .font(.system(size: 14))
                        .padding(.top, 10)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .safeAreaInset(edge: .bottom) {
            HStack(spacing: 10) {
                TextField("Add a reply", text: $reply, axis: .vertical)
                    .lineLimit(1...4)
                    .focused($replyFocused)
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background(Capsule().fill(Theme.parchment.opacity(0.08)))
                Button {
                    let text = reply.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !text.isEmpty else { return }
                    let comment = NoteComment(authorName: growerName.isEmpty ? "You" : growerName, body: text, createdAt: .now, isMine: true)
                    context.insert(comment)
                    comment.note = note
                    reply = ""
                    replyFocused = false
                    Haptics.success()
                } label: {
                    Image(systemName: "arrow.up").font(.system(size: 15, weight: .bold)).foregroundStyle(.white)
                        .frame(width: 38, height: 38).background(Circle().fill(Theme.rustGradient))
                }
                .disabled(reply.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial)
            .padding(.bottom, 80)
        }
        .screenBackground()
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct ComposeNoteView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @AppStorage("growerName") private var growerName = ""
    @Query(sort: \Tree.code) private var trees: [Tree]
    @State private var title = ""
    @State private var text = ""
    @State private var disease: Disease?
    @State private var isQuestion = false
    @State private var tags = ""
    @State private var treeCode: String?
    @State private var pickingTree = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Title", text: $title)
                    TextField("What are you seeing?", text: $text, axis: .vertical).lineLimit(4...10)
                }
                .listRowBackground(Theme.parchment.opacity(0.06))
                Section("Details") {
                    Picker("Disease", selection: $disease) {
                        Text("None").tag(Disease?.none)
                        ForEach(Disease.allCases) { Text($0.name).tag(Disease?.some($0)) }
                    }
                    Toggle("This is a question", isOn: $isQuestion)
                    TextField("Tags, comma separated", text: $tags)
                    Button { pickingTree = true } label: {
                        HStack {
                            Text("Link a tree").foregroundStyle(Theme.textPrimary)
                            Spacer()
                            Text(treeCode ?? "None").foregroundStyle(Theme.textTertiary)
                        }
                    }
                }
                .listRowBackground(Theme.parchment.opacity(0.06))
                Section {
                    TextField("Your name", text: $growerName)
                } footer: {
                    Text("Notes are stored on this device.")
                }
                .listRowBackground(Theme.parchment.opacity(0.06))
            }
            .scrollContentBackground(.hidden)
            .background(AppBackground())
            .navigationTitle("New note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Post") { post() }.disabled(title.trimmingCharacters(in: .whitespaces).isEmpty || text.isEmpty)
                }
            }
            .sheet(isPresented: $pickingTree) { TreePickerView(selection: $treeCode) }
        }
    }

    private func post() {
        var tagList = tags.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces).lowercased() }.filter { !$0.isEmpty }
        if isQuestion { tagList.insert("question", at: 0) }
        let note = CommunityNote(authorName: growerName.isEmpty ? "You" : growerName, authorRole: "Grower", authorRegion: "Your orchard",
                                 avatarHue: 0.07, title: title, body: text, disease: disease, tags: tagList, createdAt: .now, upvotes: 0, isMine: true)
        note.linkedTreeCode = treeCode
        context.insert(note)
        Haptics.success()
        dismiss()
    }
}
