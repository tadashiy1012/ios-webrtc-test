//
//  MyPeerConnectionDelegate.swift
//  ios-webrtc-test
//

import Foundation
import SwiftyJSON
import Starscream
import WebRTC

class MyPeerConnectionDelegate: NSObject, RTCPeerConnectionDelegate {

    var onRemoteVideoHandler: ((_ stream: RTCMediaStream) -> ())? = nil
    var onNegotiationHandler: (() -> ())? = nil
    var onIceGatheringComplHandler: (() -> ())? = nil
    
    var start: Date? = nil
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange stateChanged: RTCSignalingState) {
        print(">>signalingState changed", stateChanged.rawValue)
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didAdd stream: RTCMediaStream) {
        print(">>add stream")
        self.onRemoteVideoHandler?(stream)
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove stream: RTCMediaStream) {
        print(">>remove stream")
    }
    
    func peerConnectionShouldNegotiate(_ peerConnection: RTCPeerConnection) {
        print(">>negotiation")
        self.onNegotiationHandler?()
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceConnectionState) {
        print(">>ice connection state", newState.rawValue)
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceGatheringState) {
        print(">>ice gathering state", newState.rawValue)
        if newState == RTCIceGatheringState.gathering {
            start = Date()
        } else if newState == RTCIceGatheringState.complete {
            let elapsed = Date().timeIntervalSince(start ?? Date())
            print("elapsed:" + elapsed.description)
            print("ice gathering compl. send sdp")
            self.onIceGatheringComplHandler?()
        }
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didGenerate candidate: RTCIceCandidate) {
        print(">>ice candidate generate")
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove candidates: [RTCIceCandidate]) {
        print(">>ice candidate remove")
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didOpen dataChannel: RTCDataChannel) {}
    
}
