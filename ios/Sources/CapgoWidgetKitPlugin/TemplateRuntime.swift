import Foundation

struct TemplateRuntimeRecord {
    var activityId: String
    var templateId: String
    var definition: [String: Any]
    var state: [String: Any]
    var timers: [String: StoredTemplateTimerState]
    var status: String
    var openUrl: String?
    var updatedAtMs: Int64
    var revision: Int
    var nativeActivityId: String?

    init(
        activityId: String,
        templateId: String,
        definition: [String: Any],
        state: [String: Any],
        timers: [String: StoredTemplateTimerState],
        status: String,
        openUrl: String?,
        updatedAtMs: Int64,
        revision: Int,
        nativeActivityId: String?
    ) {
        self.activityId = activityId
        self.templateId = templateId
        self.definition = definition
        self.state = state
        self.timers = timers
        self.status = status
        self.openUrl = openUrl
        self.updatedAtMs = updatedAtMs
        self.revision = revision
        self.nativeActivityId = nativeActivityId
    }

    init(envelope: StoredTemplateActivityEnvelope) throws {
        let definitionObject = try TemplateRuntime.jsonObject(from: envelope.definitionData)
        let stateObject = try TemplateRuntime.jsonObject(from: envelope.stateData)

        guard let definition = definitionObject as? [String: Any] else {
            throw CapgoWidgetKitBridgeError.invalidObject("The stored template definition is not a JSON object.")
        }

        guard let state = stateObject as? [String: Any] else {
            throw CapgoWidgetKitBridgeError.invalidObject("The stored template state is not a JSON object.")
        }

        activityId = envelope.activityId
        templateId = envelope.templateId
        self.definition = definition
        self.state = state
        timers = envelope.timers
        status = envelope.status
        openUrl = envelope.openUrl
        updatedAtMs = envelope.updatedAtMs
        revision = envelope.revision
        nativeActivityId = envelope.nativeActivityId
    }

    func toEnvelope() throws -> StoredTemplateActivityEnvelope {
        StoredTemplateActivityEnvelope(
            activityId: activityId,
            templateId: templateId,
            definitionData: try TemplateRuntime.jsonData(from: definition),
            stateData: try TemplateRuntime.jsonData(from: state),
            timers: timers,
            status: status,
            openUrl: openUrl,
            updatedAtMs: updatedAtMs,
            revision: revision,
            nativeActivityId: nativeActivityId
        )
    }
}

// swiftlint:disable type_body_length force_try function_parameter_count identifier_name file_length
enum TemplateRuntime {
    private static let tokenRegex = try! NSRegularExpression(pattern: #"\{\{\s*([^{}]+?)\s*\}\}"#)
    private static let exactTokenRegex = try! NSRegularExpression(pattern: #"^\{\{\s*([^{}]+?)\s*\}\}$"#)

    static func jsonData(from object: Any) throws -> Data {
        guard JSONSerialization.isValidJSONObject(object) else {
            throw CapgoWidgetKitBridgeError.invalidObject("The template payload contains unsupported values.")
        }
        return try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
    }

    static func jsonObject(from data: Data) throws -> Any {
        try JSONSerialization.jsonObject(with: data, options: [])
    }

    static func makeRecord(
        activityId: String,
        definitionObject: [String: Any],
        stateObject: [String: Any],
        openUrl: String?,
        nowMs: Int64
    ) -> TemplateRuntimeRecord {
        var record = TemplateRuntimeRecord(
            activityId: activityId,
            templateId: (definitionObject["id"] as? String) ?? activityId,
            definition: definitionObject,
            state: stateObject,
            timers: [:],
            status: "active",
            openUrl: openUrl,
            updatedAtMs: nowMs,
            revision: 1,
            nativeActivityId: nil
        )
        record.timers = reconcileTimers(for: record, nowMs: nowMs)
        return record
    }

    static func serializeActivity(_ envelope: StoredTemplateActivityEnvelope) throws -> [String: Any] {
        let record = try TemplateRuntimeRecord(envelope: envelope)
        return serializeActivity(record, nowMs: envelope.updatedAtMs)
    }

    static func serializeActivity(_ record: TemplateRuntimeRecord, nowMs: Int64) -> [String: Any] {
        [
            "activityId": record.activityId,
            "definition": record.definition,
            "state": record.state,
            "timers": record.timers.mapValues(serializeStoredTimer),
            "status": record.status,
            "openUrl": record.openUrl as Any,
            "updatedAt": record.updatedAtMs,
            "revision": record.revision
        ]
    }

    static func serializeEvent(_ event: StoredTemplateActionEvent) throws -> [String: Any] {
        let stateObject = try jsonObject(from: event.stateData)
        let payloadObject = try event.payloadData.map(jsonObject(from:))
        return [
            "eventId": event.eventId,
            "activityId": event.activityId,
            "actionId": event.actionId,
            "eventName": event.eventName as Any,
            "sourceId": event.sourceId as Any,
            "createdAt": event.createdAtMs,
            "acknowledgedAt": event.acknowledgedAtMs as Any,
            "payload": payloadObject as Any,
            "state": stateObject,
            "timers": event.timers.mapValues(serializeStoredTimer)
        ]
    }

    static func applyAction(
        actionId: String,
        sourceId: String?,
        payloadObject: [String: Any]?,
        record: TemplateRuntimeRecord,
        nowMs: Int64
    ) throws -> (TemplateRuntimeRecord, StoredTemplateActionEvent) {
        guard let action = actionDefinitions(from: record.definition).first(where: { ($0["id"] as? String) == actionId }) else {
            throw CapgoWidgetKitBridgeError.invalidObject("The action \(actionId) is not defined on template \(record.templateId).")
        }

        var nextRecord = record

        if let patches = action["patches"] as? [[String: Any]] {
            for patch in patches {
                applyPatch(patch, to: &nextRecord, nowMs: nowMs, actionId: actionId, sourceId: sourceId, payloadObject: payloadObject)
            }
        }

        if let frameMutations = action["frameMutations"] as? [[String: Any]] {
            for mutation in frameMutations {
                applyFrameMutation(
                    mutation,
                    to: &nextRecord,
                    nowMs: nowMs,
                    actionId: actionId,
                    sourceId: sourceId,
                    payloadObject: payloadObject
                )
            }
        }

        if let timerMutations = action["timerMutations"] as? [[String: Any]] {
            for mutation in timerMutations {
                applyTimerMutation(
                    mutation,
                    to: &nextRecord,
                    nowMs: nowMs,
                    actionId: actionId,
                    sourceId: sourceId,
                    payloadObject: payloadObject
                )
            }
        }

        nextRecord.timers = reconcileTimers(for: nextRecord, nowMs: nowMs)
        nextRecord.updatedAtMs = nowMs
        nextRecord.revision += 1

        let event = StoredTemplateActionEvent(
            eventId: createIdentifier(prefix: "event"),
            activityId: nextRecord.activityId,
            actionId: actionId,
            eventName: action["eventName"] as? String,
            sourceId: sourceId,
            createdAtMs: nowMs,
            acknowledgedAtMs: nil,
            payloadData: try payloadObject.map(jsonData(from:)),
            stateData: try jsonData(from: nextRecord.state),
            timers: nextRecord.timers
        )

        return (nextRecord, event)
    }

    static func resolveSvg(layoutObject: [String: Any], record: TemplateRuntimeRecord, nowMs: Int64) -> String {
        resolveLayout(layoutObject: layoutObject, record: record, nowMs: nowMs)["svg"] as? String ?? ""
    }

    static func resolveLayout(layoutObject: [String: Any], record: TemplateRuntimeRecord, nowMs: Int64) -> [String: Any] {
        let resolvedFrame = resolveLayoutFrame(layoutObject: layoutObject, record: record, nowMs: nowMs)
        return [
            "frameId": resolvedFrame.frameId as Any,
            "svg": resolveTemplateString(resolvedFrame.svg, record: record, nowMs: nowMs),
            "hotspots": resolvedFrame.hotspots as Any
        ]
    }

    private static func resolveLayoutFrame(
        layoutObject: [String: Any],
        record: TemplateRuntimeRecord,
        nowMs: Int64
    ) -> (frameId: String?, svg: String, hotspots: Any?) {
        let frames = layoutObject["frames"] as? [[String: Any]] ?? []
        let requestedFrameId = resolveFrameId(layoutObject["frameIdPath"] as? String, record: record, nowMs: nowMs)
        let requestedFrame = frames.first(where: { ($0["id"] as? String) == requestedFrameId })
        let defaultFrame = frames.first(where: { ($0["id"] as? String) == (layoutObject["defaultFrameId"] as? String) })
        let selectedFrame = requestedFrame ?? defaultFrame ?? (layoutObject["svg"] == nil ? frames.first : nil)

        return (
            frameId: selectedFrame?["id"] as? String,
            svg: selectedFrame?["svg"] as? String ?? layoutObject["svg"] as? String ?? "",
            hotspots: selectedFrame?["hotspots"] ?? layoutObject["hotspots"]
        )
    }

    static func createIdentifier(prefix: String) -> String {
        "\(prefix)-\(UUID().uuidString.lowercased())"
    }

    private static func timerDefinitions(from definition: [String: Any]) -> [[String: Any]] {
        definition["timers"] as? [[String: Any]] ?? []
    }

    private static func actionDefinitions(from definition: [String: Any]) -> [[String: Any]] {
        definition["actions"] as? [[String: Any]] ?? []
    }

    private static func timerElapsedMs(_ timer: StoredTemplateTimerState, nowMs: Int64) -> Int64 {
        let savedElapsedMs = max(Int64(0), timer.elapsedMs ?? 0)
        if timer.status == "finished", timer.durationMs > 0 {
            return timer.durationMs
        }
        if timer.status == "running", let startedAtMs = timer.startedAtMs {
            return savedElapsedMs + max(Int64(0), nowMs - startedAtMs)
        }
        return savedElapsedMs
    }

    private static func serializeTimerBinding(_ timer: StoredTemplateTimerState, nowMs: Int64) -> [String: Any] {
        let status = timerStatus(timer, nowMs: nowMs)
        let startedAtMs = status == "running" ? timer.startedAtMs : nil
        let durationMs = timer.durationMs
        let elapsedMs = min(timerElapsedMs(timer, nowMs: nowMs), durationMs > 0 ? durationMs : Int64.max)
        let remainingMs = durationMs > 0 ? max(Int64(0), durationMs - elapsedMs) : 0
        let progress = durationMs > 0 ? min(max(Double(elapsedMs) / Double(durationMs), 0), 1) : 0
        let totalSeconds = max(0, Int(ceil(Double(remainingMs) / 1000.0)))
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60

        return [
            "id": timer.id,
            "startedAtMs": startedAtMs as Any,
            "durationMs": durationMs,
            "status": status,
            "elapsedMs": elapsedMs,
            "remainingMs": remainingMs,
            "progress": progress,
            "progressPct": Double(round(progress * 10_000) / 100),
            "isActive": status == "running",
            "isPaused": status == "paused",
            "remainingText": String(format: "%d:%02d", minutes, seconds),
            "endsAtMs": startedAtMs.map { $0 + max(Int64(0), durationMs - (timer.elapsedMs ?? 0)) } as Any
        ]
    }

    private static func serializeStoredTimer(_ timer: StoredTemplateTimerState) -> [String: Any] {
        [
            "id": timer.id,
            "startedAt": timer.startedAtMs as Any,
            "elapsedMs": timer.elapsedMs as Any,
            "durationMs": timer.durationMs,
            "status": timer.status,
            "updatedAt": timer.updatedAtMs
        ]
    }

    static func reconcileTimers(for record: TemplateRuntimeRecord, nowMs: Int64) -> [String: StoredTemplateTimerState] {
        var nextTimers: [String: StoredTemplateTimerState] = [:]

        for definition in timerDefinitions(from: record.definition) {
            guard let timerId = definition["id"] as? String else {
                continue
            }

            let previous = record.timers[timerId]
            let durationMs = resolveDuration(definition, record: record, nowMs: nowMs) ?? previous?.durationMs ?? 0
            let startedAtMs = previous == nil ? resolveStartAt(definition, record: record, nowMs: nowMs) : previous?.startedAtMs

            var timer = StoredTemplateTimerState(
                id: timerId,
                startedAtMs: startedAtMs,
                durationMs: durationMs,
                status: previous?.status ?? (startedAtMs == nil ? "idle" : "running"),
                updatedAtMs: nowMs,
                elapsedMs: previous?.elapsedMs ?? 0
            )
            timer.status = timerStatus(timer, nowMs: nowMs)
            if timer.status == "finished" {
                timer.startedAtMs = nil
                timer.elapsedMs = timer.durationMs
            }
            nextTimers[timerId] = timer
        }

        return nextTimers
    }

    private static func resolveDuration(_ definition: [String: Any], record: TemplateRuntimeRecord, nowMs: Int64) -> Int64? {
        if let duration = coerceInt64(definition["durationMs"]) {
            return max(0, duration)
        }

        if let durationPath = definition["durationPath"] as? String {
            let resolvedPath = resolveTemplateString(durationPath, record: record, nowMs: nowMs)
            return max(0, coerceInt64(resolveReference(resolvedPath, record: record, nowMs: nowMs)) ?? 0)
        }

        return nil
    }

    private static func resolveStartAt(_ definition: [String: Any], record: TemplateRuntimeRecord, nowMs: Int64) -> Int64? {
        if let startAtPath = definition["startAtPath"] as? String {
            let resolvedPath = resolveTemplateString(startAtPath, record: record, nowMs: nowMs)
            if let startAt = coerceInt64(resolveReference(resolvedPath, record: record, nowMs: nowMs)) {
                return startAt
            }
        }

        if (definition["autoStart"] as? Bool) == true {
            return nowMs
        }

        return nil
    }

    private static func applyPatch(
        _ patch: [String: Any],
        to record: inout TemplateRuntimeRecord,
        nowMs: Int64,
        actionId: String,
        sourceId: String?,
        payloadObject: [String: Any]?
    ) {
        guard let op = patch["op"] as? String, let rawPath = patch["path"] as? String else {
            return
        }

        let resolvedPath = normalizeStatePath(
            resolveTemplateString(
                rawPath,
                record: record,
                nowMs: nowMs,
                actionId: actionId,
                sourceId: sourceId,
                payloadObject: payloadObject
            )
        )
        guard !resolvedPath.isEmpty else {
            return
        }

        switch op {
        case "set":
            setValue(
                resolvePatchValue(
                    patch,
                    record: record,
                    nowMs: nowMs,
                    actionId: actionId,
                    sourceId: sourceId,
                    payloadObject: payloadObject
                ),
                at: resolvedPath,
                in: &record.state
            )
        case "timestamp":
            setValue(nowMs, at: resolvedPath, in: &record.state)
        case "increment":
            let currentValue = coerceInt64(getValue(at: resolvedPath, in: record.state)) ?? 0
            let amount = coerceInt64(patch["amount"]) ?? 1
            setValue(currentValue + amount, at: resolvedPath, in: &record.state)
        case "toggle":
            let currentValue = getValue(at: resolvedPath, in: record.state) as? Bool ?? false
            setValue(!currentValue, at: resolvedPath, in: &record.state)
        case "unset":
            removeValue(at: resolvedPath, in: &record.state)
        default:
            break
        }
    }

    private static func resolvePatchValue(
        _ patch: [String: Any],
        record: TemplateRuntimeRecord,
        nowMs: Int64,
        actionId: String,
        sourceId: String?,
        payloadObject: [String: Any]?
    ) -> Any {
        if let valuePath = patch["valuePath"] as? String {
            let resolvedPath = resolveTemplateString(
                valuePath,
                record: record,
                nowMs: nowMs,
                actionId: actionId,
                sourceId: sourceId,
                payloadObject: payloadObject
            )
            return cloneJsonValue(
                resolveReference(
                    resolvedPath,
                    record: record,
                    nowMs: nowMs,
                    actionId: actionId,
                    sourceId: sourceId,
                    payloadObject: payloadObject
                ) ?? NSNull()
            )
        }

        if let valueTemplate = patch["valueTemplate"] as? String {
            if let exact = exactTokenValue(
                valueTemplate,
                record: record,
                nowMs: nowMs,
                actionId: actionId,
                sourceId: sourceId,
                payloadObject: payloadObject
            ) {
                return cloneJsonValue(exact)
            }
            return resolveTemplateString(
                valueTemplate,
                record: record,
                nowMs: nowMs,
                actionId: actionId,
                sourceId: sourceId,
                payloadObject: payloadObject
            )
        }

        if let value = patch["value"] {
            return cloneJsonValue(value)
        }

        return NSNull()
    }

    private static func frameIdsForMutation(_ mutation: [String: Any], record: TemplateRuntimeRecord) -> [String] {
        if let frameIds = mutation["frameIds"] as? [String], !frameIds.isEmpty {
            return frameIds
        }

        guard let surface = mutation["surface"] as? String,
              let layouts = record.definition["layouts"] as? [String: Any],
              let layout = layouts[surface] as? [String: Any],
              let frames = layout["frames"] as? [[String: Any]]
        else {
            return []
        }

        return frames.compactMap { $0["id"] as? String }
    }

    private static func resolveFrameId(
        _ template: String?,
        record: TemplateRuntimeRecord,
        nowMs: Int64,
        actionId: String? = nil,
        sourceId: String? = nil,
        payloadObject: [String: Any]? = nil
    ) -> String? {
        guard let template, !template.isEmpty else {
            return nil
        }

        if let exact = exactTokenValue(
            template,
            record: record,
            nowMs: nowMs,
            actionId: actionId,
            sourceId: sourceId,
            payloadObject: payloadObject
        ) {
            return stringifyValue(exact)
        }

        let resolved = resolveTemplateString(
            template,
            record: record,
            nowMs: nowMs,
            actionId: actionId,
            sourceId: sourceId,
            payloadObject: payloadObject
        )
        if let referenced = resolveReference(
            resolved,
            record: record,
            nowMs: nowMs,
            actionId: actionId,
            sourceId: sourceId,
            payloadObject: payloadObject
        ) {
            return stringifyValue(referenced)
        }
        return resolved.isEmpty ? nil : resolved
    }

    private static func applyFrameMutation(
        _ mutation: [String: Any],
        to record: inout TemplateRuntimeRecord,
        nowMs: Int64,
        actionId: String,
        sourceId: String?,
        payloadObject: [String: Any]?
    ) {
        guard let op = mutation["op"] as? String, let rawPath = mutation["path"] as? String else {
            return
        }

        let resolvedPath = normalizeStatePath(
            resolveTemplateString(
                rawPath,
                record: record,
                nowMs: nowMs,
                actionId: actionId,
                sourceId: sourceId,
                payloadObject: payloadObject
            )
        )
        guard !resolvedPath.isEmpty else {
            return
        }

        let frameIds = frameIdsForMutation(mutation, record: record)
        let currentValue = stringifyValue(getValue(at: resolvedPath, in: record.state))
        let currentIndex = frameIds.firstIndex(of: currentValue)
        let wraps = (mutation["wrap"] as? Bool) ?? true
        var nextFrameId: String?

        switch op {
        case "set":
            nextFrameId = resolveFrameId(
                mutation["frameId"] as? String,
                record: record,
                nowMs: nowMs,
                actionId: actionId,
                sourceId: sourceId,
                payloadObject: payloadObject
            )
        case "toggle":
            let alternateFrameId = resolveFrameId(
                mutation["frameId"] as? String,
                record: record,
                nowMs: nowMs,
                actionId: actionId,
                sourceId: sourceId,
                payloadObject: payloadObject
            )
            if frameIds.count >= 2 {
                nextFrameId = currentValue == frameIds[0] ? frameIds[1] : frameIds[0]
            } else if let alternateFrameId {
                nextFrameId = currentValue == alternateFrameId ? frameIds.first : alternateFrameId
            }
        case "next":
            guard !frameIds.isEmpty else { break }
            let nextIndex = currentIndex.map { $0 + 1 } ?? 0
            nextFrameId = frameIds.indices.contains(nextIndex) ? frameIds[nextIndex] : (wraps ? frameIds[0] : currentValue)
        case "previous":
            guard !frameIds.isEmpty else { break }
            let nextIndex = currentIndex.map { $0 - 1 } ?? frameIds.count - 1
            nextFrameId = frameIds.indices.contains(nextIndex) ? frameIds[nextIndex] : (wraps ? frameIds[frameIds.count - 1] : currentValue)
        default:
            break
        }

        if let nextFrameId, !nextFrameId.isEmpty {
            setValue(nextFrameId, at: resolvedPath, in: &record.state)
        }
    }

    private static func pauseTimer(_ timer: inout StoredTemplateTimerState, nowMs: Int64) {
        timer.elapsedMs = min(timer.durationMs, timerElapsedMs(timer, nowMs: nowMs))
        timer.startedAtMs = nil
        timer.status = timerStatus(timer, nowMs: nowMs)
    }

    private static func resumeTimer(_ timer: inout StoredTemplateTimerState, nowMs: Int64) {
        if timer.status != "paused" {
            timer.elapsedMs = 0
        }
        timer.startedAtMs = nowMs
        timer.status = timer.durationMs > 0 ? "running" : "idle"
    }

    private static func applyTimerMutation(
        _ mutation: [String: Any],
        to record: inout TemplateRuntimeRecord,
        nowMs: Int64,
        actionId: String,
        sourceId: String?,
        payloadObject: [String: Any]?
    ) {
        guard let op = mutation["op"] as? String, let timerId = mutation["timerId"] as? String else {
            return
        }

        var timer = record.timers[timerId] ?? StoredTemplateTimerState(
            id: timerId,
            startedAtMs: nil,
            durationMs: 0,
            status: "idle",
            updatedAtMs: nowMs,
            elapsedMs: 0
        )

        if let durationMs = coerceInt64(mutation["durationMs"]) {
            timer.durationMs = max(0, durationMs)
        } else if let durationPath = mutation["durationPath"] as? String {
            let resolvedPath = resolveTemplateString(
                durationPath,
                record: record,
                nowMs: nowMs,
                actionId: actionId,
                sourceId: sourceId,
                payloadObject: payloadObject
            )
            timer.durationMs = max(
                0,
                coerceInt64(
                    resolveReference(
                        resolvedPath,
                        record: record,
                        nowMs: nowMs,
                        actionId: actionId,
                        sourceId: sourceId,
                        payloadObject: payloadObject
                    )
                ) ?? timer.durationMs
            )
        }

        switch op {
        case "start", "restart":
            timer.elapsedMs = 0
            timer.startedAtMs = nowMs
            timer.status = timer.durationMs > 0 ? "running" : "idle"
        case "pause":
            pauseTimer(&timer, nowMs: nowMs)
        case "resume":
            resumeTimer(&timer, nowMs: nowMs)
        case "toggle":
            if timerStatus(timer, nowMs: nowMs) == "running" {
                pauseTimer(&timer, nowMs: nowMs)
            } else {
                resumeTimer(&timer, nowMs: nowMs)
            }
        case "stop":
            timer.elapsedMs = 0
            timer.startedAtMs = nil
            timer.status = "stopped"
        case "reset":
            timer.elapsedMs = 0
            timer.startedAtMs = nil
            timer.status = "idle"
        case "setDuration":
            break
        default:
            break
        }

        timer.updatedAtMs = nowMs
        timer.status = timerStatus(timer, nowMs: nowMs)
        if timer.status == "finished" {
            timer.elapsedMs = timer.durationMs
            timer.startedAtMs = nil
        }
        record.timers[timerId] = timer
    }

    private static func normalizeStatePath(_ path: String) -> String {
        path.hasPrefix("state.") ? String(path.dropFirst("state.".count)) : path
    }

    private static func timerStatus(_ timer: StoredTemplateTimerState, nowMs: Int64) -> String {
        if timer.status == "stopped" {
            return "stopped"
        }

        let elapsedMs = timerElapsedMs(timer, nowMs: nowMs)
        if timer.durationMs <= 0 {
            return "idle"
        }
        if elapsedMs >= timer.durationMs {
            return "finished"
        }
        if timer.status == "paused" {
            return "paused"
        }
        if timer.startedAtMs != nil {
            return "running"
        }
        return elapsedMs > 0 ? "paused" : "idle"
    }

    private static func buildScope(
        record: TemplateRuntimeRecord,
        nowMs: Int64,
        actionId: String? = nil,
        sourceId: String? = nil,
        payloadObject: [String: Any]? = nil
    ) -> [String: Any] {
        var timers: [String: Any] = [:]
        for (timerId, timerState) in record.timers {
            timers[timerId] = serializeTimerBinding(timerState, nowMs: nowMs)
        }

        var scope: [String: Any] = [
            "state": record.state,
            "timers": timers,
            "meta": [
                "nowMs": nowMs,
                "activityId": record.activityId,
                "status": record.status,
                "openUrl": record.openUrl as Any,
                "revision": record.revision,
                "updatedAt": record.updatedAtMs,
                "template": [
                    "id": record.templateId,
                    "metadata": record.definition["metadata"] as Any
                ]
            ]
        ]

        if actionId != nil || sourceId != nil || payloadObject != nil {
            scope["action"] = [
                "id": actionId as Any,
                "sourceId": sourceId as Any,
                "payload": payloadObject as Any
            ]
        }

        return scope
    }

    private static func resolveReference(
        _ expression: String,
        record: TemplateRuntimeRecord,
        nowMs: Int64,
        actionId: String? = nil,
        sourceId: String? = nil,
        payloadObject: [String: Any]? = nil
    ) -> Any? {
        let scope = buildScope(
            record: record,
            nowMs: nowMs,
            actionId: actionId,
            sourceId: sourceId,
            payloadObject: payloadObject
        )

        if expression.hasPrefix("state.") || expression.hasPrefix("timers.") || expression.hasPrefix("meta.") || expression.hasPrefix("action.") {
            return getValue(at: expression, in: scope)
        }

        return getValue(at: expression, in: record.state)
    }

    private static func exactTokenValue(
        _ template: String,
        record: TemplateRuntimeRecord,
        nowMs: Int64,
        actionId: String? = nil,
        sourceId: String? = nil,
        payloadObject: [String: Any]? = nil
    ) -> Any? {
        let range = NSRange(template.startIndex..., in: template)
        guard let match = exactTokenRegex.firstMatch(in: template, options: [], range: range),
              let tokenRange = Range(match.range(at: 1), in: template)
        else {
            return nil
        }
        return resolveReference(
            String(template[tokenRange]),
            record: record,
            nowMs: nowMs,
            actionId: actionId,
            sourceId: sourceId,
            payloadObject: payloadObject
        )
    }

    private static func resolveTemplateString(
        _ template: String,
        record: TemplateRuntimeRecord,
        nowMs: Int64,
        actionId: String? = nil,
        sourceId: String? = nil,
        payloadObject: [String: Any]? = nil
    ) -> String {
        let matches = tokenRegex.matches(in: template, options: [], range: NSRange(template.startIndex..., in: template))
        var resolved = template

        for match in matches.reversed() {
            guard let expressionRange = Range(match.range(at: 1), in: resolved),
                  let fullRange = Range(match.range(at: 0), in: resolved)
            else {
                continue
            }

            let expression = String(resolved[expressionRange])
            let replacement = stringifyValue(
                resolveReference(
                    expression,
                    record: record,
                    nowMs: nowMs,
                    actionId: actionId,
                    sourceId: sourceId,
                    payloadObject: payloadObject
                )
            )
            resolved.replaceSubrange(fullRange, with: replacement)
        }

        return resolved
    }

    private static func stringifyValue(_ value: Any?) -> String {
        switch value {
        case nil, is NSNull:
            return ""
        case let string as String:
            return string
        case let number as NSNumber:
            return number.stringValue
        case let object as [String: Any]:
            guard let data = try? jsonData(from: object),
                  let string = String(data: data, encoding: .utf8)
            else {
                return ""
            }
            return string
        case let array as [Any]:
            guard JSONSerialization.isValidJSONObject(array),
                  let data = try? JSONSerialization.data(withJSONObject: array, options: []),
                  let string = String(data: data, encoding: .utf8)
            else {
                return ""
            }
            return string
        default:
            return "\(value ?? "")"
        }
    }

    private static func coerceInt64(_ value: Any?) -> Int64? {
        switch value {
        case let number as NSNumber:
            return number.int64Value
        case let string as String:
            return Int64(string)
        default:
            return nil
        }
    }

    private static func cloneJsonValue(_ value: Any) -> Any {
        switch value {
        case let object as [String: Any]:
            guard let data = try? jsonData(from: object),
                  let cloned = try? jsonObject(from: data)
            else {
                return object
            }
            return cloned
        case let array as [Any]:
            guard JSONSerialization.isValidJSONObject(array),
                  let data = try? JSONSerialization.data(withJSONObject: array, options: []),
                  let cloned = try? JSONSerialization.jsonObject(with: data, options: [])
            else {
                return array
            }
            return cloned
        default:
            return value
        }
    }

    private static func getValue(at path: String, in root: Any?) -> Any? {
        var current = root
        for segment in splitPath(path) {
            if let dictionary = current as? [String: Any] {
                current = dictionary[segment]
                continue
            }

            if let array = current as? [Any], let index = Int(segment), array.indices.contains(index) {
                current = array[index]
                continue
            }

            return nil
        }
        return current
    }

    private static func setValue(_ value: Any, at path: String, in root: inout [String: Any]) {
        let segments = splitPath(path)
        guard !segments.isEmpty else {
            return
        }
        var boxed: Any = root
        setValue(value, segments: segments, current: &boxed)
        root = boxed as? [String: Any] ?? root
    }

    private static func setValue(_ value: Any, segments: [String], current: inout Any) {
        guard let segment = segments.first else {
            current = value
            return
        }

        if segments.count == 1 {
            if var dictionary = current as? [String: Any] {
                dictionary[segment] = value
                current = dictionary
            } else if var array = current as? [Any], let index = Int(segment) {
                ensureArrayCapacity(&array, index: index)
                array[index] = value
                current = array
            } else {
                current = [segment: value]
            }
            return
        }

        if var dictionary = current as? [String: Any] {
            var next = dictionary[segment] ?? defaultContainer(for: segments[1])
            setValue(value, segments: Array(segments.dropFirst()), current: &next)
            dictionary[segment] = next
            current = dictionary
            return
        }

        if var array = current as? [Any], let index = Int(segment) {
            ensureArrayCapacity(&array, index: index)
            var next = array[index]
            if next is NSNull {
                next = defaultContainer(for: segments[1])
            }
            setValue(value, segments: Array(segments.dropFirst()), current: &next)
            array[index] = next
            current = array
            return
        }

        var dictionary: [String: Any] = [:]
        var next = defaultContainer(for: segments[1])
        setValue(value, segments: Array(segments.dropFirst()), current: &next)
        dictionary[segment] = next
        current = dictionary
    }

    private static func removeValue(at path: String, in root: inout [String: Any]) {
        let segments = splitPath(path)
        guard !segments.isEmpty else {
            return
        }
        var boxed: Any = root
        removeValue(segments: segments, current: &boxed)
        root = boxed as? [String: Any] ?? root
    }

    private static func removeValue(segments: [String], current: inout Any) {
        guard let segment = segments.first else {
            return
        }

        if segments.count == 1 {
            if var dictionary = current as? [String: Any] {
                dictionary.removeValue(forKey: segment)
                current = dictionary
            } else if var array = current as? [Any], let index = Int(segment), array.indices.contains(index) {
                array.remove(at: index)
                current = array
            }
            return
        }

        if var dictionary = current as? [String: Any], var next = dictionary[segment] {
            removeValue(segments: Array(segments.dropFirst()), current: &next)
            dictionary[segment] = next
            current = dictionary
        } else if var array = current as? [Any], let index = Int(segment), array.indices.contains(index) {
            var next = array[index]
            removeValue(segments: Array(segments.dropFirst()), current: &next)
            array[index] = next
            current = array
        }
    }

    private static func splitPath(_ path: String) -> [String] {
        path
            .split(separator: ".")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private static func defaultContainer(for nextSegment: String) -> Any {
        Int(nextSegment) != nil ? [Any]() : [String: Any]()
    }

    private static func ensureArrayCapacity(_ array: inout [Any], index: Int) {
        while array.count <= index {
            array.append(NSNull())
        }
    }
}
// swiftlint:enable type_body_length force_try function_parameter_count identifier_name file_length
