//
//  MyDCPeerConnectionDelegate.swift
//  ios-webrtc-test
//

import Foundation
import WebRTC

class MyDCPeerConnectionDelegate: NSObject, RTCPeerConnectionDelegate {
    
    var onNegotiationHandler: (() -> ())? = nil
    var onIceGatheringComplHandler: (() -> ())? = nil
    var onDataChannelOpenHandler: (() -> ())? = nil
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange stateChanged: RTCSignalingState) {
        print(">>signalingState changed dc", stateChanged.rawValue)
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didAdd stream: RTCMediaStream) {
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove stream: RTCMediaStream) {
    }
    
    func peerConnectionShouldNegotiate(_ peerConnection: RTCPeerConnection) {
        print(">>negotiation dc")
        self.onNegotiationHandler?()
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceConnectionState) {
        print(">>ice connection state dc", newState.rawValue)
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceGatheringState) {
        print(">>ice gathering state dc", newState.rawValue)
        if newState == RTCIceGatheringState.complete {
            print("ice gathering complete dc")
            self.onIceGatheringComplHandler?()
        }
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didGenerate candidate: RTCIceCandidate) {
        print(">>ice candidate generate dc")
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove candidates: [RTCIceCandidate]) {
        print(">>ice candidate remove dc")
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didOpen dataChannel: RTCDataChannel) {
        print(">>data channel open")
        self.onDataChannelOpenHandler?()
    }
    
}
