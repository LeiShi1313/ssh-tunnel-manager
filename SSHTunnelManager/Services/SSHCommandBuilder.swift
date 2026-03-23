import Foundation

enum SSHCommandBuilder {
    static func buildArguments(for config: TunnelConfig) -> [String] {
        var args: [String] = []
        args.append("-N")
        args += ["-o", "ExitOnForwardFailure=yes"]
        args += ["-o", "ServerAliveInterval=30"]
        args += ["-o", "ServerAliveCountMax=3"]

        switch config.forwardingType {
        case .local:
            args.append("-L")
            args.append("\(config.localPort):\(config.remoteHost ?? "localhost"):\(config.remotePort ?? 0)")
        case .remote:
            args.append("-R")
            args.append("\(config.remotePort ?? 0):\(config.remoteHost ?? "localhost"):\(config.localPort)")
        case .dynamic:
            args.append("-D")
            args.append("\(config.localPort)")
        }

        if config.authMethod == .key, let keyPath = config.keyPath {
            args += ["-i", keyPath]
        }

        args += ["-p", "\(config.port)"]
        args.append("\(config.user)@\(config.host)")
        return args
    }
}
