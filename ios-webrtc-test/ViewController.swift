//
//  ViewController.swift
//  ios-webrtc-test
//

import UIKit
import AVFoundation
import WebRTC
import Starscream
import SwiftyJSON

class ViewController: UIViewController, WebSocketDelegate {
    
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
        } else if data["type"]?.rawString() == "produce_dc" {
            print("bingo!!")
            let answer = RTCSessionDescription(type: RTCSdpType.answer, sdp: (data["sdp"]?.rawString())!)
            dcpc.setRemoteDescription(answer) { (err) in
                print(err ?? "set dc remote desc no error")
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
    var dcpc: RTCPeerConnection! = nil
    var remoteVideoTrack: RTCVideoTrack! = nil
    var localVideoTrack: RTCVideoTrack! = nil
    var capture: RTCCameraVideoCapturer! = nil
    var pcDelegate: MyPeerConnectionDelegate? = nil
    var dcpcDelegate: MyDCPeerConnectionDelegate? = nil
    var dataChannel: RTCDataChannel? = nil
    var dataChannelDelegate: MyDataChDelegate? = nil
    
    override func viewDidLoad() {
        super.viewDidLoad()
        RTCInitializeSSL()
        uuid = NSUUID().uuidString
        print("uuid:", uuid!)
        ws = WebSocket(url: URL(string: "wss://cloud.achex.ca")!)
        ws.delegate = self
        let encoderFactory = RTCDefaultVideoEncoderFactory()
        let decoderFactory = RTCDefaultVideoDecoderFactory()
        factory = RTCPeerConnectionFactory(encoderFactory: encoderFactory, decoderFactory: decoderFactory)
        let config = RTCConfiguration()
        config.iceServers = [RTCIceServer(urlStrings: ["stun:stun.l.google.com:19302"])]
        //config.sdpSemantics = .unifiedPlan
        config.bundlePolicy = .maxBundle
        config.rtcpMuxPolicy = .require
        let constraints = RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: nil)
        pcDelegate = MyPeerConnectionDelegate()
        pcDelegate?.onRemoteVideoHandler = { stream in
            self.remoteVideoTrack = stream.videoTracks[0]
            self.remoteVideoTrack.add(self.remoteVideoView)
        }
        pcDelegate?.onNegotiationHandler = {
            self.makeOffer()
        }
        pcDelegate?.onIceGatheringComplHandler = {
            self.sendSdp()
        }
        pc = factory.peerConnection(with: config, constraints: constraints, delegate: pcDelegate)
        dcpcDelegate = MyDCPeerConnectionDelegate()
        dcpcDelegate?.onNegotiationHandler = {
            self.makeDcOffer()
        }
        dcpcDelegate?.onIceGatheringComplHandler = {
            self.sendDcSdp()
        }
        dcpc = factory.peerConnection(with: config, constraints: constraints, delegate: dcpcDelegate)
        let dcConfig = RTCDataChannelConfiguration()
        dataChannel = dcpc.dataChannel(forLabel: "chat", configuration: dcConfig)
        dataChannelDelegate = MyDataChDelegate()
        dataChannelDelegate?.onReceiveMessageHandler = { buffer in
            print(buffer.isBinary)
            print(buffer.data)
        }
        dataChannel?.delegate = dataChannelDelegate
        startVideo()
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
        print("local stream added!")
    }
    
    func makeOffer() {
        let constraints = RTCMediaConstraints(mandatoryConstraints: [
            kRTCMediaConstraintsOfferToReceiveAudio: kRTCMediaConstraintsValueTrue,
            kRTCMediaConstraintsOfferToReceiveVideo: kRTCMediaConstraintsValueTrue
        ], optionalConstraints: nil)
        pc.offer(for: constraints) { (desc, err) in
            print(err ?? "offer create no error")
            if let offer = desc {
                self.pc.setLocalDescription(offer, completionHandler: { (err) in
                    print(err ?? "offer set no error")
                })
            }
        }
    }
    
    func makeDcOffer() {
        let constraints = RTCMediaConstraints(mandatoryConstraints: [:], optionalConstraints: nil)
        dcpc.offer(for: constraints) { (desc, err) in
            print(err ?? "dc offer create no error")
            if let offer = desc {
                self.dcpc.setLocalDescription(offer, completionHandler: { (err) in
                    print(err ?? "dc offer set no error")
                })
            }
        }
    }
    
    func sendSdp() {
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
    
    func sendDcSdp() {
        let sdp = dcpc.localDescription?.sdp
        let json = JSON([
            "to": "default@890",
            "type": "consume_dc",
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
    
    deinit {
        capture.stopCapture()
        pc.close()
        factory = nil
        RTCCleanupSSL()
    }

}
