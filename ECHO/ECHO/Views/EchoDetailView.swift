import SwiftData
import SwiftUI
#if os(iOS)
import AudioToolbox
import AVFAudio
import UIKit
#endif

struct EchoDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query(sort: \EchoMemoryStoredLink.createdAt, order: .reverse) private var storedLinks: [EchoMemoryStoredLink]

    let memory: EchoMemory
    let candidateMemories: [EchoMemory]

    @State private var relatedLinks: [EchoMemoryLink] = []
    @State private var recommendations: [EchoRecommendation] = []
    @State private var isLoadingRelatedLinks = false
    @State private var isLoadingRecommendations = false
    @State private var isEditing = false
    @State private var isSaving = false
    @State private var title: String
    @State private var creator: String
    @State private var category: EchoCategory
    @State private var emotion: EchoEmotion
    @State private var memoryText: String
    @State private var year: String
    @State private var discoveryStatus: EchoDiscoveryStatus
    @State private var deleteError: EchoUserFacingError?
    @State private var audioPlaybackError: String?
    @State private var audioPlayer: AVAudioPlayer?
    @State private var isAudioPlaying = false
    @State private var isShowingUndoBubble = false
    @State private var detailStampScale: CGFloat = 1
    @State private var detailStampOpacity: Double = 1
    @State private var pendingDismissTask: Task<Void, Never>?

    private let persistenceService = EchoMemoryPersistenceService()
    private let linkService = EchoMemoryLinkService()
    private let recommendationService = EchoRecommendationService()

    init(memory: EchoMemory, candidateMemories: [EchoMemory] = [], startsEditing: Bool = false) {
        self.memory = memory
        self.candidateMemories = candidateMemories
        _title = State(initialValue: memory.title)
        _creator = State(initialValue: memory.creator ?? "")
        _category = State(initialValue: memory.category)
        _emotion = State(initialValue: memory.emotion)
        _memoryText = State(initialValue: memory.memory)
        _year = State(initialValue: memory.year ?? "")
        _discoveryStatus = State(initialValue: memory.discoveryStatus)
        _isEditing = State(initialValue: startsEditing)
    }

    private var displayedRelatedLinks: [EchoMemoryLink] {
        linkService.displayedLinks(from: relatedLinks)
    }

    private var relatedLinkRefreshID: String {
        let memoryIDs = candidateMemories.map(\.id.uuidString).joined(separator: ",")
        let linkIDs = storedLinks.map(\.id.uuidString).joined(separator: ",")
        return memory.id.uuidString + "|" + memoryIDs + "|" + linkIDs
    }

    private var recommendationRefreshID: String {
        let memoryIDs = candidateMemories.map { memory in
            memory.id.uuidString + ":" + memory.discoveryStatus.rawValue
        }.joined(separator: ",")
        return memory.id.uuidString + "|" + memory.discoveryStatus.rawValue + "|" + memoryIDs
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        topBar
                        titleBlock
                        aboutSection
                        audioRecordingSection
                        metadataSection
                        relatedEchoesSection
                        recommendationsSection
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, 18)
                    .padding(.bottom, 28)
                }

                bottomActionBar
            }

            if isShowingUndoBubble {
                undoBubble
                    .padding(20)
                    .padding(.bottom, 72)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isShowingUndoBubble)
        .background(Color.white)
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .alert(item: $deleteError) { error in
            Alert(
                title: Text("Echo could not be moved"),
                message: Text(error.message),
                dismissButton: .default(Text("OK"))
            )
        }
        .task(id: relatedLinkRefreshID) {
            await loadRelatedLinks()
        }
        .task(id: recommendationRefreshID) {
            await loadRecommendations()
        }
        .onChange(of: memory.unlockedAt) { oldValue, newValue in
            if oldValue == nil, newValue != nil {
                playDetailStampImpact()
            } else if oldValue != nil, newValue == nil {
                playDetailStampRemoval()
            }
        }
        .onDisappear {
            pendingDismissTask?.cancel()
            stopAudioPlayback()
        }
    }

    private var topBar: some View {
        VStack(spacing: 8) {
            HStack(alignment: .center) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .medium))
                        .frame(width: 34, height: 34)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Return")
                .accessibilityHint("Double tap to go back to the previous screen.")

                Spacer()

                Text("Echo Archive")
                    .font(.system(size: 12, weight: .semibold))
                    .textCase(.uppercase)
                    .tracking(1.2)

                Spacer()

                Button {
                    if isEditing {
                        saveInlineEdits()
                    } else {
                        beginInlineEditing()
                    }
                } label: {
                    Text(isEditing ? "Save" : "Edit")
                        .font(.system(size: 12, weight: .semibold))
                        .textCase(.uppercase)
                        .tracking(0.8)
                        .frame(width: 42, height: 34)
                }
                .buttonStyle(.plain)
                .disabled(memory.deletedAt != nil || isSaving)
            }

            rule()
        }
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 0) {
            if isEditing {
                editorialTextField("Title", text: $title, size: 30)
                    .textInputAutocapitalization(.words)
                    .padding(.top, 14)
                    .padding(.bottom, 8)

                editorialTextField("Creator", text: $creator, size: 14)
                    .textInputAutocapitalization(.words)
                    .padding(.bottom, 12)
            } else {
                Text(memory.title)
                    .font(.system(size: 30, weight: .regular))
                    .textCase(.uppercase)
                    .tracking(0.2)
                    .foregroundStyle(EchoStyle.ink)
                    .lineLimit(4)
                    .minimumScaleFactor(0.72)
                    .padding(.top, 14)
                    .padding(.bottom, 8)

                if let creator = memory.creator, !creator.isEmpty {
                    Text(creator)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(EchoStyle.ink)
                        .padding(.bottom, 12)
                }
            }

            if let unlockedAt = memory.unlockedAt, !isEditing {
                HStack {
                    Spacer()

                    DateStampView(
                        date: unlockedAt,
                        emotion: memory.emotion,
                        compact: false,
                        rotationDegrees: detailStampRotation
                    )
                    .scaleEffect(detailStampScale)
                    .opacity(detailStampOpacity)
                    .offset(detailStampOffset)
                    .padding(.bottom, 12)
                    .transition(.scale(scale: 1.18).combined(with: .opacity))
                }
            } else if !isEditing {
                Spacer(minLength: 28)
            }

            rule()
        }
    }

    private func editorialTextField(_ placeholder: String, text: Binding<String>, size: CGFloat) -> some View {
        TextField(placeholder, text: text, axis: .vertical)
            .font(.system(size: size, weight: .regular))
            .textCase(size >= 24 ? .uppercase : nil)
            .tracking(size >= 24 ? 0.2 : 0)
            .foregroundStyle(EchoStyle.ink)
            .textFieldStyle(.plain)
            .padding(.vertical, 2)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(EchoStyle.border.opacity(0.28))
                    .frame(height: 1)
            }
    }

    private func editorialTextEditor(_ label: String, text: Binding<String>, minHeight: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .textCase(.uppercase)
                .tracking(0.8)
                .foregroundStyle(EchoStyle.mutedInk)

            TextEditor(text: text)
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(EchoStyle.ink)
                .scrollContentBackground(.hidden)
                .frame(minHeight: minHeight)
                .accessibilityLabel(label)
                .accessibilityHint("Edit this text before saving the Echo.")
                .padding(8)
                .overlay(
                    Rectangle()
                        .stroke(EchoStyle.border.opacity(0.34), lineWidth: 1)
                )
        }
        .animation(.spring(response: 0.24, dampingFraction: 0.62), value: memory.unlockedAt != nil)
    }

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            editorialSectionHeader("About")

            VStack(alignment: .leading, spacing: 14) {
                if isEditing {
                    editorialTextEditor("Memory", text: $memoryText, minHeight: 116)
                } else {
                    Text(memory.memory)
                        .font(.system(size: 15, weight: .regular))
                        .lineSpacing(1.5)
                        .foregroundStyle(EchoStyle.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.vertical, 18)

            rule()
        }
    }

    @ViewBuilder
    private var audioRecordingSection: some View {
        if memory.audioFileName != nil {
            VStack(alignment: .leading, spacing: 0) {
                editorialSectionHeader("Voice")

                audioBubble
                    .padding(.vertical, 16)

                if let audioPlaybackError {
                    Text(audioPlaybackError)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(EchoStyle.ink.opacity(0.66))
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.bottom, 14)
                }

                rule()
            }
        }
    }

    private var audioBubble: some View {
        HStack(spacing: 12) {
            Button {
                toggleAudioPlayback()
            } label: {
                Image(systemName: isAudioPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(hasPlayableAudio ? Color.white : EchoStyle.mutedInk)
                    .frame(width: 36, height: 36)
                    .background(hasPlayableAudio ? EchoStyle.ink : EchoStyle.surfaceSecondary)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .disabled(!hasPlayableAudio)
            .accessibilityLabel(isAudioPlaying ? "Pause voice recording" : "Play voice recording")
            .accessibilityValue(formattedAudioDuration)
            .accessibilityHint("Double tap to listen to the original spoken Echo.")

            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 3) {
                    ForEach(audioWaveformBars.indices, id: \.self) { index in
                        Capsule()
                            .fill(audioWaveformColor(for: index))
                            .frame(width: 3, height: audioWaveformBars[index])
                    }
                }
                .frame(height: 24, alignment: .center)
                .accessibilityHidden(true)

                Text(hasPlayableAudio ? formattedAudioDuration : "Recording unavailable")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(EchoStyle.ink.opacity(0.68))
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            Image(systemName: "waveform")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(EchoStyle.mutedInk)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(EchoStyle.surfaceSecondary.opacity(0.72))
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(EchoStyle.border.opacity(0.34), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 22))
    }

    private var hasPlayableAudio: Bool {
        EchoAudioFileService.fileExists(fileName: memory.audioFileName)
    }

    private var formattedAudioDuration: String {
        guard let duration = memory.audioDuration, duration.isFinite, duration > 0 else {
            return "Recorded voice"
        }

        let totalSeconds = Int(duration.rounded())
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private var audioWaveformBars: [CGFloat] {
        [8, 14, 20, 12, 18, 24, 10, 16, 22, 13, 19, 9, 15, 21, 11, 17, 23, 12]
    }

    private func audioWaveformColor(for index: Int) -> Color {
        guard hasPlayableAudio else { return EchoStyle.mutedInk.opacity(0.24) }
        if isAudioPlaying {
            return index.isMultiple(of: 2) ? EchoStyle.ink : EchoStyle.ink.opacity(0.58)
        }
        return EchoStyle.ink.opacity(0.38)
    }

    private func toggleAudioPlayback() {
        if isAudioPlaying {
            audioPlayer?.pause()
            isAudioPlaying = false
            return
        }

        do {
            guard let fileName = memory.audioFileName else { return }
            let url = try EchoAudioFileService.recordingURL(for: fileName)
            if audioPlayer == nil || audioPlayer?.url != url {
                audioPlayer = try AVAudioPlayer(contentsOf: url)
                audioPlayer?.prepareToPlay()
            }

            if let audioPlayer, audioPlayer.currentTime >= audioPlayer.duration {
                audioPlayer.currentTime = 0
            }

            audioPlaybackError = nil
            isAudioPlaying = audioPlayer?.play() == true
        } catch {
            audioPlaybackError = "Echo could not play this voice recording."
            isAudioPlaying = false
        }
    }

    private func stopAudioPlayback() {
        audioPlayer?.stop()
        audioPlayer = nil
        isAudioPlaying = false
    }

    private var metadataSection: some View {
        VStack(spacing: 0) {
            if isEditing {
                editableMetadataRow(
                    leftLabel: "Category",
                    leftContent: AnyView(categoryPicker),
                    rightLabel: "Emotion",
                    rightContent: AnyView(emotionPicker)
                )

                editableMetadataRow(
                    leftLabel: "Status",
                    leftContent: AnyView(statusPicker),
                    rightLabel: "Created",
                    rightContent: AnyView(staticMetadataValue(memory.createdAt.formatted(date: .numeric, time: .omitted)))
                )

                editableMetadataRow(
                    leftLabel: "Year",
                    leftContent: AnyView(metadataTextField("Year", text: $year)),
                    rightLabel: "Entry",
                    rightContent: AnyView(staticMetadataValue(memory.deletedAt == nil ? "Active" : "Deleted"))
                )
            } else {
                editorialInfoRow(
                    leftLabel: "Category",
                    leftValue: memory.category.title,
                    rightLabel: "Emotion",
                    rightValue: memory.emotion.title
                )

                editorialInfoRow(
                    leftLabel: "Status",
                    leftValue: memory.discoveryStatus.title,
                    rightLabel: "Created",
                    rightValue: memory.createdAt.formatted(date: .numeric, time: .omitted)
                )

                if let year = memory.year, !year.isEmpty {
                    editorialInfoRow(
                        leftLabel: "Year",
                        leftValue: year,
                        rightLabel: "Entry",
                        rightValue: memory.deletedAt == nil ? "Active" : "Deleted"
                    )
                }
            }
        }
    }

    @ViewBuilder
    private var relatedEchoesSection: some View {
        if isLoadingRelatedLinks {
            editorialTextSection(title: "Related Echoes", text: "Looking for meaningful connections...")
        } else if !displayedRelatedLinks.isEmpty {
            linkedSection(title: "Related Echoes", count: displayedRelatedLinks.count) {
                ForEach(displayedRelatedLinks) { link in
                    NavigationLink {
                        EchoDetailView(memory: link.target, candidateMemories: candidateMemories)
                    } label: {
                        relatedEchoRow(link)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Open related Echo, \(link.target.title)")
                    .accessibilityValue(link.reason)
                    .accessibilityHint("Double tap to open this connected Echo.")
                }
            }
        } else {
#if DEBUG
            editorialTextSection(
                title: "Related Echoes",
                text: relatedLinks.isEmpty ? "No links for this Echo yet. Use Rebuild Echo Links after loading samples, or create another related Echo." : "\(relatedLinks.count) stored link(s), but none reach the display score threshold yet."
            )
#endif
        }
    }

    @ViewBuilder
    private var recommendationsSection: some View {
        if isLoadingRecommendations {
            editorialTextSection(title: "Recommended Next", text: "Looking through your discovery queue...")
        } else if !recommendations.isEmpty {
            linkedSection(title: "Recommended Next", count: recommendations.count) {
                ForEach(recommendations) { recommendation in
                    NavigationLink {
                        EchoDetailView(memory: recommendation.target, candidateMemories: candidateMemories)
                    } label: {
                        recommendationRow(recommendation)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Open recommendation, \(recommendation.target.title)")
                    .accessibilityValue(recommendation.reason)
                    .accessibilityHint("Double tap to open this recommended Echo.")
                }
            }
        }
    }

    private var bottomActionBar: some View {
        HStack(spacing: 0) {
            if isEditing {
                Button {
                    cancelInlineEditing()
                } label: {
                    bottomActionLabel("Cancel")
                }
                .buttonStyle(.plain)
                .disabled(isSaving)
                .accessibilityLabel("Cancel editing")
                .accessibilityHint("Double tap to discard unsaved changes and leave edit mode.")

                verticalRule()

                Button {
                    saveInlineEdits()
                } label: {
                    bottomActionLabel(isSaving ? "Saving" : "Save")
                }
                .buttonStyle(.plain)
                .disabled(isSaving)
                .accessibilityLabel(isSaving ? "Saving Echo" : "Save Echo")
                .accessibilityHint("Double tap to save your edited Echo.")
            } else {
                Button {
                    moveMemoryToTrash()
                } label: {
                    bottomActionLabel("Delete")
                }
                .buttonStyle(.plain)
                .disabled(memory.deletedAt != nil)
                .accessibilityLabel("Move Echo to Recently Deleted")
                .accessibilityHint("Double tap to move this Echo to Recently Deleted. You can undo immediately.")

                verticalRule()

                Button {
                    dismiss()
                } label: {
                    bottomActionLabel("Return")
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Return")
                .accessibilityHint("Double tap to go back to the previous screen.")

                verticalRule()

                Button {
                    beginInlineEditing()
                } label: {
                    bottomActionLabel("Edit")
                }
                .buttonStyle(.plain)
                .disabled(memory.deletedAt != nil)
                .accessibilityLabel("Edit Echo")
                .accessibilityHint("Double tap to edit title, creator, memory, status, and metadata.")
            }
        }
        .frame(height: 72)
        .overlay(alignment: .top) { rule() }
        .background(Color.white.opacity(0.96))
    }

    private func bottomActionLabel(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 13, weight: .medium))
            .textCase(.uppercase)
            .tracking(0.7)
            .foregroundStyle(EchoStyle.ink)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func editorialSectionHeader(_ title: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Spacer(minLength: 28)

            Text(title)
                .font(.system(size: 20, weight: .regular))
                .textCase(.uppercase)
                .tracking(0.2)

            rule()
        }
    }

    private func editorialTextSection(title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            editorialSectionHeader(title)

            Text(text)
                .font(.system(size: 14, weight: .regular))
                .lineSpacing(1.5)
                .foregroundStyle(EchoStyle.ink.opacity(0.78))
                .fixedSize(horizontal: false, vertical: true)
                .padding(.vertical, 16)

            rule()
        }
    }

    private func linkedSection<Content: View>(title: String, count: Int, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            editorialSectionHeader(title)

#if DEBUG
            Text("\(count) shown")
                .font(.system(size: 10, weight: .semibold))
                .textCase(.uppercase)
                .tracking(0.8)
                .foregroundStyle(EchoStyle.mutedInk)
                .padding(.top, 10)
#endif

            VStack(spacing: 0) {
                content()
            }
            .padding(.top, 8)

            rule()
        }
    }

    private var categoryPicker: some View {
        Picker("Category", selection: $category) {
            ForEach(EchoCategory.allCases) { category in
                Text(category.title).tag(category)
            }
        }
        .pickerStyle(.menu)
        .tint(EchoStyle.ink)
        .accessibilityHint("Double tap to choose the cultural category for this Echo.")
    }

    private var emotionPicker: some View {
        Menu {
            ForEach(EchoEmotion.allCases) { option in
                Button(option.title) {
                    emotion = option
                }
            }
        } label: {
            Text(emotion.title)
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(EchoStyle.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
        }
        .tint(EchoStyle.ink)
        .accessibilityLabel("Emotion")
        .accessibilityValue(emotion.title)
        .accessibilityHint("Double tap to choose the emotion associated with this Echo.")
    }

    private var statusPicker: some View {
        Picker("Status", selection: $discoveryStatus) {
            ForEach(EchoDiscoveryStatus.allCases) { status in
                Text(status.title).tag(status)
            }
        }
        .pickerStyle(.menu)
        .tint(EchoStyle.ink)
        .accessibilityHint("Double tap to mark this Echo as discovered or not discovered.")
    }

    private func editableMetadataRow(leftLabel: String, leftContent: AnyView, rightLabel: String, rightContent: AnyView) -> some View {
        HStack(spacing: 0) {
            editableMetadataCell(label: leftLabel, leadingInset: 0) {
                leftContent
            }

            verticalRule()

            editableMetadataCell(label: rightLabel, leadingInset: 16) {
                rightContent
            }
        }
        .frame(minHeight: 50)
        .overlay(alignment: .bottom) { rule() }
    }

    private func editableMetadataCell<Content: View>(label: String, leadingInset: CGFloat, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .textCase(.uppercase)
                .tracking(0.45)
                .foregroundStyle(EchoStyle.ink)

            content()
                .font(.system(size: 13, weight: .regular))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 9)
        .padding(.leading, leadingInset)
        .padding(.trailing, 12)
    }

    private func metadataTextField(_ placeholder: String, text: Binding<String>) -> some View {
        TextField(placeholder, text: text)
            .font(.system(size: 13, weight: .regular))
            .foregroundStyle(EchoStyle.ink)
            .textFieldStyle(.plain)
            .accessibilityLabel(placeholder)
            .accessibilityHint("Edit this metadata field before saving the Echo.")
    }

    private func staticMetadataValue(_ value: String) -> some View {
        Text(value)
            .font(.system(size: 13, weight: .regular))
            .foregroundStyle(EchoStyle.ink.opacity(0.72))
    }

    private func editorialInfoRow(
        leftLabel: String,
        leftValue: String,
        rightLabel: String,
        rightValue: String,
        leftValueColor: Color = EchoStyle.ink,
        rightValueColor: Color = EchoStyle.ink
    ) -> some View {
        HStack(spacing: 0) {
            editorialInfoCell(label: leftLabel, value: leftValue, leadingInset: 0, valueColor: leftValueColor)

            verticalRule()

            editorialInfoCell(label: rightLabel, value: rightValue, leadingInset: 16, valueColor: rightValueColor)
        }
        .frame(minHeight: 46)
        .overlay(alignment: .bottom) { rule() }
    }

    private func editorialInfoCell(label: String, value: String, leadingInset: CGFloat, valueColor: Color) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .textCase(.uppercase)
                .tracking(0.45)
                .foregroundStyle(EchoStyle.ink)
                .frame(width: 72, alignment: .leading)

            Text(value)
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(valueColor)
                .lineLimit(2)
                .minimumScaleFactor(0.78)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 10)
        .padding(.leading, leadingInset)
        .padding(.trailing, 12)
    }

    private func recommendationRow(_ recommendation: EchoRecommendation) -> some View {
        editorialLinkRow(
            marker: recommendation.basis.title,
            title: recommendation.target.title,
            subtitle: recommendation.reason,
            debugText: "Score \(recommendation.score)"
        )
    }

    private func relatedEchoRow(_ link: EchoMemoryLink) -> some View {
        editorialLinkRow(
            marker: link.basis.title,
            title: link.target.title,
            subtitle: link.reason,
            debugText: "Score \(link.score)"
        )
    }

    private func editorialLinkRow(marker: String, title: String, subtitle: String, debugText: String) -> some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                Text(marker)
                    .font(.system(size: 10, weight: .semibold))
                    .textCase(.uppercase)
                    .tracking(0.6)
                    .foregroundStyle(EchoStyle.mutedInk)
                    .frame(width: 82, alignment: .leading)

                VStack(alignment: .leading, spacing: 5) {
                    Text(title)
                        .font(.system(size: 16, weight: .regular))
                        .textCase(.uppercase)
                        .tracking(0.15)
                        .foregroundStyle(EchoStyle.ink)
                        .lineLimit(2)

                    Text(subtitle)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(EchoStyle.ink.opacity(0.72))
                        .lineLimit(3)

#if DEBUG
                    Text(debugText)
                        .font(.system(size: 10, weight: .semibold))
                        .textCase(.uppercase)
                        .tracking(0.6)
                        .foregroundStyle(EchoStyle.mutedInk)
#endif
                }

                Spacer(minLength: 6)

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(EchoStyle.ink)
            }
            .padding(.vertical, 13)

            rule(opacity: 0.42)
        }
    }

    private var undoBubble: some View {
        HStack(spacing: 12) {
            Text("Moved to Recently Deleted")
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(.white)

            Spacer()

            Button("Undo") {
                restoreFromTrash()
            }
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.white)
            .accessibilityLabel("Undo move to Recently Deleted")
            .accessibilityHint("Double tap to restore this Echo immediately.")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.black.opacity(0.86))
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    private func rule(opacity: Double = 0.72) -> some View {
        Rectangle()
            .fill(Color.black.opacity(opacity))
            .frame(height: 1)
    }

    private func verticalRule(opacity: Double = 0.72) -> some View {
        Rectangle()
            .fill(Color.black.opacity(opacity))
            .frame(width: 1)
    }

    private var detailStampRotation: Double {
        Double((detailStampSeed % 7) - 3)
    }

    private var detailStampOffset: CGSize {
        CGSize(
            width: CGFloat((detailStampSeed % 25) - 12),
            height: CGFloat(((detailStampSeed / 5) % 17) - 8)
        )
    }

    private var detailStampSeed: Int {
        memory.id.uuidString.unicodeScalars.reduce(0) { partialResult, scalar in
            partialResult + Int(scalar.value)
        }
    }

    private func playDetailStampImpact() {
        guard !reduceMotion else {
            detailStampScale = 1
            detailStampOpacity = 1
            return
        }

        detailStampScale = 1.75
        detailStampOpacity = 0

        withAnimation(.easeIn(duration: 0.10)) {
            detailStampScale = 0.92
            detailStampOpacity = 0.84
        }

#if os(iOS)
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred(intensity: 0.72)
        AudioServicesPlaySystemSound(1104)
#endif

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(120))
            withAnimation(.spring(response: 0.24, dampingFraction: 0.64)) {
                detailStampScale = 1
                detailStampOpacity = 1
            }
        }
    }

    private func playDetailStampRemoval() {
        guard !reduceMotion else { return }

        withAnimation(.easeOut(duration: 0.12)) {
            detailStampScale = 0.84
            detailStampOpacity = 0
        }

#if os(iOS)
        UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.42)
        AudioServicesPlaySystemSound(1157)
#endif

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(160))
            detailStampScale = 1
            detailStampOpacity = 1
        }
    }

    private func loadRelatedLinks() async {
        guard candidateMemories.contains(where: { $0.id != memory.id && $0.deletedAt == nil }) else {
            relatedLinks = []
            return
        }

        let storedGraphLinks = linkService.storedLinks(
            for: memory,
            among: candidateMemories,
            storedLinks: storedLinks
        )

        if !storedGraphLinks.isEmpty,
           !linkService.displayedLinks(from: storedGraphLinks).isEmpty {
            relatedLinks = storedGraphLinks
            isLoadingRelatedLinks = false
            return
        }

        isLoadingRelatedLinks = true
        let links = await linkService.suggestedLinks(for: memory, among: candidateMemories)
        relatedLinks = linkService.displayedLinks(from: links).isEmpty ? storedGraphLinks : links
        isLoadingRelatedLinks = false
    }

    private func loadRecommendations() async {
        let candidates = candidateMemories.filter { $0.deletedAt == nil }
        guard candidates.contains(where: { $0.id != memory.id && $0.discoveryStatus == .notDiscovered }) else {
            recommendations = []
            return
        }

        isLoadingRecommendations = true
        recommendations = recommendationService.recommendations(for: memory, among: candidates)
        isLoadingRecommendations = false
    }

    private var inlineDraft: EchoMemoryDraft {
        EchoMemoryDraft(
            id: memory.id,
            title: title,
            creator: creator.nilIfBlank,
            category: category,
            emotion: emotion,
            memory: memoryText,
            year: year.nilIfBlank,
            originalTranscript: memory.originalTranscript,
            audioFileName: memory.audioFileName,
            audioDuration: memory.audioDuration,
            discoveryStatus: discoveryStatus,
            unlockedAt: memory.unlockedAt
        )
    }

    private func beginInlineEditing() {
        resetEditableFields()
        isEditing = true
    }

    private func cancelInlineEditing() {
        resetEditableFields()
        isEditing = false
    }

    private func resetEditableFields() {
        title = memory.title
        creator = memory.creator ?? ""
        category = memory.category
        emotion = memory.emotion
        memoryText = memory.memory
        year = memory.year ?? ""
        discoveryStatus = memory.discoveryStatus
    }

    private func saveInlineEdits() {
        guard !isSaving else { return }
        isSaving = true

        do {
            try persistenceService.update(memory, with: inlineDraft, in: modelContext)
            try? linkService.refreshStoredLinks(for: memory, among: candidateMemories, in: modelContext)
            resetEditableFields()
            isEditing = false
        } catch {
            deleteError = .persistenceFailure(action: "update this Echo")
        }

        isSaving = false
    }

    private func moveMemoryToTrash() {
        do {
            try persistenceService.moveToTrash(memory, in: modelContext)
            isShowingUndoBubble = true
            scheduleDismissAfterUndoWindow()
        } catch {
            deleteError = .persistenceFailure(action: "update Recently Deleted")
        }
    }

    private func restoreFromTrash() {
        pendingDismissTask?.cancel()

        do {
            try persistenceService.restore(memory, in: modelContext)
            isShowingUndoBubble = false
        } catch {
            deleteError = .persistenceFailure(action: "update Recently Deleted")
        }
    }

    private func scheduleDismissAfterUndoWindow() {
        pendingDismissTask?.cancel()
        pendingDismissTask = Task {
            try? await Task.sleep(for: .seconds(4))
            guard !Task.isCancelled else { return }

            await MainActor.run {
                dismiss()
            }
        }
    }
}

#Preview {
    NavigationStack {
        EchoDetailView(
            memory: EchoMemory(
                title: "The Lord of the Rings",
                creator: "J.R.R. Tolkien",
                category: .film,
                emotion: .nostalgia,
                memory: "I watched it every winter with my brother."
            )
        )
    }
    .modelContainer(for: [EchoMemory.self, EchoMemoryStoredLink.self], inMemory: true)
}
