//
//  RemoteDebugging.swift
//  Recordings
//
//  Created by Chris Eidhof on 24.05.18.
//

import UIKit

extension UIView {
	func capture() -> UIImage? {
		let format = UIGraphicsImageRendererFormat()
		format.opaque = isOpaque
		let renderer = UIGraphicsImageRenderer(size: frame.size, format: format)
		return renderer.image { _ in
			drawHierarchy(in: frame, afterScreenUpdates: true)
		}
	}
}

struct DebugWrapper<A: Encodable>: Encodable {
	var state: A
	var action: String
	var imageData: String // base64-encoded
}

enum WriteError: Error, Equatable {
    case eof
    case other(Int)
}
extension OutputStream {
	func write(_ data: Data) throws -> Int {
        assert(!data.isEmpty, "Empty data will be interpreted as EOF")
		let result = data.withUnsafeBytes {
			self.write($0, maxLength: data.count)
		}
        if result == 0 { throw WriteError.eof }
        if result < 0 { throw WriteError.other(result) }
        return result
	}
}

typealias JSONObject = Any
enum Result<L, R> {
	case success(L)
	case error(R)
}



// https://github.com/turn/json-over-tcp#protocol
class JSONOverTCPDecoder {
    var payloadLength: Int?
    var buffer = Data()
    var callback: (Data?) -> () = { _ in ()}
    
    func receive(_ data: Data) {
        buffer.append(data)
        var canContinue: Bool {
            if buffer.isEmpty { return false }
            if buffer.count > 5 && payloadLength == nil { return true }
            if let c = payloadLength, buffer.count >= c { return true }
            return false
        }
        while canContinue {
            if payloadLength == nil {
                guard buffer.removeFirst() == 206 else {
                    // Protocol signature error
                    callback(nil)
                    return
                }
                assert(buffer.count >= 4) // todo
                let lengthBytes = buffer.prefix(4)
                buffer.removeFirst(4)
                let length: Int32 = lengthBytes.withUnsafeBytes { $0.pointee }
                payloadLength = Int(length)
            }
            if let c = payloadLength, buffer.count >= c {
                let data = buffer.prefix(c)
                buffer.removeFirst(c)
                callback(data)
                payloadLength = nil
            }
        }
    }
}

class Reader: NSObject, StreamDelegate {
    var onData: (Data) -> () = { _ in () }
    var streamDidEnd: (_ success: Bool) -> () = { _ in () }
    
    func stream(_ stream: Stream, handle eventCode: Stream.Event) {
        switch eventCode {
        case .openCompleted:
            ()
        case .errorOccurred:
            streamDidEnd(false)
        case.endEncountered:
            streamDidEnd(true)
        case .hasBytesAvailable:
            readBytes(stream as! InputStream)
        default:
            print("Uknown event: \(eventCode)")
            ()
        }
    }
    
    func readBytes(_ stream: InputStream) {
        while stream.hasBytesAvailable {
            var d = Data(count: 1024)
            let count = d.withUnsafeMutableBytes { body in
                stream.read(body, maxLength: 1024)
            }
            guard count != 0 else { print("eof"); return }
            if count < 0 { fatalError() }
            onData(d[0..<count])
        }
    }
}

class Writer: NSObject, StreamDelegate {
    let chunkSize = 1024
    let outputStream: OutputStream
    var remainder = Data()
    let onEnd: (Writer) -> ()
    init(_ outputStream: OutputStream, onEnd: @escaping (Writer) -> ()) {
        self.outputStream = outputStream
        self.onEnd = onEnd
        super.init()
        outputStream.delegate = self
    }
    
    func resume() {
        if remainder.isEmpty { return }
        while outputStream.streamStatus == .open && outputStream.hasSpaceAvailable && !remainder.isEmpty {
            let chunk = remainder.prefix(chunkSize)
            do {
                let bytesWritten = try outputStream.write(chunk)
                remainder.removeFirst(bytesWritten)
            } catch {
                if let e = error as? WriteError, e == .eof, remainder.isEmpty { continue }
                dump(error)
                print("Couldn't write")
            }
        }
    }
    
    func write(_ data: Data) {
        remainder.append(data)
        resume()
    }
    
    func stream(_ aStream: Stream, handle eventCode: Stream.Event) {
        switch eventCode {
        case .openCompleted:
            resume()
        case .errorOccurred:
            onEnd(self)
        case.endEncountered:
            onEnd(self)
        case .hasSpaceAvailable:
            resume()
        default:
            print("other event: \(eventCode)")
            ()
        }
    }
}

class RemoteDebugger: NSObject, NetServiceBrowserDelegate {
	let browser = NetServiceBrowser()
	var connections: [Connection] = []
	let queue = DispatchQueue(label: "DebugService")
	let encoder = JSONEncoder()
    
    struct Connection {
        var inputStream: InputStream
        var outputStream: OutputStream
        var reader: Reader
        var writer: Writer
    }
	
	var onData: ((Data?) -> ())? = nil

	override init() {
		super.init()
		browser.delegate = self
		browser.searchForServices(ofType: "_debug._tcp", inDomain: "local")
	}
	
	func netServiceBrowser(_ browser: NetServiceBrowser, didNotSearch errorDict: [String : NSNumber]) {
		print("did not search: \(errorDict)")
	}
	
	func netServiceBrowser(_ browser: NetServiceBrowser, didFind service: NetService, moreComing: Bool) {
        var input: InputStream? = nil
        var output: OutputStream? = nil
        service.getInputStream(&input, outputStream: &output)
		CFReadStreamSetDispatchQueue(input, queue)
        CFWriteStreamSetDispatchQueue(output, queue)
        let reader = Reader()
		let receiver = JSONOverTCPDecoder()
		reader.onData = receiver.receive
		reader.streamDidEnd = { [unowned self] success in
            guard let index = self.connections.index(where: { $0.reader == reader }) else { return }
            self.close(connectionAtIndex: index)
		}
		receiver.callback = { [unowned self] result in
			guard let d = result else { fatalError() }
			self.onData?(d)
		}
        input!.delegate = reader
		input!.open()
        output!.open()
        let writer = Writer(output!) { [unowned self] w in
            guard let i = self.connections.index(where: { $0.writer == w }) else { fatalError() }
            self.close(connectionAtIndex: i)
        }
		connections.append(Connection(inputStream: input!, outputStream: output!, reader: reader, writer: writer))
	}
    
    func close(connectionAtIndex index: Int) {
        let c = connections[index]
        c.inputStream.close()
        c.outputStream.close()
        self.connections.remove(at: index)

    }
	
    // Write using the TCP over JSON protocol:
    // - first a 206 byte
    // - then an UInt32 with the length (encoded as 4 bytes)
    // - then the JSON data
	private func write(jsonData: Data) {
        queue.async {
            var encodedLength = Data(count: 4)
            encodedLength.withUnsafeMutableBytes { $0.pointee = Int32(jsonData.count) }
            let data: Data = [206] + encodedLength + jsonData
            for c in self.connections {
                c.writer.write(data)
            }
        }
	}

	func write<State>(action: String, state: State, snapshot: UIView) throws where State: Encodable {
		let screenshot = snapshot.capture()!
		let data = UIImagePNGRepresentation(screenshot)!.base64EncodedString()
        let jsonData = try! encoder.encode(DebugWrapper<State>(state: state, action: action, imageData: data))
        try! jsonData.write(to: URL(fileURLWithPath: "/Users/chris/Downloads/test2.json"))
        assert((try? JSONSerialization.jsonObject(with: jsonData, options: [])) != nil)
		try? write(jsonData: jsonData)
	}
}
