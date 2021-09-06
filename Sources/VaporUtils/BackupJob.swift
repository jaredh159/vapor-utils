import Queues
import Vapor

public struct BackupJob: ScheduledJob {
  let appName: String
  let pgDumpPath: String
  let gzipPath: String
  let dbName: String
  let excludeDataFromTables: [String]
  let sendGridApiKey: String
  let fromEmail: EmailAddress

  public init(
    appName: String,
    dbName: String,
    pgDumpPath: String,
    gzipPath: String,
    sendGridApiKey: String,
    fromEmail: EmailAddress = .init(email: "backups@vapor-utils.com", name: "Vapor Backups"),
    excludeDataFromTables: [String] = []
  ) {
    self.appName = appName
    self.dbName = dbName
    self.pgDumpPath = pgDumpPath
    self.gzipPath = gzipPath
    self.sendGridApiKey = sendGridApiKey
    self.fromEmail = fromEmail
    self.excludeDataFromTables = excludeDataFromTables
  }

  public func run(context: QueueContext) -> EventLoopFuture<Void> {
    guard let data = try? dumpData() else {
      context.logger.error("[VaporUtils] Error getting gzipped database backup data")
      return context.eventLoop.makeSucceededVoidFuture()
    }

    var email = SendGridEmail(
      to: .init(email: "jared@netrivet.com", name: "Jared Henderson"),
      from: fromEmail,
      subject: "[\(appName)] Database backup \(filedate())",
      html: "Backup attached."
    )

    email.attachments = [SendGridEmail.Attachment(data: data, filename: filename())]

    return email.send(on: context.application.client, withKey: sendGridApiKey).map { success in
      if success {
        context.logger.info("[VaporUtils] Successfully sent scheduled database backup")
      } else {
        context.logger.error("[VaporUtils] Failed to send scheduled database backup")
      }
    }.transform(to: ())
  }

  private func dumpData() throws -> Data {
    let pgDump = Process()
    pgDump.executableURL = URL(fileURLWithPath: pgDumpPath)
    var arguments = [dbName]
    for tableName in excludeDataFromTables {
      arguments += ["--exclude-table-data", tableName]
    }
    pgDump.arguments = arguments
    pgDump.standardOutput = Pipe()

    let gzip = Process()
    gzip.executableURL = URL(fileURLWithPath: gzipPath)
    gzip.arguments = ["-c"]
    gzip.standardInput = pgDump.standardOutput
    let outputPipe = Pipe()
    gzip.standardOutput = outputPipe

    try pgDump.run()
    try gzip.run()
    pgDump.waitUntilExit()
    gzip.waitUntilExit()

    return outputPipe.fileHandleForReading.readDataToEndOfFile()
  }

  private func filename() -> String {
    "\(appName.lowercased().replacingOccurrences(of: " ", with: "-"))-backup_\(filedate()).sql.gz"
  }
}

private func filedate() -> String {
  Date().description
    .split(separator: "+")
    .dropLast()
    .joined(separator: "")
    .trimmingCharacters(in: .whitespaces)
    .replacingOccurrences(of: ":", with: "-")
    .replacingOccurrences(of: " ", with: "_")
}
