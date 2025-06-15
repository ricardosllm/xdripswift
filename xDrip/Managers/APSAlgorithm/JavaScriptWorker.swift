import Foundation
import JavaScriptCore

private let contextLock = NSRecursiveLock()

final class JavaScriptWorker {
    private let processQueue = DispatchQueue(label: "DispatchQueue.JavaScriptWorker")
    private let virtualMachine: JSVirtualMachine
    @SyncAccess(lock: contextLock) private var commonContext: JSContext? = nil
    private var capturedLogs: [String] = []

    init() {
        virtualMachine = processQueue.sync { JSVirtualMachine()! }
    }

    private func createContext() -> JSContext {
        let context = JSContext(virtualMachine: virtualMachine)!
        context.exceptionHandler = { [weak self] _, exception in
            if let error = exception?.toString() {
                trace("JavaScript Error: %{public}@", log: .default, category: ConstantsLog.categoryRootView, type: .error, error)
                self?.capturedLogs.append("JS Error: \(error)")
            }
        }
        let consoleLog: @convention(block) (String) -> Void = { [weak self] message in
            if message.count > 3 { // Remove the cryptic test logs created during development of Autosens
                trace("JavaScript log: %{public}@", log: .default, category: ConstantsLog.categoryRootView, type: .debug, message)
                self?.capturedLogs.append("JS Log: \(message)")
            }
        }
        
        let consoleError: @convention(block) (String) -> Void = { [weak self] message in
            trace("JavaScript error: %{public}@", log: .default, category: ConstantsLog.categoryRootView, type: .error, message)
            self?.capturedLogs.append("JS Error: \(message)")
        }

        context.setObject(
            consoleLog,
            forKeyedSubscript: "_consoleLog" as NSString
        )
        
        context.setObject(
            consoleError,
            forKeyedSubscript: "_consoleError" as NSString
        )
        
        // Set up console object
        context.evaluateScript("""
            var console = {
                log: function() {
                    var args = Array.prototype.slice.call(arguments);
                    var message = args.map(function(arg) {
                        if (typeof arg === 'object') {
                            try {
                                return JSON.stringify(arg);
                            } catch (e) {
                                return String(arg);
                            }
                        }
                        return String(arg);
                    }).join(' ');
                    _consoleLog(message);
                },
                error: function() {
                    var args = Array.prototype.slice.call(arguments);
                    var message = args.map(function(arg) {
                        if (typeof arg === 'object') {
                            try {
                                return JSON.stringify(arg);
                            } catch (e) {
                                return String(arg);
                            }
                        }
                        return String(arg);
                    }).join(' ');
                    _consoleError(message);
                }
            };
        """)
        
        return context
    }

    @discardableResult func evaluate(script: Script) -> JSValue! {
        evaluate(string: script.body)
    }

    private func evaluate(string: String) -> JSValue! {
        let ctx = commonContext ?? createContext()
        return ctx.evaluateScript(string)
    }

    private func json(for string: String) -> RawJSON {
        evaluate(string: "JSON.stringify(\(string), null, 4);")!.toString()!
    }

    func call(function: String, with arguments: [JSON]) -> RawJSON {
        let joined = arguments.map(\.rawJSON).joined(separator: ",")
        return json(for: "\(function)(\(joined))")
    }

    func inCommonContext<Value>(execute: (JavaScriptWorker) -> Value) -> Value {
        commonContext = createContext()
        defer {
            commonContext = nil
        }
        return execute(self)
    }
    
    func getCapturedLogs() -> [String] {
        return capturedLogs
    }
    
    func clearCapturedLogs() {
        capturedLogs.removeAll()
    }
}
