//
//  SoudClassifier.swift
//  CoreML-Sounds
//
//  Created by Julie Alexan on 10/26/26.
//


import Foundation
import CoreML
import SoundAnalysis

final class SoundClassifier: NSObject, SNResultsObserving {

    func request(_ request: SNRequest,
                 didProduce result: SNResult) {

        guard let result = result as? SNClassificationResult else {
            return
        }

        print("Classification results:")

        for classification in result.classifications {
            print(
                "\(classification.identifier): " + "\(String(format: "%.2f%%", classification.confidence * 100))"
            )
        }
    }

    func request(_ request: SNRequest,
                 didFailWithError error: Error) {
        print("Classification failed: \(error)")
    }

    func requestDidComplete(_ request: SNRequest) {
        print("Analysis complete.")
    }
//
//    func analyze(audioURL: URL, model: MLModel) throws {
//        let soundClassifier = try MLSoundClassifier(
//            model: model
//        )
//
//        let request = try SNClassifySoundRequest(
//            mlModel: soundClassifier.model
//        )
//
//        request.windowDuration = CMTime(
//            seconds: 3.0,
//            preferredTimescale: 48_000
//        )
//
//        let analyzer = SNAudioFileAnalyzer(
//            url: audioURL
//        )
//
//        try analyzer.add(request, withObserver: self)
//        try analyzer.analyze()
//    }
}
