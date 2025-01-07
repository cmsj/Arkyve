/// Gathers progression information of all computations within the `operation` block.
///
/// This free function sets the `@TaskLocal` value `Task.unsafeProgress`, which serves as an
/// indicator to any task in the structure concurrency tree to start gathering progression information.
/// Functions supporting _progress_ will forward such data into the `progress` handler.
///
/// ## Features
/// - Progress data forwarding to the `progress` handler.
/// - No locks (and no thread hopping).
/// - Supports concurrent operations.
/// - Supports hierarchy of child operations (recursive tree).
/// - (Almost) zero cost when operations are not interested in progress information.
///
/// It is worth noting that progress information requires structured concurrency;
/// therefore any operation outside of it (e.g. `Task.detached`) won't be able to participate.
/// At least, without some manual labor. Structure concurrency does still support parallel operations
/// through _task groups_ and `async let`.
///
/// ## Usage
///
/// Call `withTaskProgression` when you are interested in progression information.
/// Any operation internally checking for `Task.unsafeProgress` can forward such information and
/// you will receive it in the `progress` handler.
///
/// ```swift
/// try await withTaskProgression { _ in
///   let data = try await downloadLargeImage()
///   return try await Image(data: data)
/// } progress: { progression in
///   switch progression.status {
///     case .running(let workUnits): print("Completed units of work:", workUnits.completed)
///     case .finished: print("Image has been successfully generated")
///     case .failed: print("Failed to process image")
///   }
/// }
/// ```
///
/// Not all functions will support progression natively; however, you can quickly retrofit them. For example:
///
/// ```swit
/// try await withTaskProgression { progression in
///   let (bytes, response) = try await URLSession.shared.bytes(from: url)
///   for await byte in bytes {
///     await progression.progressed()
///   }
/// } progress: {
///   guard case .running(let units) = $0 else { return }
///   print("Downloaded bytes:", units.completed)
/// }
/// ```
///
/// Task progression also supports hierarchical work and parallel sub-task.
/// This means, you can divide the work to be done between logical operations and
/// monitor the progress of each task (even when they are run concurrently).
///
/// ```swift
/// try await withTaskProgression { progression in
///   async let imageDataA = downloadImage(url: urlA)
///   async let imageDataB = downloadImage(url: urlB)
///   let (dataA, dataB) = try await (imageDataA, imageDataB)
/// } progress: {
///   print("Downloaded bytes in imageA:", $0.children[0].status.completed)
///   print("Downloaded bytes in imageB:", $0.children[1].status.completed)
/// }
/// ```
///
/// If you are implementing progression data forwarding, you should call one of the following
/// two methods of `UnsafeTaskProgress`:
/// - `progress(_:)` lets you specify how many _units of work_ have been completed.
/// - `addChild(totalUnits:operation:)` creates a logical child progress.
///
/// ```swift
/// func downloadImage(url: URL) async throws -> Data {
///   try await Task.$unsafeProgress.addChild { progression in
///     for await twoBytes in mySequence {
///       // Store bytes
///       progression.progress { $0.increment(by: 2) }
///     }
///   }
/// }
/// ```
///
/// - parameter totalUnits: Optional total number of _units of work_ that this operation will performed.
///   This is forwarded to the `progress` block and it doesn't have any real function. If you aren't sure
///   how much _work_ will be performed. Leave it at `nil`.
/// - parameter metadata: Any `Sendable` type identifying the _root_ logical task.
/// - parameter operation: The operations being monitored for progress data.
/// - parameter progress: Closure forwarding any change in progress data.
/// - parameter isolation: The actor in which the progress data will be synchronized and the `operation` block will start.
///   If `nil` (i.e. concurrent thread), a new simple actor is created to serialize progression data computation.
/// - returns: The result of the `operation` block.
/// - todo: Remove `Sendable` marker from `Success` (use `sending` instead).
/// - todo: Make `TaskProgress` `~Escapable` and only compute values if queried.
public func withTaskProgression<Success: Sendable, Failure: Error>(
    totalUnits: Int? = nil,
    metadata: TaskProgress.Metadata? = nil,
    operation: @isolated(any) (UnsafeTaskProgress) async throws(Failure) -> Success, // TODO: make sending Success
    progress: @Sendable (TaskProgress) -> Void,
    isolation: isolated (any Actor)? = #isolation
) async throws(Failure) -> sending Success {
    try await withoutActuallyEscaping(progress) { (forward) async throws(Failure) -> Success in
        let rootProgress = UnsafeTaskProgress(totalUnits: totalUnits, metadata: metadata, isolation: isolation ?? UnsafeTaskProgress.Serializer())
        rootProgress.handler = { [unowned rootProgress] in
            let immutableProgress = TaskProgress(unsafe: rootProgress)
            forward(immutableProgress)
        }

        do {
            let result = try await Task.$unsafeProgress.withValue(rootProgress) {
                try await operation(rootProgress)
            }
            await rootProgress.finished(parent: .none, isolation: rootProgress.isolation)
            return result
        } catch let error as Failure {
            await rootProgress.failed(error: error, isolation: rootProgress.isolation)
            throw error
        } catch { fatalError() } // TODO: Remove when concrete thrown errors are better supported
    }
}

// MARK: -

/// Immutable progress information.
///
/// As soon as this object is retrieved, the _progression state_ is read and
/// further progression is not serialized here.
public struct TaskProgress: Sendable {
    /// The status of the task (i.e. `running`, `failed`, `finished`) and
    /// the amount of units of work performed by the progression task.
    ///
    /// The units of work tracked here are independent from the units of work tracked in the children tasks.
    public let status: Status
    /// All logical children tasks progressions (recursive).
    ///
    /// If a child task hasn't been launched, it doesn't appear here.
    public let children: [TaskProgress]
    /// Optional data identifying this _logical_ task.
    public let metadata: Metadata?

    /// - precondition: Isolated to `UnsafeTaskProgress.isolation`.
    fileprivate init(unsafe progress: UnsafeTaskProgress) {
        progress.isolation.assertIsolated()
        self.status = progress.status
        self.children = progress.children.map { TaskProgress(unsafe: $0) }
        self.metadata = progress.metadata
    }
}

public extension TaskProgress {
    /// Data type stored with the receiving ``TaskProgress``.
    typealias Metadata = any Sendable

    /// The state of the task gathering progress information.
    enum Status: Sendable {
        case running(TaskProgress.Units)
        case finished
        case failed(any Swift.Error)
    }

    /// The number of _units of work_ completed by the task and, optionally,
    /// the expected amount of _units of work_.
    struct Units: Sendable, Hashable, CustomDebugStringConvertible {
        public var completed: Int
        public var total: Int?

        public init() {
            self.completed = .zero
            self.total = nil
        }

        public init(completed: Int, total: Int? = nil) {
            self.completed = completed
            self.total = total
        }
    }
}

public extension TaskProgress.Units {
    var debugDescription: String {
        var result = String(self.completed)
        if let total {
            result.append(" of \(total)")
        }
        return result
    }

    func increment() -> Self {
        self.increment(by: 1)
    }

    func increment(by unit: Int) -> Self {
        let completed = self.completed + unit
        let total: Int? = self.total.map { Swift.max(completed, $0) }
        return Self(completed: completed, total: total)
    }
}

public extension Task where Success == Never, Failure == Never {
    /// Unsafe handle to the ongoing task progression.
    ///
    /// If `nil`, no one is interested in task progression information, and
    /// therefore there is no need to waste CPU cycles gathering it.
    @TaskLocal static var unsafeProgress: UnsafeTaskProgress?
}

public extension TaskLocal<UnsafeTaskProgress?> {
    /// Creates a _logical_ task to track progression.
    func addChild<Success: Sendable, Failure: Error>(
        totalUnits: Int? = nil,
        metadata: TaskProgress.Metadata? = nil,
        operation: (UnsafeTaskProgress?) async throws(Failure) -> Success
    ) async throws(Failure) -> Success {
        guard let parentProgress = self.get(),
              let childProgress = await parentProgress.makeChild(totalUnits: totalUnits, metadata: metadata, isolation: parentProgress.isolation) else {
            return try await operation(nil)
        }

        do {
            let result = try await self.withValue(childProgress) {
                try await operation(childProgress)
            }
            await childProgress.finished(parent: parentProgress, isolation: childProgress.isolation)
            return result
        } catch let error as Failure {
            await childProgress.failed(error: error, isolation: childProgress.isolation)
            throw error
        } catch { fatalError() } // TODO: Remove when concrete thrown errors are better supported
    }
}

// MARK: -

public final class UnsafeTaskProgress: @unchecked Sendable {
    var status: TaskProgress.Status
    var children: ContiguousArray<UnsafeTaskProgress> = []
    let isolation: any Actor
    let metadata: TaskProgress.Metadata?
    var handler: Handler!

    init(
        totalUnits: Int?,
        metadata: TaskProgress.Metadata?,
        isolation: any Actor
    ) {
        self.status = .running(TaskProgress.Units(completed: 0, total: totalUnits))
        self.children = ContiguousArray()
        self.isolation = isolation
        self.metadata = metadata
    }

    typealias Handler = () -> Void
}

public extension UnsafeTaskProgress {
    func progressed(isolation: isolated (any Actor)? = #isolation) async {
        await self.progressed(isolation: isolation) { $0.increment() }
    }

    func progressed(
        isolation: isolated (any Actor)? = #isolation,
        _ tally: @Sendable (_ previously: TaskProgress.Units) -> TaskProgress.Units
    ) async {
        guard self.isolation === isolation else {
            return await self.progressed(isolation: self.isolation, tally)
        }

        self.isolation.assertIsolated()
        guard case .running(let previousTally) = self.status else { return }

        self.status = .running(tally(previousTally))
        self.handler()
    }

    func signalHandler(isolation: isolated (any Actor)? = #isolation) async {
        guard self.isolation === isolation else {
            return await self.signalHandler(isolation: self.isolation)
        }

        self.isolation.assertIsolated()
        self.handler()
    }
}

internal extension UnsafeTaskProgress {
    /// - precondition: Isolated to `UnsafeTaskProgress.isolation`.
    func failed(error: any Swift.Error, isolation: isolated any Actor) {
        self.isolation.preconditionIsolated()
        guard case .running = self.status else { fatalError("Unexpected progression status (on failure)") }

        self.status = .failed(error)
        self.handler()
    }

    /// - precondition: Isolated to `UnsafeTaskProgress.isolation`.
    func finished(parent: UnsafeTaskProgress?, isolation: isolated any Actor) {
        self.isolation.preconditionIsolated()
        guard case .running = self.status else { fatalError("Unexpected progression status (on successful termination)") }

        self.status = .finished
        if let parent, case .running(let units) = parent.status {
            parent.status = .running(TaskProgress.Units(completed: units.completed + 1, total: units.total))
        }
        self.handler()
    }

    actor Serializer {}
}

fileprivate extension UnsafeTaskProgress {
    /// - precondition: Isolated to `UnsafeTaskProgress.isolation`.
    func makeChild(totalUnits: Int?, metadata: TaskProgress.Metadata?, isolation: isolated any Actor) -> UnsafeTaskProgress? {
        self.isolation.preconditionIsolated()
        guard case .running = self.status else { return nil }

        let childProgress = UnsafeTaskProgress(totalUnits: totalUnits, metadata: metadata, isolation: self.isolation)
        childProgress.handler = { [unowned self] in self.handler() }
        self.children.append(childProgress)
        return childProgress
    }
}
