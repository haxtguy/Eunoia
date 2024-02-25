//
//  ContentView.swift
//  Eunoia
//
//  Created by Justin Hudacsko on 2/24/24.
//

import SwiftUI
import Foundation
import AVFoundation
import Speech
import Charts

class AudioRecorderViewModel: ObservableObject {
    var audioRecorder: AVAudioRecorder?
    var currentIndex = 10
    @Published var isRecording = false
    @Published var transcription: String?
    @Published var response: String?
    let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-GB"))
    
    @Published var moods: [Mood] = [
        Mood(value: 0.2, day: 0),
        Mood(value: -0.3, day: 1),
        Mood(value: 0.4, day: 2),
        Mood(value: 0.3, day: 3),
        Mood(value: 0.5, day: 4),
        Mood(value: 0.7, day: 5),
        Mood(value: 0.6, day: 6),
        Mood(value: 0.65, day: 7),
        Mood(value: 0.7, day: 8),
        Mood(value: 0.4, day: 9),
        ]
    
    func requestMicrophoneAccess() {
        AVAudioSession.sharedInstance().requestRecordPermission { granted in
            if granted {
                print("Microphone access granted")
            } else {
                print("Microphone access denied")
            }
        }
    }
    
    func startRecording() {
        let audioFilename = getDocumentsDirectory().appendingPathComponent("hithere.m4a")
        
        let settings = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 8000,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.low.rawValue
        ]
        
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playAndRecord, mode: .default)
            try audioSession.setActive(true)
            
            audioRecorder = try AVAudioRecorder(url: audioFilename, settings: settings)
            audioRecorder?.record()
            isRecording = true
        } catch {
            print("Error: \(error)")
        }
    }
    
    func stopRecording() {
        audioRecorder?.stop()
        isRecording = false
    }
    
    private func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    func requestTranscribePermissions() {
        SFSpeechRecognizer.requestAuthorization { [unowned self] authStatus in
            DispatchQueue.main.async {
                if authStatus == .authorized {
                    print("Good")
                } else {
                    print(" permission was declined.")
                }
            }
        }
    }
    
    func transcribeAudio(url: URL) {
        let request = SFSpeechURLRecognitionRequest(url: url)

        recognizer?.recognitionTask(with: request) { [unowned self] (result, error) in
            guard let result = result else {
                print("There was an error: \(error!)")
                return
            }

            if result.isFinal {
                transcription = result.bestTranscription.formattedString
                let parameters = MoodParameters(text: result.bestTranscription.formattedString)
                Task {
                    do {
                        let x = try await postMood(parameters: parameters)
                        response = x.response
                        moods.append(Mood(value: x.polarity, day: currentIndex))
                        currentIndex += 1
                    } catch {
                        print("error")
                    }
                }
            }
        }
    }
    
    func getRecordingURL() -> URL {
        let documentsDirectory = getDocumentsDirectory()
        let audioFilename = documentsDirectory.appendingPathComponent("hithere.m4a")
        return audioFilename
    }
    
    func postMood(parameters: Encodable) async throws -> MoodResponse {
        let url = URL(string: "http://127.0.0.1:5000/mood")!
        
        var postData: Data?  = nil
        guard let encodedParameters = try? JSONEncoder().encode(parameters) else {
            throw APIError.error
        }
        postData = encodedParameters
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = postData
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let response = response as? HTTPURLResponse, response.statusCode == 200 else {
            throw APIError.error
        }
                
        guard let decodedResponse = try? JSONDecoder().decode(MoodResponse.self, from: data) else {
            throw APIError.error
        }
                
        return decodedResponse
    }
}

struct ContentView: View {
    @StateObject private var audioRecorderViewModel = AudioRecorderViewModel()
    @State private var appear = false
    @State private var aboutMood = false

    var body: some View {
        VStack(spacing: 0) {
            Section {
                VStack(alignment: .leading) {
                    HStack(alignment: .center, spacing: 5) {
                        Text("Your Mood")
                            .font(.title2.smallCaps())
                            .bold()
                        
                        Button(action: { aboutMood.toggle() }) {
                            Image(systemName: "questionmark.circle.fill")
                                .imageScale(.small)
                                .offset(y: 2)
                                .foregroundStyle(.blue.opacity(0.7))
                        }
                    }
                    
                    Chart {
                        ForEach(audioRecorderViewModel.moods.suffix(10)) { mood in
                            LineMark(
                                x: PlottableValue.value("Day", mood.day),
                                y: PlottableValue.value("Value", mood.value)
                            )
                            .symbol(.circle)
                        }
                    }
                    .padding(.bottom, 25)
                    
                    Text("Log")
                        .font(.title2.smallCaps())
                        .bold()
                        .padding(.top)
                    
                    RoundedRectangle(cornerRadius: 15)
                        .fill(Color(white: 0.1))
                        .stroke(.blue, lineWidth: 1.5)
                        .overlay(
                            Text(audioRecorderViewModel.transcription ?? "Tap the microphone to start recording your thoughts")
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                                .font(.title3)
                                .fontWeight(.medium)
                                .padding(20)
                                .foregroundStyle(audioRecorderViewModel.transcription != nil ? .white : .white.opacity(0.5))
                        )
                }
                .frame(maxHeight: .infinity)
            } header: {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Welcome to Eunoia")
                        .bold()
                        .font(.largeTitle)
                    
                    Text("Your mindfulness journey begins here")
                    
                    Divider()
                        .overlay(
                            RoundedRectangle(cornerRadius: 5)
                                .fill(.white)
                        )
                }
            } footer: {
                ZStack(alignment: .center) {
                    if audioRecorderViewModel.isRecording {
                        Circle()
                            .scale(appear ? 1.0 : 4/7)
                            .animation(
                                .easeOut(duration: 2).repeatForever(autoreverses: false)
                            )
                            .frame(width: 140, height: 140)
                            .foregroundStyle(appear ? .blue.opacity(0.1) : .blue.opacity(0.8))
                            .onAppear {
                                appear = true
                            }
                            .onDisappear {
                                appear = false
                            }
                    }
                        
                    Button(action: {
                        if audioRecorderViewModel.isRecording {
                            audioRecorderViewModel.stopRecording()
                            audioRecorderViewModel.requestTranscribePermissions()
                            let audioURL = audioRecorderViewModel.getRecordingURL()
                            audioRecorderViewModel.transcribeAudio(url: audioURL)
                        } else {
                            print("HJAPPY DAY")
                            audioRecorderViewModel.requestMicrophoneAccess()
                            audioRecorderViewModel.startRecording()
                        }
                    }) {
                        Circle()
                            .frame(width: 75, height: 75)
                            .overlay(
                                Image(systemName: audioRecorderViewModel.isRecording ? "stop.fill" : "mic.fill")
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 25, height: 25)
                                    .foregroundStyle(.white)
                            )
                    }
                }
            }
            .sheet(isPresented: Binding<Bool>(
                get: { audioRecorderViewModel.response != nil },
                set: {_ in }
            ), onDismiss: { audioRecorderViewModel.response = nil }) {
                SheetView(text: audioRecorderViewModel.response!)
                    .presentationDetents([.fraction(0.4)])
            }
            .sheet(isPresented: $aboutMood, onDismiss: { aboutMood = false }) {
                AboutView()
                    .presentationDetents([.fraction(0.45)])
            }
            .preferredColorScheme(.dark)
            .padding()
        }
    }
}

struct SheetView: View {
    var text: String
    
    var body: some View {
        VStack(alignment: .leading) {
            VStack(alignment: .leading, spacing: 5) {
                Text("Eunoia's Response")
                    .font(.title)
                    .bold()
                
                Divider()
                    .overlay(
                        RoundedRectangle(cornerRadius: 5)
                            .fill(.white)
                            .frame(height: 1)
                    )
            }
            .frame(width: 260)
            .padding(.bottom, 10)
            
            Text(text)
                .lineSpacing(5)
        }
        .padding()
        .frame(maxHeight: .infinity, alignment: .top)
        .preferredColorScheme(.dark)
    }
}

struct AboutView: View {
    var body: some View {
        VStack(alignment: .leading) {
            VStack(alignment: .leading, spacing: 5) {
                Text("Mood Chart")
                    .font(.title)
                    .bold()
                
                Divider()
                    .overlay(
                        RoundedRectangle(cornerRadius: 5)
                            .fill(.white)
                            .frame(height: 1)
                    )
            }
            .frame(width: 165)
            .padding(.bottom, 10)
            
            Text("Every time you log a Eunote, a natural language processor analyzes what you've said, and gives you a personalized response, as well as a 'mood score', essentially a score of happy you were when you created the log. That value is a decimal between -1 and 1, and is then plotted on this graph so you can see your general mood trend over time.")
                .lineSpacing(5)
            
            Spacer()
            
            Text("The chart plots the last 10 Eunotes.")
                .font(.footnote)
        }
        .padding()
        .frame(maxHeight: .infinity, alignment: .top)
        .preferredColorScheme(.dark)
    }
}

enum APIError: Error {
    case error
}

struct Mood: Identifiable {
    var id = UUID()
    var value: Float
    var day: Int
}


struct MoodParameters: Codable {
    var text: String
}


struct MoodResponse: Codable {
    var response: String
    var polarity: Float
}

#Preview {
    ContentView()
}


