import Queues
import Vapor

public struct BackupJob: ScheduledJob {
  let appName: String
  let pgDumpPath: String
  let dbName: String
  let excludeDataFromTables: [String]
  let sendGridApiKey: String
  let fromEmail: EmailAddress

  public init(
    appName: String,
    dbName: String,
    pgDumpPath: String,
    sendGridApiKey: String,
    fromEmail: EmailAddress = .init(email: "backups@vapor-utils.com", name: "Vapor Backups"),
    excludeDataFromTables: [String] = []
  ) {
    self.appName = appName
    self.dbName = dbName
    self.pgDumpPath = pgDumpPath
    self.sendGridApiKey = sendGridApiKey
    self.fromEmail = fromEmail
    self.excludeDataFromTables = excludeDataFromTables
  }

  public func run(context: QueueContext) -> EventLoopFuture<Void> {
    var email = SendGridEmail(
      to: .init(email: "jared@netrivet.com", name: "Jared Henderson"),
      from: fromEmail,
      subject: "[\(appName)] Database backup \(filedate())",
      html: "Backup attached."
    )

    email.attachments = [SendGridEmail.Attachment(data: dumpData, filename: filename())]

    return email.send(on: context.application.client, withKey: sendGridApiKey).map { success in
      if success {
        context.logger.info("[VaporUtils] Successfully sent scheduled database backup")
      } else {
        context.logger.error("[VaporUtils] Failed to send scheduled database backup")
      }
    }.transform(to: ())
  }

  private var dumpData: Data {
    let pgDump = Process()
    pgDump.executableURL = URL(fileURLWithPath: pgDumpPath)

    var arguments = [dbName, "-Z", "9"]  // -Z 9 means full gzip compression
    for tableName in excludeDataFromTables {
      arguments += ["--exclude-table-data", tableName]
    }
    pgDump.arguments = arguments

    let outputPipe = Pipe()
    pgDump.standardOutput = outputPipe
    try? pgDump.run()
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
