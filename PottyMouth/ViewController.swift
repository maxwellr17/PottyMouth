//
//  ViewController.swift
//  PottyMouth
//
//  Created by Maxwell Roling on 8/25/18.
//  Copyright © 2018 Maxwell Roling. All rights reserved.
//

import UIKit
import Speech
import AVFoundation
import AudioToolbox

class ViewController: UIViewController, SFSpeechRecognizerDelegate {
    
    //UI elements
    @IBOutlet weak var textLabel: UILabel!
    @IBOutlet weak var startStopButton: UIButton!
    @IBOutlet weak var mostRecentSwear: UILabel!
    @IBOutlet weak var numberOfSwears: UILabel!
    
    //brief list of swear words
    private var swearWords = ["ass", "asshole", "bastard", "bitch", "crap", "cunt", "damn","fuck", "goddamn", "hell", "motherfucker", "shit"]
    
    //vars to track recent swears
    private var transcription = ""
    private var mostRecentSwearString = ""
    private var numberOfSwearsInt = 0
  
    //vars to control voice transcription
    private let engine = AVAudioEngine()
    private var task: SFSpeechRecognitionTask?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale.init(identifier: "en-US"))
    
    //vars to control audio playback
    private var beep: AVAudioPlayer?
    var player: AVAudioPlayer!
    
    
    //logic to present an alert to the user
    func showAlert(title_alert: String, message_alert: String) {
        
        let alert = UIAlertController(title: title_alert, message: message_alert, preferredStyle: .alert)
        self.present(alert, animated: true)
    }
    
    //delegate method
    func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        if available {
            startStopButton.isEnabled = true
        } else {
            startStopButton.isEnabled = false
        }
    }
    
    //default setup when view loads
    override func viewDidLoad() {
        super.viewDidLoad()
        
        startStopButton.isEnabled = false
        speechRecognizer?.delegate = self
        
        SFSpeechRecognizer.requestAuthorization { (status) in
            var enabled = false
            
            switch status {
            case .authorized:
                enabled = true
                
            case .denied:
                enabled = false
                print("User denied access to speech recognition")
                self.showAlert(title_alert: "Error Occured", message_alert: "Oops... You have denied access to speech recognition")
                
            case .restricted:
                enabled = false
                print("Speech recognition restricted on this device")
                self.showAlert(title_alert: "Error Occured", message_alert: "Speech recognition restricted on this device")
                
            case .notDetermined:
                enabled = false
                print("Speech recognition not yet authorized")
                self.showAlert(title_alert: "Error Occured", message_alert: "Oops... You have not yet allowed access to speech recognition")
            }
            
            OperationQueue.main.addOperation() {
                self.startStopButton.isEnabled = enabled
            }
            
        }
        
    }
    
    //logic to start and stop listening
    @IBAction func startStopClicked(_ sender: Any) {
        if engine.isRunning {
            engine.stop()
            request?.endAudio()
            startStopButton.isEnabled = false
            startStopButton.setTitle("Start", for: .normal)
        } else {
            start()
            startStopButton.setTitle("Stop", for: .normal)
        }
    }
        
    //reduces amount of processing required for detecting swear words by only
    //looking at unprocessed parts of the transcription
    func removePartOfString(input: String, remove:String) -> String {
        let inputLower = input.lowercased()
        let removeLower = remove.lowercased()
        
        if (inputLower.hasPrefix(removeLower)) {
            return String(inputLower.dropFirst(removeLower.count))
        }
        print("remove not contained in input")
        return ""
    }
    
    
    
    
    //logic to start the voice transcription
    func start() {
        
        transcription = ""
        mostRecentSwearString = "None"
        numberOfSwearsInt = 0
        
        mostRecentSwear.text = "Most Recent Swear: " + mostRecentSwearString
        numberOfSwears.text = "Number of Swears: " + String(numberOfSwearsInt)
        
        if task != nil {
            task?.cancel()
            task = nil
        }
        
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(AVAudioSessionCategoryRecord)
            try session.setMode(AVAudioSessionModeMeasurement)
            try session.setActive(true, with: .notifyOthersOnDeactivation)
            
        } catch {
            print("audioSession properties weren't set because of an error.")
            self.showAlert(title_alert: "Error Occured", message_alert: "Error creating an audio session. Please restart the application and try again.")
            
        }
        
        request = SFSpeechAudioBufferRecognitionRequest()
        let inputNode = engine.inputNode
        guard let request = request else {
            self.showAlert(title_alert: "Terrible No Good Very Bad Error Occured", message_alert: "Error creating an audio session. Please restart the application and try again.")
            fatalError("Unable to create an SFSpeechAudioBufferRecognitionRequest object")
        }
        
        request.shouldReportPartialResults = true
        task = speechRecognizer?.recognitionTask(with: request, resultHandler: { (result, error) in
            
            var isEnd = false
            
            if result != nil {
                //updated voice transcription recieved
                
                //self.textLabel.text = result?.bestTranscription.formattedString
                let allTranscription = (result?.bestTranscription.formattedString)!
                let toCount = self.removePartOfString(input: allTranscription, remove: self.transcription)
                self.textLabel.text = toCount
                self.countSwearWords(input: toCount)
                self.transcription = allTranscription
                
                isEnd = (result?.isFinal)!
            }
            if error != nil || isEnd {
                //voice transcription complete
                self.engine.stop()
                inputNode.removeTap(onBus: 0)
                
                self.request = nil
                self.task = nil
                self.startStopButton.isEnabled = true
            }
        })
        
        let format = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { (buffer, when) in
            self.request?.append(buffer)
        }
        
        engine.prepare()
        
        do {
            try engine.start()
            
        } catch {
            print("audioEngine couldn't start because of an error.")
            self.showAlert(title_alert: "Error Occured", message_alert: "Error occured with starting audio engine")

        }
        textLabel.text = "Watch your PottyMouth!"
    }
    
    
    func countSwearWords (input: String) {
        let words = input.components(separatedBy: " ")
        for word in words {
            if swearWords.contains(word) {
                print("detected swear word")
                numberOfSwearsInt += 1
                mostRecentSwearString = word
                
                mostRecentSwear.text = "Most Recent Swear: " + mostRecentSwearString
                numberOfSwears.text = "Number of Swears: " + String(numberOfSwearsInt)
                
                //play irritating sound every time swear word is detected
                self.playSound()
                
            }
        }
    }
    

    func playSound() {
        //set up beep audio playback
        guard let path = Bundle.main.path(forResource: "beepSound", ofType: "wav") else {
            print("url not found")
            return
        }

        do {
            player = try AVAudioPlayer(contentsOf: URL(fileURLWithPath: path))
            print(path)
            print((player!.play()))
        }
        catch {
            print("Error occured loading file")
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

}

