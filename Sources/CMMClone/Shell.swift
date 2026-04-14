import Foundation

enum Shell {
    @discardableResult
    static func run(_ command: String, arguments: [String] = []) -> (status: Int32, output: String) {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: command)
        process.arguments = arguments
        process.standardOutput = pipe
        process.standardError = pipe
        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            return (process.terminationStatus, output)
        } catch {
            return (-1, error.localizedDescription)
        }
    }

    @discardableResult
    static func bash(_ script: String) -> (status: Int32, output: String) {
        return run("/bin/bash", arguments: ["-lc", script])
    }
}
