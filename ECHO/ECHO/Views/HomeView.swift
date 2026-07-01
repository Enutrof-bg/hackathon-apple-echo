import SwiftData
import SwiftUI

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \EchoMemory.createdAt, order: .reverse) private var memories: [EchoMemory]

    @State private var isShowingCapture = false
    @State private var searchText = ""
    @State private var navigation = EchoAppNavigation.shared
    @State private var handledCaptureRequestID = EchoAppNavigation.shared.captureRequestID
    @State private var handledSearchRequestID = EchoAppNavigation.shared.searchRequestID
    @State private var captureInitialMode: CaptureInputMode = .speech
    @State private var captureAutoStartSpeech = false
    @State private var purgeError: EchoUserFacingError?
#if DEBUG
    @State private var isLoadingSampleEchoes = false
    @State private var isRebuildingLinks = false
#endif

    private let persistenceService = EchoMemoryPersistenceService()
#if DEBUG
    private let placeholderService = EchoPlaceholderService()
    private let linkService = EchoMemoryLinkService()
#endif

    private var activeMemories: [EchoMemory] {
        memories.filter { $0.deletedAt == nil }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                EchoStyle.background
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    header

                    Spacer()

                    VStack(spacing: 28) {
                        captureButton
                        inputOptions
                        captureCaption
                    }

                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 22)
                .padding(.bottom, 20)
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $isShowingCapture) {
                CaptureView(
                    existingMemories: activeMemories,
                    initialInputMode: captureInitialMode,
                    autoStartSpeech: captureAutoStartSpeech
                )
            }
            .task {
                purgeExpiredDeletedMemoriesIfNeeded()
            }
            .onChange(of: navigation.captureRequestID) { _, requestID in
                guard requestID != handledCaptureRequestID else { return }
                handledCaptureRequestID = requestID
                captureInitialMode = navigation.requestedCaptureMode
                captureAutoStartSpeech = navigation.shouldStartSpeechCapture
                isShowingCapture = true
            }
            .onChange(of: navigation.searchRequestID) { _, requestID in
                guard requestID != handledSearchRequestID else { return }
                handledSearchRequestID = requestID
                searchText = navigation.requestedSearchText
            }
            .alert(item: $purgeError) { error in
                Alert(
                    title: Text("Recently Deleted could not be cleaned"),
                    message: Text(error.message),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("Echo")
                    .font(.title2)
                    .fontWeight(.medium)
                    .textCase(.uppercase)
                    .tracking(0.4)

                Spacer()
            }

            Rectangle()
                .fill(EchoStyle.border)
                .frame(height: 1)
        }
    }

    private var captureButton: some View {
        ScribbleEchoButton(state: .idle, size: 190) {
            isShowingCapture = true
        }
    }

    private var inputOptions: some View {
        HStack(spacing: 78) {
            inputOption("Text", systemImage: "textformat")
            inputOption("Photo", systemImage: "camera")
        }
    }

    private func inputOption(_ title: String, systemImage: String) -> some View {
        Button {
            isShowingCapture = true
        } label: {
            VStack(spacing: 10) {
                Image(systemName: systemImage)
                    .font(.title2)
                    .frame(width: 54, height: 54)
                    .background(EchoStyle.surface)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(EchoStyle.border.opacity(0.22), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 5)

                Text(title)
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .textCase(.uppercase)
                    .foregroundStyle(EchoStyle.ink)
            }
        }
        .buttonStyle(.plain)
    }

    private var captureCaption: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                Rectangle()
                    .fill(EchoStyle.border.opacity(0.7))
                    .frame(width: 56, height: 1)

                Text("Capture an Echo")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .textCase(.uppercase)
                    .tracking(1)

                Rectangle()
                    .fill(EchoStyle.border.opacity(0.7))
                    .frame(width: 56, height: 1)
            }

            Text("Speak, type, or take a photo\nof a work that matters to you.")
                .font(.footnote)
                .foregroundStyle(EchoStyle.mutedInk)
                .multilineTextAlignment(.center)
        }
    }

#if DEBUG
    private func insertPlaceholderEchoes() {
        guard !isLoadingSampleEchoes else { return }
        isLoadingSampleEchoes = true

        Task {
            defer { isLoadingSampleEchoes = false }

            do {
                try await placeholderService.insertPlaceholders(in: modelContext, existingMemories: memories)
            } catch {
                purgeError = .persistenceFailure(action: "update the local collection")
            }
        }
    }

    private func rebuildEchoLinks() {
        guard !isRebuildingLinks else { return }
        isRebuildingLinks = true

        Task {
            defer { isRebuildingLinks = false }

            do {
                try linkService.rebuildStoredLinks(for: activeMemories, in: modelContext)
            } catch {
                purgeError = .persistenceFailure(action: "update the local collection")
            }
        }
    }
#endif

    private func purgeExpiredDeletedMemoriesIfNeeded() {
        do {
            try persistenceService.purgeExpiredDeletedMemories(memories, in: modelContext)
        } catch {
            purgeError = .persistenceFailure(action: "update the local collection")
        }
    }
}

#Preview {
    HomeView()
        .modelContainer(for: [EchoMemory.self, EchoMemoryStoredLink.self], inMemory: true)
}
