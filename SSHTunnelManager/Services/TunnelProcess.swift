import Foundation

class TunnelProcess {
    let config: TunnelConfig
    private var process: Process?
    private var askpassURL: URL?

    var isRunning: Bool { process?.isRunning ?? false }
    var onTermination: ((Int32) -> Void)?

    init(config: TunnelConfig) {
        self.config = config
    }

    func start() throws {
        guard !isRunning else { return }
        guard PortChecker.isPortAvailable(config.localPort) else {
            throw TunnelError.portInUse(config.localPort)
        }

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/ssh")
        proc.arguments = SSHCommandBuilder.buildArguments(for: config)

        if config.authMethod == .password {
            let scriptURL = try AskpassHelper.createScript(for: config.id)
            askpassURL = scriptURL
            var env = ProcessInfo.processInfo.environment
            env["SSH_ASKPASS"] = scriptURL.path
            env["SSH_ASKPASS_REQUIRE"] = "force"
            env["DISPLAY"] = ":0"
            proc.environment = env
        }

        proc.standardOutput = FileHandle.nullDevice
        proc.standardError = FileHandle.nullDevice

        proc.terminationHandler = { [weak self] process in
            DispatchQueue.main.async {
                self?.onTermination?(process.terminationStatus)
            }
        }

        try proc.run()
        self.process = proc
    }

    func stop() {
        guard let proc = process, proc.isRunning else { return }
        proc.terminate()
        let pid = proc.processIdentifier
        DispatchQueue.global().asyncAfter(deadline: .now() + 2) { [weak proc] in
            if let proc = proc, proc.isRunning {
                kill(pid, SIGKILL)
            }
        }
        cleanup()
    }

    private func cleanup() {
        AskpassHelper.cleanup(for: config.id)
        askpassURL = nil
    }

    deinit {
        stop()
    }
}

enum TunnelError: LocalizedError {
    case portInUse(Int)

    var errorDescription: String? {
        switch self {
        case .portInUse(let port):
            return "Port \(port) is already in use"
        }
    }
}
