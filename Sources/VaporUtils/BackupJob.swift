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
        context.logger.info("Successfully sent scheduled database backup")
      } else {
        context.logger.error("Failed to send scheduled database backup")
      }
    }.transform(to: ())
  }

  private var dumpData: Data {
    let task = Process()
    task.executableURL = URL(fileURLWithPath: pgDumpPath)
    var arguments = [dbName]

    for tableName in excludeDataFromTables {
      arguments += ["--exclude-table-data", tableName]
    }

    task.arguments = arguments

    let pipe = Pipe()
    task.standardOutput = pipe
    try? task.run()
    return pipe.fileHandleForReading.readDataToEndOfFile()
  }

  private func filename() -> String {
    "\(appName.lowercased().replacingOccurrences(of: " ", with: "-"))-backup_\(filedate()).sql"
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
