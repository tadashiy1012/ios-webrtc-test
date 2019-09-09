//
//  ViewController.swift
//  ios-webrtc-test
//

import UIKit
import AVFoundation
import WebRTC
import Starscream
import SwiftyJSON

class ViewController: UIViewController, WebSocketDelegate, RTCPeerConnectionDelegate {
    
    // RTCPeerConnection delegate func
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange stateChanged: RTCSignalingState) {
        print(">>signalingState changed", stateChanged.rawValue)
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didAdd stream: RTCMediaStream) {
        print(">>add stream")
        remoteVideoTrack = stream.videoTracks[0]
        remoteVideoTrack.add(remoteVideoView)
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove stream: RTCMediaStream) {
        print(">>remove stream")
    }
    
    func peerConnectionShouldNegotiate(_ peerConnection: RTCPeerConnection) {
        print(">>negotiation")
        makeOffer()
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceConnectionState) {
        print(">>ice connection state", newState.rawValue)
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceGatheringState) {
        print(">>ice gathering state", newState.rawValue)
        if newState == RTCIceGatheringState.complete {
            print("ice gathering compl. send sdp")
            let sdp = pc.localDescription?.sdp
            let json = JSON([
                "to": "default@890",
                "type": "consume",
                "key": "default",
                "uuid": uuid,
                "sdp": sdp
            ])
            DispatchQueue.main.async {
                Timer.scheduledTimer(withTimeInterval: 3, repeats: true, block: { (timer) in
                    if self.ws.isConnected {
                        print("exec send")
                        self.ws.write(string: json.rawString(String.Encoding.utf8, options: [])!)
                        timer.invalidate()
                    } else {
                        print("pending...")
                    }
                })
            }
        }
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didGenerate candidate: RTCIceCandidate) {
        print(">>ice candidate generate")
        pc.add(candidate)
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove candidates: [RTCIceCandidate]) {
        print(">>ice candidate remove")
        pc.remove(candidates)
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didOpen dataChannel: RTCDataChannel) {}
    
    
    // websocket delegate func
    
    func websocketDidConnect(socket: WebSocketClient) {
        print(">>websocket connected")
        let auth = JSON(["auth":"consume@890", "password":"0749637637"])
        ws.write(string: auth.rawString([.castNilToNSNull: true])!)
    }
    
    func websocketDidDisconnect(socket: WebSocketClient, error: Error?) {
        print(">>websocket disconnected")
    }
    
    func websocketDidReceiveMessage(socket: WebSocketClient, text: String) {
        print(">>websocket received message")
        print(text)
        let data = JSON(parseJSON: text).dictionaryValue
        print(data)
        if data["type"]?.rawString() == "produce" {
            print("bingo!")
            let answer = RTCSessionDescription(type: RTCSdpType.answer, sdp: (data["sdp"]?.rawString())!)
            pc.setRemoteDescription(answer) { (err) in
                print(err ?? "set remote desc no error")
            }
        }
    }
    
    func websocketDidReceiveData(socket: WebSocketClient, data: Data) {}
    
    // main
    
    @IBOutlet weak var remoteVideoView: RTCEAGLVideoView!
    @IBOutlet weak var localVideoView: RTCEAGLVideoView!
    
    var uuid: String! = nil
    var ws: WebSocket! = nil
    var factory: RTCPeerConnectionFactory! = nil
    var pc: RTCPeerConnection! = nil
    var remoteVideoTrack: RTCVideoTrack! = nil
    var localVideoTrack: RTCVideoTrack! = nil
    var capture: RTCCameraVideoCapturer! = nil
    
    override func viewDidLoad() {
        super.viewDidLoad()
        RTCInitializeSSL()
        uuid = NSUUID().uuidString
        print("uuid:", uuid!)
        let encoderFactory = RTCDefaultVideoEncoderFactory()
        let decoderFactory = RTCDefaultVideoDecoderFactory()
        factory = RTCPeerConnectionFactory(encoderFactory: encoderFactory, decoderFactory: decoderFactory)
        let config = RTCConfiguration()
        config.iceServers = [RTCIceServer(urlStrings: ["stun:stun.l.google.com:19302"])]
        //config.sdpSemantics = .unifiedPlan
        config.bundlePolicy = .maxBundle
        config.rtcpMuxPolicy = .require
        let constraints = RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: nil)
        pc = factory.peerConnection(with: config, constraints: constraints, delegate: self)
        startVideo()
        ws = WebSocket(url: URL(string: "wss://cloud.achex.ca")!)
        ws.delegate = self
        ws.connect()
    }
    
    func getCamera() -> AVCaptureDevice {
        let deviceDiscoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [AVCaptureDevice.DeviceType.builtInWideAngleCamera], mediaType: AVMediaType.video, position: AVCaptureDevice.Position.unspecified)
        let devices = deviceDiscoverySession.devices
        let device = devices.filter { (e) -> Bool in
            e.position == AVCaptureDevice.Position.front
        }.first!
        return device
    }
    
    func getFormat(tgtDevice: AVCaptureDevice) -> AVCaptureDevice.Format {
        let formats = RTCCameraVideoCapturer.supportedFormats(for: tgtDevice)
        let targetWidth = Int32(320)
        let targetHeight = Int32(240)
        var selectedFormat: AVCaptureDevice.Format?
        var currentDiff: Int32 = Int32.max
        for format in formats {
            let dimension = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
            let diff = abs(targetWidth - dimension.width) + abs(targetHeight - dimension.height)
            if diff < currentDiff {
                selectedFormat = format
                currentDiff = diff
            }
        }
        return selectedFormat!
    }
    
    func startVideo() {
        let audioSrc = factory.audioSource(with: nil)
        let videoSrc = factory.videoSource()
        let audioTrack = factory.audioTrack(with: audioSrc, trackId: "audioTrack1")
        let videoTrack = factory.videoTrack(with: videoSrc, trackId: "videoTrack1")
        self.localVideoTrack = videoTrack
        capture = RTCCameraVideoCapturer(delegate: videoSrc)
        let camera = getCamera()
        let format = getFormat(tgtDevice: camera)
        capture.startCapture(with: camera, format: format, fps: 30)
        self.localVideoTrack.add(localVideoView)
        let streamId = "stream1"
        let stream = factory.mediaStream(withStreamId: streamId)
        stream.addAudioTrack(audioTrack)
        stream.addVideoTrack(videoTrack)
        pc.add(stream)
    }
    
    func makeOffer() {
        pc.offer(for: RTCMediaConstraints(mandatoryConstraints: [
            kRTCMediaConstraintsOfferToReceiveAudio: kRTCMediaConstraintsValueTrue,
            kRTCMediaConstraintsOfferToReceiveVideo: kRTCMediaConstraintsValueTrue
        ], optionalConstraints: nil)) { (desc, err) in
            print(err ?? "no error")
            if let offer = desc {
                self.pc.setLocalDescription(offer, completionHandler: { (err) in
                    print(err ?? "no error")
                })
            }
        }
    }
    
    deinit {
        capture.stopCapture()
        pc.close()
        factory = nil
        RTCCleanupSSL()
    }

}
