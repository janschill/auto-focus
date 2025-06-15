import Foundation

class NativeMessagingHost {
    static let shared = NativeMessagingHost()
    private var inputData = Data()
    private weak var browserManager: BrowserManager?

    private init() {}

    func setBrowserManager(_ manager: BrowserManager) {
        self.browserManager = manager
    }

    func startListening() {
        DispatchQueue.global(qos: .background).async {
            self.readFromStdin()
        }
    }

    private func readFromStdin() {
        while true {
            // Read 4 bytes for message length
            var lengthBytes = Data(count: 4)
            let lengthRead = lengthBytes.withUnsafeMutableBytes { buffer in
                return read(STDIN_FILENO, buffer.baseAddress, 4)
            }

            guard lengthRead == 4 else {
                print("Failed to read message length")
                continue
            }

            // Convert to message length
            let messageLength = lengthBytes.withUnsafeBytes { buffer in
                return buffer.load(as: UInt32.self).littleEndian
            }

            guard messageLength > 0 && messageLength < 1024 * 1024 else {
                print("Invalid message length: \(messageLength)")
                continue
            }

            // Read message data
            var messageData = Data(count: Int(messageLength))
            let messageRead = messageData.withUnsafeMutableBytes { buffer in
                return read(STDIN_FILENO, buffer.baseAddress, Int(messageLength))
            }

            guard messageRead == messageLength else {
                print("Failed to read complete message")
                continue
            }

            // Parse and handle message
            handleMessage(messageData)
        }
    }

    private func handleMessage(_ data: Data) {
        do {
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            guard let message = json else {
                print("Invalid JSON message")
                return
            }

            print("Received native message: \(message)")

            // Create NativeMessage and forward to BrowserManager
            if let command = message["command"] as? String {
                let nativeMessage = NativeMessage(command: command, data: message)
                DispatchQueue.main.async {
                    self.browserManager?.handleNativeMessage(nativeMessage)
                }
            }

        } catch {
            print("Error parsing native message: \(error)")
        }
    }

    func sendMessage(_ message: [String: Any]) {
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: message)
            let length = UInt32(jsonData.count).littleEndian

            // Write length (4 bytes) then message
            let lengthData = withUnsafeBytes(of: length) { Data($0) }

            lengthData.withUnsafeBytes { buffer in
                write(STDOUT_FILENO, buffer.baseAddress, 4)
            }

            jsonData.withUnsafeBytes { buffer in
                write(STDOUT_FILENO, buffer.baseAddress, jsonData.count)
            }

            fflush(stdout)

        } catch {
            print("Error sending native message: \(error)")
        }
    }
}
