//
//  MyDataChDelegate.swift
//  ios-webrtc-test
//

import Foundation
import WebRTC

class MyDataChDelegate: NSObject, RTCDataChannelDelegate {
    
    var onReceiveMessageHandler: ((_ buffer: RTCDataBuffer) -> ())? = nil
    
    func dataChannelDidChangeState(_ dataChannel: RTCDataChannel) {
        print(">>data channel change state")
    }
    
    func dataChannel(_ dataChannel: RTCDataChannel, didReceiveMessageWith buffer: RTCDataBuffer) {
        print(">>data channel received message")
        self.onReceiveMessageHandler?(buffer)
    }
    
}
