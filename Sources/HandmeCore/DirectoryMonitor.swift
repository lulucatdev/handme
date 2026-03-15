import Foundation

public final class DirectoryMonitor: @unchecked Sendable {
    private let url: URL
    private var source: DispatchSourceFileSystemObject?
    private let onChange: @Sendable () -> Void

    public init(url: URL, onChange: @escaping @Sendable () -> Void) {
        self.url = url
        self.onChange = onChange
    }

    deinit { stop() }

    public func start() {
        guard source == nil else { return }
        let fd = open(url.path, O_EVTONLY)
        guard fd >= 0 else { return }
        let src = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd, eventMask: .write,
            queue: DispatchQueue.global(qos: .utility)
        )
        src.setEventHandler { [onChange] in onChange() }
        src.setCancelHandler { close(fd) }
        source = src
        src.resume()
    }

    public func stop() {
        source?.cancel()
        source = nil
    }
}
