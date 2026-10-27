
import SwiftUI
import UniformTypeIdentifiers
import AVFoundation
import CoreML
import SoundAnalysis

struct ContentView: View {
    @State private var showFilePicker = false
    @State private var selectedFileURL: URL?
    @State private var fileName = "No file selected"
    @State private var audioPlayer: AVAudioPlayer?

    @State private var identifier = "Identifier: —"
    @State private var confidence = "Confidence: —"
    @State private var isAnalyzing = false
    @State private var errorMessage: String?

    private let testingDirectory =
        "/Users/jalexan/Documents/code/iOSdev/CoreML-Sounds/CoreML-Sounds/TestingData"

    var body: some View {
        VStack(spacing: 24) {

            // Testing directory indicator
            VStack(spacing: 8) {
                Image(systemName: "folder")
                    .font(.system(size: 42))
                    .foregroundStyle(.cyan)

                Text("Testing Directory")
                    .font(.headline)

                Text(testingDirectory)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .textSelection(.enabled)
            }
            .padding(.horizontal)

            Divider()

            // Select an audio file
            Button {
                showFilePicker = true
                if (audioPlayer?.isPlaying == true) {
                    audioPlayer?.stop()
                }
            } label: {
                Label("Choose Audio File", systemImage: "folder.badge.plus")
            }
            .buttonStyle(.borderedProminent)

            // Selected filename
            Text(fileName)
                .font(.headline)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .padding(.horizontal)

            // Play button
            Button {
                playAudio()
            } label: {
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 56))
            }
            .disabled(selectedFileURL == nil)

            Divider()

            // Classification results
            VStack(spacing: 12) {
                Text(identifier)
                    .font(.title3)

                Text(confidence)
                    .font(.title3)
                    .monospacedDigit()

                if isAnalyzing {
                    ProgressView("Analyzing audio...")
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }
            }

            Spacer()
        }
        .padding()
        .navigationTitle("Sound Tester")
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [.audio],
            allowsMultipleSelection: false
        ) { result in
            handleSelectedFile(result)
        }
    }

    // MARK: - File selection

    private func handleSelectedFile(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let sourceURL = urls.first else { return }

            let hasAccess = sourceURL.startAccessingSecurityScopedResource()
            defer {
                if hasAccess {
                    sourceURL.stopAccessingSecurityScopedResource()
                }
            }

            do {
                // Copy the selected file into the app's temporary directory.
                // This makes playback and analysis easier after the picker closes.
                let destinationURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent(UUID().uuidString)
                    .appendingPathExtension(sourceURL.pathExtension)

                try FileManager.default.copyItem(
                    at: sourceURL,
                    to: destinationURL
                )

                selectedFileURL = destinationURL
                fileName = sourceURL.lastPathComponent

                identifier = "Identifier: —"
                confidence = "Confidence: —"
                errorMessage = nil
                audioPlayer = nil

                playAudio()                  // Autoplay immediately
                classifyAudio(at: destinationURL)

            } catch {
                errorMessage = "Could not open file: \(error.localizedDescription)"
            }

        case .failure(let error):
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Playback

    private func playAudio() {
        guard let selectedFileURL else { return }

        do {
            audioPlayer = try AVAudioPlayer(contentsOf: selectedFileURL)
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()
        } catch {
            errorMessage = "Playback failed: \(error.localizedDescription)"
        }
    }

    // MARK: - Core ML classification

    private func classifyAudio(at url: URL) {
        isAnalyzing = true
        identifier = "Identifier: —"
        confidence = "Confidence: —"
        errorMessage = nil

        Task {
            do {
                let model = try SnoringClassifier(
                    configuration: MLModelConfiguration()
                ).model

                let observer = SoundResultsObserver { classification in
                    DispatchQueue.main.async {
                        identifier = "Identifier: \(classification.identifier)"
                        confidence = String(
                            format: "Confidence: %.2f%%",
                            classification.confidence * 100
                        )
                        isAnalyzing = false
                    }
                } onCompletion: {
                    DispatchQueue.main.async {
                        isAnalyzing = false
                    }
                } onError: { error in
                    DispatchQueue.main.async {
                        errorMessage = error.localizedDescription
                        isAnalyzing = false
                    }
                }

                let analyzer = try SoundFileAnalyzer(
                    audioURL: url,
                    model: model,
                    observer: observer
                )

                // Keep the analyzer and observer alive during analysis.
                await MainActor.run {
                    AnalysisHolder.shared.start(
                        analyzer: analyzer,
                        observer: observer
                    )
                }

                try await analyzer.analyze()

            } catch {
                await MainActor.run {
                    errorMessage = "Analysis failed: \(error.localizedDescription)"
                    isAnalyzing = false
                }
            }
        }
    }
}

// MARK: - SoundAnalysis helpers

final class SoundResultsObserver: NSObject, SNResultsObserving {
    private let onResult: (SNClassification) -> Void
    private let onCompletion: () -> Void
    private let onError: (Error) -> Void

    init(
        onResult: @escaping (SNClassification) -> Void,
        onCompletion: @escaping () -> Void,
        onError: @escaping (Error) -> Void
    ) {
        self.onResult = onResult
        self.onCompletion = onCompletion
        self.onError = onError
    }

    func request(_ request: SNRequest, didProduce result: SNResult) {
        guard let result = result as? SNClassificationResult,
              let best = result.classifications.first else {
            return
        }

        onResult(best)
    }

    func request(_ request: SNRequest, didFailWithError error: Error) {
        onError(error)
    }

    func requestDidComplete(_ request: SNRequest) {
        onCompletion()
    }
}

final class SoundFileAnalyzer {
    private let analyzer: SNAudioFileAnalyzer

    init(
        audioURL: URL,
        model: MLModel,
        observer: SoundResultsObserver
    ) throws {
        analyzer = try SNAudioFileAnalyzer(url: audioURL)

        let request = try SNClassifySoundRequest(mlModel: model)
        try analyzer.add(request, withObserver: observer)
    }

    func analyze() async throws {
        try await withCheckedThrowingContinuation {
            (continuation: CheckedContinuation<Void, Error>) in

            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try self.analyzer.analyze()
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}

final class AnalysisHolder {
    static let shared = AnalysisHolder()

    private var analyzer: SoundFileAnalyzer?
    private var observer: SoundResultsObserver?

    func start(
        analyzer: SoundFileAnalyzer,
        observer: SoundResultsObserver
    ) {
        self.analyzer = analyzer
        self.observer = observer
    }
}
