//
//  SoundClassifierTests.swift
//  CoreML-SoundsTests
//
//  Starter smoke tests for the CoreML-Sounds app.
//
//  NOTE: `SoundClassifier` is currently an `SNResultsObserving` delegate whose
//  `analyze(audioURL:model:)` method is commented out, so there is no pure,
//  returnable logic to assert against yet. These tests verify the test target
//  compiles, links against the app module, and that the type is constructible.
//  Once `analyze` is uncommented and refactored to RETURN a classification
//  result (instead of only printing), replace `testClassifierConstructs` with a
//  real test: bundle a short known clip in this test target, run it through the
//  classifier, and assert the top label + confidence.
//

import XCTest
import SoundAnalysis
@testable import CoreML_Sounds

final class SoundClassifierTests: XCTestCase {

    func testClassifierConstructs() {
        let classifier = SoundClassifier()
        XCTAssertNotNil(classifier)
    }

    func testClassifierIsResultsObserver() {
        let classifier = SoundClassifier()
        XCTAssertTrue(classifier is SNResultsObserving)
    }
}
