import XCTest
@testable import SIPCore

final class CallStateMachineTests: XCTestCase {
    func testOutgoingHappyPath() {
        XCTAssertEqual(CallStateMachine.transition(from: .idle, on: .dialed), .calling)
        XCTAssertEqual(CallStateMachine.transition(from: .calling, on: .provisional), .early)
        XCTAssertEqual(CallStateMachine.transition(from: .early, on: .accepted), .connecting)
        XCTAssertEqual(CallStateMachine.transition(from: .connecting, on: .established), .confirmed)
        XCTAssertEqual(CallStateMachine.transition(from: .confirmed, on: .ended), .disconnected)
    }

    func testIncomingHappyPath() {
        XCTAssertEqual(CallStateMachine.transition(from: .idle, on: .invited), .incoming)
        XCTAssertEqual(CallStateMachine.transition(from: .incoming, on: .accepted), .connecting)
        XCTAssertEqual(CallStateMachine.transition(from: .connecting, on: .established), .confirmed)
    }

    func testImmediateAnswerSkippingEarly() {
        XCTAssertEqual(CallStateMachine.transition(from: .calling, on: .accepted), .connecting)
    }

    func testCancelBeforeAnswer() {
        XCTAssertEqual(CallStateMachine.transition(from: .calling, on: .ended), .disconnected)
        XCTAssertEqual(CallStateMachine.transition(from: .early, on: .ended), .disconnected)
        XCTAssertEqual(CallStateMachine.transition(from: .incoming, on: .ended), .disconnected)
    }

    func testIllegalTransitionsReturnNil() {
        XCTAssertNil(CallStateMachine.transition(from: .disconnected, on: .accepted))
        XCTAssertNil(CallStateMachine.transition(from: .idle, on: .established))
        XCTAssertNil(CallStateMachine.transition(from: .confirmed, on: .dialed))
        XCTAssertNil(CallStateMachine.transition(from: .idle, on: .ended))
    }

    @MainActor
    func testURINormalization() {
        XCTAssertEqual(CallStore.normalizeURI("600", domain: "127.0.0.1", port: 5060), "sip:600@127.0.0.1")
        XCTAssertEqual(CallStore.normalizeURI("600", domain: "pbx.example.com", port: 5070), "sip:600@pbx.example.com:5070")
        XCTAssertEqual(CallStore.normalizeURI("sip:a@b.c", domain: "x", port: 5060), "sip:a@b.c")
        XCTAssertEqual(CallStore.normalizeURI("  600 ", domain: "127.0.0.1", port: 5060), "sip:600@127.0.0.1")
        XCTAssertEqual(CallStore.normalizeURI("600", domain: nil, port: nil), "sip:600")
    }
}
