import Vapor

public struct SlackMessage {
  private struct Response: Content {
    let ok: Bool
  }

  public enum Emoji: String {
    case unlock
  }

  let text: String
  let channel: String
  let username: String
  let emoji: Emoji

  public init(text: String, channel: String, username: String, emoji: Emoji) {
    self.text = text
    self.channel = channel
    self.username = username
    self.emoji = emoji
  }

  public func send(on client: Client, withToken token: String) -> EventLoopFuture<Bool> {
    return client.post("https://slack.com/api/chat.postMessage") { req in
      req.headers.contentType = .json
      req.headers.bearerAuthorization = BearerAuthorization(token: token)
      try req.content.encode([
        "channel": channel,
        "text": text,
        "icon_emoji": emoji.rawValue,
        "username": username,
        "unfurl_links": "false",
        "unfurl_media": "false",
      ])
    }.flatMapThrowing { res in
      try res.content.decode(SlackMessage.Response.self)
    }.map { json in json.ok == true }
  }
}
