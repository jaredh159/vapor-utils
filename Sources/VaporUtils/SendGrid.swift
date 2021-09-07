import Foundation
import Vapor

public struct EmailAddress: Codable, ExpressibleByStringLiteral {
  let email: String
  let name: String?

  public init(email: String, name: String? = nil) {
    self.email = email
    self.name = name
  }

  public init(stringLiteral email: String) {
    self.email = email
    self.name = nil
  }
}

public struct SendGridEmail: Content {
  public enum SendError: Error {
    case missingApiKey
  }

  public struct Personalization: Codable {
    let to: [EmailAddress]
  }

  public struct Attachment: Codable {
    let content: String  // Base64 encoded
    let filename: String
    var type = "text/plain"

    public init(data: Data, filename: String) {
      self.content = data.base64EncodedString()
      self.filename = filename
    }
  }

  let personalizations: [Personalization]
  let from: EmailAddress
  let subject: String
  let content: [[String: String]]
  var attachments: [Attachment]?

  public init(to: EmailAddress, from: EmailAddress, subject: String, html: String) {
    self.personalizations = [Personalization(to: [to])]
    self.from = from
    self.subject = subject
    self.content = [
      ["type": "text/html", "value": html]
    ]
  }

  public func send(on client: Client, withKey API_KEY: String) -> EventLoopFuture<Bool> {
    return client.post("https://api.sendgrid.com/v3/mail/send") { apiReq in
      apiReq.headers.contentType = .json
      apiReq.headers.bearerAuthorization = BearerAuthorization(token: API_KEY)
      try apiReq.content.encode(self)
    }.map { res in res.status == .accepted }
  }
}
