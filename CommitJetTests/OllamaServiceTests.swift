import XCTest
@testable import CommitJet

final class OllamaServiceTests: XCTestCase {
    func testRejectsInvalidServerAddress() async {
        do { _ = try await OllamaService().models(server: "not a URL"); XCTFail("Expected invalid address") }
        catch let error as OllamaService.OllamaError {
            guard case .invalidAddress = error else { return XCTFail("Unexpected error: \(error)") }
        } catch { XCTFail("Unexpected error: \(error)") }
    }

    func testParsesGeneratedCommitMessage() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        MockURLProtocol.responseData = Data("{\"response\":\"{\\\"subject\\\":\\\"fix: correct status display\\\",\\\"body\\\":\\\"\\\"}\"}".utf8)
        MockURLProtocol.statusCode = 200
        let service = OllamaService(session: URLSession(configuration: configuration))
        let answer = try await service.generate(server: "http://localhost:11434", model: "test-model", diff: "diff --git a/a b/a")
        XCTAssertEqual(answer, "fix: correct status display")
    }

    func testReportsConnectionFailure() async {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        MockURLProtocol.shouldFail = true
        let service = OllamaService(session: URLSession(configuration: configuration))
        do { _ = try await service.models(server: "http://localhost:11434"); XCTFail("Expected connection error") }
        catch let error as OllamaService.OllamaError {
            guard case .unreachable = error else { return XCTFail("Unexpected error: \(error)") }
        } catch { XCTFail("Unexpected error: \(error)") }
        MockURLProtocol.shouldFail = false
    }
}

private final class MockURLProtocol: URLProtocol {
    nonisolated(unsafe) static var responseData = Data()
    nonisolated(unsafe) static var statusCode = 200
    nonisolated(unsafe) static var shouldFail = false
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        if Self.shouldFail {
            client?.urlProtocol(self, didFailWithError: URLError(.cannotConnectToHost))
            return
        }
        let response = HTTPURLResponse(url: request.url!, statusCode: Self.statusCode, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Self.responseData)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}
