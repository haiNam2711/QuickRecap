//
//  WhisperState.swift
//  QuickRecap
//
//  Created by haiNam2711 on 3/11/24.
//

import Foundation
import AVFoundation
import RxSwift
import ProgressHUD
import RxCocoa

class WhisperState: NSObject, AVAudioRecorderDelegate {
    // Observables
    private let _isModelLoaded = BehaviorRelay<Bool>(value: false)
    private let _messageLog = BehaviorRelay<String>(value: "")
    private let _canTranscribe = BehaviorRelay<Bool>(value: false)
    private let _isRecording = BehaviorRelay<Bool>(value: false)
    private let _nearestTranscription = BehaviorRelay<String?>(value: nil)
    
    // Public observers
    var isModelLoaded: Observable<Bool> { return _isModelLoaded.asObservable() }
    var messageLog: Observable<String> { return _messageLog.asObservable() }
    var canTranscribe: Observable<Bool> { return _canTranscribe.asObservable() }
    var isRecording: Observable<Bool> { return _isRecording.asObservable() }
    var nearestTranscription: Observable<String?> { return _nearestTranscription.asObservable() }
    
    private let disposeBag = DisposeBag()
    private var whisperContext: WhisperContext?
    private let recorder = Recorder()
    private var recordedFile: URL? = nil
    private var audioPlayer: AVAudioPlayer?
    
    private var modelUrl: URL? {
        Bundle.main.url(forResource: "ggml-base", withExtension: "bin")
    }
    
    private var sampleUrl: URL? {
        Bundle.main.url(forResource: "jfk", withExtension: "wav")
    }
    
    private enum LoadError: Error {
        case couldNotLocateModel
    }
    
    override init() {
        super.init()
        do {
            try loadModel()
            _canTranscribe.accept(true)
        } catch {
            print(error.localizedDescription)
            appendToMessageLog(error.localizedDescription)
        }
    }
    
    private func loadModel() throws {
        appendToMessageLog("Loading model...")
        if let modelUrl {
            whisperContext = try WhisperContext.createContext(path: modelUrl.path())
            appendToMessageLog("Loaded model \(modelUrl.lastPathComponent)")
        } else {
            appendToMessageLog("Could not locate model")
        }
    }
    
    func transcribeSample() {
        if let sampleUrl {
            transcribeAudio(sampleUrl)
        } else {
            appendToMessageLog("Could not locate sample")
        }
    }
    
    private func transcribeAudio(_ url: URL) {
        guard _canTranscribe.value else { return }
        guard let whisperContext else { return }
        
        _canTranscribe.accept(false)
        
        Observable.create { observer in
            do {
                self.appendToMessageLog("Reading wave samples...")
                let data = try self.readAudioSamples(url)
                self.appendToMessageLog("Transcribing data...")
                
                Task {
                    await whisperContext.fullTranscribe(samples: data)
                    let text = await whisperContext.getTranscription()
                    observer.onNext(text)
                    observer.onCompleted()
                }
            } catch {
                observer.onError(error)
            }
            return Disposables.create()
        }
        .observe(on: MainScheduler.instance)
        .subscribe(
            onNext: { [weak self] text in
                self?.stopPlayback()
                ProgressHUD.dismiss()
                self?.appendToMessageLog("Done: \(text)")
                self?._nearestTranscription.accept(text)
            },
            onError: { [weak self] error in
                self?.stopPlayback()
                ProgressHUD.dismiss()
                print(error.localizedDescription)
                self?.appendToMessageLog(error.localizedDescription)
            },
            onCompleted: { [weak self] in
                self?.stopPlayback()
                ProgressHUD.dismiss()
                self?._canTranscribe.accept(true)
            }
        )
        .disposed(by: disposeBag)
    }
    
    private func readAudioSamples(_ url: URL) throws -> [Float] {
        stopPlayback()
        try startPlayback(url)
        return try decodeWaveFile(url)
    }
    
    func toggleRecord() {
        if _isRecording.value {
            Task {
                await recorder.stopRecording()
                _isRecording.accept(false)
                DispatchQueue.main.async {
                    ProgressHUD.animate("Transcribing...")
                }
                if let recordedFile {
                    transcribeAudio(recordedFile)
                }
            }
        } else {
            requestRecordPermission()
                .subscribe(onNext: { [weak self] granted in
                    guard let self = self else { return }
                    if granted {
                        print("Recording permission granted")
                        Task {
                            do {
                                self.stopPlayback()
                                let file = try FileManager.default.url(for: .documentDirectory,
                                                                     in: .userDomainMask,
                                                                     appropriateFor: nil,
                                                                     create: true)
                                    .appending(path: "output.wav")
                                print("Recording to \(file)")
                                try await self.recorder.startRecording(toOutputFile: file, delegate: self)
                                print("Recording started")
                                self._isRecording.accept(true)
                                self.recordedFile = file
                            } catch {
                                print(error.localizedDescription)
                                self.appendToMessageLog(error.localizedDescription)
                                self._isRecording.accept(false)
                            }
                        }
                    }
                })
                .disposed(by: disposeBag)
        }
    }
    
    private func requestRecordPermission() -> Observable<Bool> {
        return Observable.create { observer in
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                observer.onNext(granted)
                observer.onCompleted()
            }
            return Disposables.create()
        }
    }
    
    private func startPlayback(_ url: URL) throws {
        audioPlayer = try AVAudioPlayer(contentsOf: url)
        audioPlayer?.play()
    }
    
    private func stopPlayback() {
        audioPlayer?.stop()
        audioPlayer = nil
    }
    
    private func appendToMessageLog(_ message: String) {
        _messageLog.accept(_messageLog.value + "\(message)\n")
    }
    
    // MARK: AVAudioRecorderDelegate
    
    func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        if let error {
            handleRecError(error)
        }
    }
    
    private func handleRecError(_ error: Error) {
        print(error.localizedDescription)
        appendToMessageLog(error.localizedDescription)
        _isRecording.accept(false)
    }
    
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        _isRecording.accept(false)
    }
}
