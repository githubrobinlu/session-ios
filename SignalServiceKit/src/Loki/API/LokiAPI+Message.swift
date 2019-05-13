import PromiseKit

public extension LokiAPI {
    
    public struct Message {
        /// The hex encoded public key of the receiver.
        let destination: String
        /// The content of the message.
        let data: LosslessStringConvertible
        /// The time to live for the message.
        let ttl: UInt64
        /// When the proof of work was calculated, if applicable.
        ///
        /// - Note: Expressed as milliseconds since 00:00:00 UTC on 1 January 1970.
        let timestamp: UInt64?
        /// The base 64 encoded proof of work, if applicable.
        let nonce: String?
        
        public init(destination: String, data: LosslessStringConvertible, ttl: UInt64, timestamp: UInt64?, nonce: String?) {
            self.destination = destination
            self.data = data
            self.ttl = ttl
            self.timestamp = timestamp
            self.nonce = nonce
        }
        
        /// Construct a `LokiMessage` from a `SignalMessage`.
        ///
        /// - Note: `timestamp` is the original message timestamp (i.e. `TSOutgoingMessage.timestamp`).
        public static func from(signalMessage: SignalMessage, timestamp: UInt64, requiringPoW isPoWRequired: Bool) -> Promise<Message> {
            // To match the desktop application, we have to wrap the data in an envelope and then wrap that in a websocket object
            return Promise<Message> { seal in
                DispatchQueue.global(qos: .default).async {
                    do {
                        let wrappedMessage = try wrap(message: signalMessage, timestamp: timestamp)
                        let data = wrappedMessage.base64EncodedString()
                        let destination = signalMessage["destination"] as! String
                        let ttl = LokiAPI.defaultMessageTTL
                        if isPoWRequired {
                            // timeIntervalSince1970 returns a time interval in seconds but the storage server takes a time interval in milliseconds
                            let now = UInt64(Date().timeIntervalSince1970 * 1000)
                            if let nonce = ProofOfWork.calculate(data: data, pubKey: destination, timestamp: now, ttl: ttl) {
                                let result = Message(destination: destination, data: data, ttl: ttl, timestamp: now, nonce: nonce)
                                seal.fulfill(result)
                            } else {
                                seal.reject(Error.proofOfWorkCalculationFailed)
                            }
                        } else {
                            let result = Message(destination: destination, data: data, ttl: ttl, timestamp: nil, nonce: nil)
                            seal.fulfill(result)
                        }
                    } catch let error {
                        seal.reject(error)
                    }
                }
            }
        }

        public func toJSON() -> JSON {
            var result = [ "pubKey" : destination, "data" : data.description, "ttl" : String(ttl) ]
            if let timestamp = timestamp, let nonce = nonce {
                result["timestamp"] = String(timestamp)
                result["nonce"] = nonce
            }
            return result
        }
    }
}