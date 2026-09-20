import Foundation

public actor VoiceControlTurnRunner {
    public nonisolated let events: AsyncStream<VoiceControlEvent>
    private let continuation: AsyncStream<VoiceControlEvent>.Continuation
    private let adapter: any VoiceControlAdapter
    private let engine: any VoiceControlDecisionEngine
    private nonisolated let gate = VoiceControlAuthorityGate()
    private var goal = ""
    private var history: [VoiceControlAction] = []
    private var pending: (VoiceControlAction, VoiceControlSnapshot, Date, ActionAuthority)?
    private var running = false
    private var cancelled = false
    private var submissionID = UUID()
    private var stoppedWaiters: [CheckedContinuation<Void, Never>] = []
    private var requests = 0
    private var dispatched = 0
    private var hasUnverifiedEffect = false
    private var taskStarted = Date()

    public init(adapter: any VoiceControlAdapter, engine: any VoiceControlDecisionEngine) {
        self.adapter = adapter; self.engine = engine
        let pair = AsyncStream<VoiceControlEvent>.makeStream(bufferingPolicy: .bufferingNewest(100))
        events = pair.stream; continuation = pair.continuation
    }
    deinit { continuation.finish() }

    public nonisolated func stop() { gate.revoke() }
    public func cancel() {
        stop(); submissionID = UUID(); goal = ""; history = []; pending = nil; cancelled = true
        continuation.yield(.cancelled)
    }
    public func submit(_ goal: String) async {
        stop()
        let id = UUID()
        submissionID = id
        if running { await withCheckedContinuation { stoppedWaiters.append($0) } }
        guard submissionID == id else { return }
        self.goal = goal; history = []; pending = nil; cancelled = false
        requests = 0; dispatched = 0; hasUnverifiedEffect = false; taskStarted = Date()
        await run()
    }
    public func resume() async {
        guard !goal.isEmpty, !running else { return }
        guard !hasUnverifiedEffect else {
            continuation.yield(.paused("The last action is uncertain. Check the app and give a new instruction.")); return
        }
        pending = nil; await run()
    }
    public func confirm() async {
        guard !running, let (action, snapshot, created, pendingAuthority) = pending else { return }
        pending = nil
        guard pendingAuthority.isValid, dispatched < 12, Date().timeIntervalSince(taskStarted) < 60, Date().timeIntervalSince(created) < 20 else {
            continuation.yield(.paused("Confirmation expired. Repeat your request.")); return
        }
        // Adapter must revalidate the exact snapshot and bound target at dispatch.
        running = true
        let authority = pendingAuthority
        do {
            try authority.check()
            dispatched += 1
            hasUnverifiedEffect = true
            let receipt = try await adapter.execute(action: action, snapshot: snapshot, authority: authority)
            guard authority.isValid, !cancelled else { markStopped(); continuation.yield(.paused("Stopped.")); return }
            guard receipt.status == .verified else {
                markStopped(); continuation.yield(.paused("The action could not be verified. Check the app before continuing.")); return
            }
            hasUnverifiedEffect = false
            history.append(VoiceControlAction(operation: action.operation, targetID: action.targetID, value: action.value, targetLabel: snapshot.targets.first { $0.id == action.targetID }?.label)); running = false
            await run()
        } catch { markStopped(); continuation.yield(.paused("The app changed or the action stopped. Repeat your request.")) }
    }

    public func clarify(_ answer: String) async {
        guard !running, !goal.isEmpty else { return }
        guard !hasUnverifiedEffect else {
            continuation.yield(.paused("The last action is uncertain. Check the app and give a new instruction.")); return
        }
        goal += "\nUser clarification: " + answer
        await run()
    }

    private static func semanticTargets(_ snapshot: VoiceControlSnapshot) -> [String] {
        snapshot.targets.map { "\($0.role)|\($0.label)|\($0.value ?? "")|\($0.operations.map(\.rawValue).sorted().joined(separator: ","))" }
    }

    private func markStopped() {
        running = false
        let waiters = stoppedWaiters
        stoppedWaiters = []
        for waiter in waiters { waiter.resume() }
    }

    private func run() async {
        guard !running else { return }
        running = true
        defer { markStopped() }
        let authority = gate.replace()
        var noProgress = 0
        var previous: VoiceControlSnapshot?
        do {
            while authority.isValid, !cancelled {
                guard dispatched < 12, requests < 30, Date().timeIntervalSince(taskStarted) < 60 else {
                    continuation.yield(.paused("Task limit reached. Check the app and give the next instruction.")); return
                }
                continuation.yield(.observing)
                let snapshot = try await adapter.observe()
                try authority.check()
                if let previous, previous.contextID == snapshot.contextID,
                   Self.semanticTargets(previous) == Self.semanticTargets(snapshot), previous.summary == snapshot.summary { noProgress += 1 } else { noProgress = 0 }
                guard noProgress < 2 else { continuation.yield(.paused("The app is not changing. Please check it before continuing.")); return }
                previous = snapshot
                continuation.yield(.deciding)
                requests += 1
                let decision = try await engine.decide(goal: goal, snapshot: snapshot, history: history)
                try authority.check()
                guard Date().timeIntervalSince(taskStarted) < 60 else {
                    continuation.yield(.paused("Task limit reached. Give the next instruction.")); return
                }
                switch decision {
                case .finished:
                    guard snapshot.isComplete else {
                        continuation.yield(.paused("Only part of the interface is visible. Please check whether the task is complete.")); return
                    }
                    continuation.yield(.completed("The task appears complete. Check the result in the app.")); return
                case .clarify(let question):
                    continuation.yield(.clarification(question)); return
                case .action(let action):
                    guard let target = snapshot.targets.first(where: { $0.id == action.targetID }),
                          target.operations.contains(action.operation) else {
                        continuation.yield(.failed("The requested control is no longer available.")); return
                    }
                    if action.requiresConfirmation || action.operation == .press && !target.isNavigation || action.operation == .key {
                        pending = (action, snapshot, Date(), authority)
                        continuation.yield(.confirmation(action, "Allow \(action.operation.rawValue) on \(target.label)?" + (action.requiresConfirmation ? "\n" + String((action.value ?? "").prefix(1_000)) : ""))); return
                    }
                    continuation.yield(.acting(action))
                    dispatched += 1
                    hasUnverifiedEffect = true
                    let receipt = try await adapter.execute(action: action, snapshot: snapshot, authority: authority)
                    try authority.check()
                    guard receipt.status == .verified else {
                        continuation.yield(.paused("The action could not be verified. Check the app before continuing.")); return
                    }
                    hasUnverifiedEffect = false
                    history.append(VoiceControlAction(operation: action.operation, targetID: action.targetID, value: action.value, targetLabel: snapshot.targets.first { $0.id == action.targetID }?.label))
                }
            }
            if !cancelled { continuation.yield(.paused("Stopped.")) }
        } catch is CancellationError {
            if !cancelled { continuation.yield(.paused("Stopped.")) }
        } catch let error as JevDecisionError {
            continuation.yield(.failed(error.localizedDescription))
        } catch {
            continuation.yield(.failed("Voice Control could not continue. Check the connection and app permissions."))
        }
    }
}

private final class VoiceControlAuthorityGate: @unchecked Sendable {
    private let lock = NSLock()
    private var current = ActionAuthority()
    func revoke() { lock.lock(); defer { lock.unlock() }; current.revoke() }
    func replace() -> ActionAuthority {
        lock.lock(); defer { lock.unlock() }
        current.revoke(); current = ActionAuthority(); return current
    }
}
