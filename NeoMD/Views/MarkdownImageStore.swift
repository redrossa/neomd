import AppKit
import Observation

@MainActor @Observable final class MarkdownImageStore {
    enum State: Equatable {
        case loading
        case loaded(NSImage, natural: CGSize)
        case unavailable(MarkdownImageFailure)
    }

    private(set) var states: [URL: State] = [:]
    @ObservationIgnored private var tasks: [URL: (id: UUID, task: Task<Void, Never>)] = [:]
    @ObservationIgnored private let loader: @Sendable (URL) async -> MarkdownImageLoadResult

    init(loader: @escaping @Sendable (URL) async -> MarkdownImageLoadResult = MarkdownImageLoader.load) {
        self.loader = loader
    }

    func load(_ url: URL) {
        guard states[url] == nil else { return }
        states[url] = .loading
        let id = UUID()
        let loader = loader
        let task = Task.detached(priority: .utility) { [weak self] in
            let result = await loader(url)
            guard !Task.isCancelled else { return }
            await self?.publish(result, for: url, id: id)
        }
        tasks[url] = (id, task)
    }

    private func publish(_ result: MarkdownImageLoadResult, for url: URL, id: UUID) {
        guard tasks[url]?.id == id else { return }
        tasks[url] = nil
        switch result {
        case .loaded(let bitmap, let natural):
            states[url] = .loaded(NSImage(cgImage: bitmap, size: natural), natural: natural)
        case .unavailable(let failure): states[url] = .unavailable(failure)
        }
    }

    func retryInaccessible() {
        let urls = states.compactMap { $0.value == .unavailable(.inaccessible) ? $0.key : nil }
        for url in urls { states[url] = nil; load(url) }
    }

    func reset() {
        for entry in tasks.values { entry.task.cancel() }
        tasks.removeAll()
        states.removeAll()
    }

    deinit {
        for entry in tasks.values { entry.task.cancel() }
    }
}
