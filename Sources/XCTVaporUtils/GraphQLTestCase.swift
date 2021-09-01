import Vapor
import XCTVapor
import XCTest

@testable import GraphQLKit

public struct GraphQLTest {

  public enum ExpectedError {
    case status(HTTPStatus)
    case match(String)
  }

  public enum ExpectedData {
    case exact(String)
    case contains(String)
    case containsAll([String])
    case containsUUIDs([UUID])
    case exactJson(String)
    case containsJson(String)
    case containsKVPs([String: Any])
  }

  var query: String
  var expectedData: ExpectedData? = nil
  var expectedError: ExpectedError? = nil
  var headers: [HTTPHeaders.Name: String] = [:]

  public init(
    _ query: String,
    expectedData: ExpectedData,
    headers: [HTTPHeaders.Name: String] = [:]
  ) {
    self.query = query
    self.expectedData = expectedData
    self.headers = headers
  }

  public init(
    _ query: String,
    expectedError: ExpectedError,
    headers: [HTTPHeaders.Name: String] = [:]
  ) {
    self.query = query
    self.expectedError = expectedError
    self.headers = headers
  }

  public func run(_ testCase: GraphQLTestCase, variables: [String: Map]? = nil) {
    let queryRequest = QueryRequest(query: query, operationName: nil, variables: variables)
    let data = String(data: try! JSONEncoder().encode(queryRequest), encoding: .utf8)!

    var body = ByteBufferAllocator().buffer(capacity: 0)
    body.writeString(data)

    var reqHeaders = HTTPHeaders()
    reqHeaders.contentType = .json
    reqHeaders.add(name: .contentLength, value: body.readableBytes.description)
    for (name, value) in headers {
      reqHeaders.add(name: name, value: value)
    }

    try! testCase.app.testable().test(.POST, "/graphql", headers: reqHeaders, body: body) {
      res in
      if expectedError == nil {
        XCTAssertEqual(res.status, .ok)
      }
      var mutableRes = res
      let rawResponse = mutableRes.body.readString(length: res.body.readableBytes)
      if let expectedData = expectedData {
        switch expectedData {
        case .exact(let exact):
          XCTAssertEqual(rawResponse, exact)
        case .contains(let substring):
          XCTAssertContains(rawResponse, substring)
        case .containsUUIDs(let uuids):
          for uuid in uuids {
            XCTAssertContains(rawResponse, uuid.uuidString)
          }
        case .containsAll(let substrings):
          for substring in substrings {
            XCTAssertContains(rawResponse, substring)
          }
        case .containsJson(let json):
          XCTAssertContains(rawResponse, jsonCondense(json))
        case .exactJson(let json):
          XCTAssertEqual(rawResponse, #"{"data":\#(jsonCondense(json))}"#)
        case .containsKVPs(let pairs):
          for (key, value) in pairs {
            switch value {
            case let bool as Bool:
              XCTAssertContains(rawResponse, "\"\(key)\":\(bool)")
            case let float as Float:
              XCTAssertContains(rawResponse, "\"\(key)\":\(float)")
            case let int as Int:
              XCTAssertContains(rawResponse, "\"\(key)\":\(int)")
            default:
              XCTAssertContains(rawResponse, "\"\(key)\":\"\(String(describing: value))\"")
            }
          }
        }
      } else if let err = expectedError {
        switch err {
        case .status(let status):
          XCTAssertContains(rawResponse, "\(status.code): \(status.reasonPhrase)")
        case .match(let needle):
          XCTAssertContains(rawResponse, needle)
        }
      }
    }
  }
}

open class GraphQLTestCase: XCTestCase {
  open func configureApp(_ app: Application) throws {}

  public var app: Application!

  public override func setUp() {
    app = Application(.testing)
    try! app.autoRevert().wait()
    try! app.autoMigrate().wait()
    try! configureApp(app)
  }

  public override func tearDown() {
    app.shutdown()
  }
}

private func jsonCondense(_ json: String) -> String {
  return json.split(separator: "\n")
    .map { $0.trimmingCharacters(in: .whitespaces) }
    .joined()
    .replacingOccurrences(of: "\": ", with: "\":")
}
