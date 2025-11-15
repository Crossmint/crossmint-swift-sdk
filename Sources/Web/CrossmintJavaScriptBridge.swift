public struct CrossmintJavaScriptBridge {
    private static let script = """
        (function() {
            // Keep original console methods
            const originalConsole = {
                log: console.log,
                error: console.error,
                warn: console.warn,
                info: console.info,
            };

            // Function to send messages to RN
            const postToRN = (type, args) => {
                try {
                    var seen = new Set(); // Declare seen here for function scope
                    // Attempt to serialize arguments, handling potential circular references safely
                    const serializedArgs = args.map(arg => {
                        // Basic type checking and string conversion
                        if (typeof arg === 'function') {
                            return '[Function]';
                        }
                        if (typeof arg === 'object' && arg !== null) {
                            try {
                                // Use a replacer function to handle potential circular references
                                return JSON.stringify(arg, (key, value) => {
                                    if (typeof value === 'object' && value !== null) {
                                        if (seen.has(value)) {
                                            return '[Circular Reference]';
                                        }
                                        seen.add(value);
                                    }
                                    return value;
                                }, 2); // Optional: pretty print JSON
                            } catch (e) {
                                return '[Unserializable Object]';
                            }
                        }
                        return String(arg); // Convert primitive types to string directly
                    });

                    const message = JSON.stringify({ type: 'console.' + type, data: serializedArgs });
                    if (window.ReactNativeWebView && typeof window.ReactNativeWebView.postMessage === 'function') {
                        window.ReactNativeWebView.postMessage(message);
                    } else {
                        originalConsole.warn('[Bridge] ReactNativeWebView.postMessage not available.');
                    }
                } catch (e) {
                    // Fallback if serialization fails completely
                    originalConsole.error('[Bridge] Error posting console message to RN:', e);
                }
            };

            // Override console methods
            console.log = (...args) => {
                originalConsole.log.apply(console, args); // Call original console.log
                postToRN('log', args);
            };
            console.error = (...args) => {
                originalConsole.error.apply(console, args); // Call original console.error
                postToRN('error', args);
            };
            console.warn = (...args) => {
                originalConsole.warn.apply(console, args); // Call original console.warn
                postToRN('warn', args);
            };
            console.info = (...args) => {
                originalConsole.info.apply(console, args); // Call original console.info
                postToRN('info', args);
            };

            // Existing message handler from RN
            window.onMessageFromNative = function(messageStr) {
                try {
                    const str = typeof messageStr === 'string' ? messageStr : JSON.stringify(messageStr);
                    const message = JSON.parse(str);
                    // dispatch standard MessageEvent
                    window.dispatchEvent(new MessageEvent('message', { data: message }));
                } catch (e) {
                    // Use the original console.error to avoid infinite loop if postToRN fails
                    originalConsole.error('[Bridge] Error handling message from RN:', e);
                }
            };
        })();
        """

    public static func communicationScript(bundleID: String?, handlerName: String) -> String {
        let reactNativeTransportAdapter = """
        window.ReactNativeWebView = { postMessage: function(message) {
            if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.\(handlerName)) {
                window.webkit.messageHandlers.\(handlerName).postMessage(message);
            } else {
                console.error('[Bridge] ReactNativeWebView.postMessage not available.');
            }
        }
        };\n
        """

        if let bundleID = bundleID {
            return "window.crossmintAppId = '\(bundleID)';\n" + reactNativeTransportAdapter + script
        }
        return reactNativeTransportAdapter + script
    }
}
