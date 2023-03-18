// Copyright 2023 Daniel C Brotsky.  All rights reserved.
//
// All material in this project and repository is licensed under the
// GNU Affero General Public License v3. See the LICENSE file for details.

import SwiftUI

struct MainView: View {
    @State private var currentDeviceName: String = WhisperData.deviceName
    @State private var newDeviceName: String = WhisperData.deviceName
    @State private var mode: OperatingMode = MainViewModel.get_initial_mode()
    @StateObject private var model: MainViewModel = .init()
    
    var body: some View {
        if model.state != .poweredOn {
            Text("Enable Bluetooth to start scanning")
        } else {
            switch mode {
            case .ask:
                choiceView()
            case .listen:
                ListenView(mode: $mode)
            case .whisper:
                WhisperView(mode: $mode)
            }
        }
    }
    
    @ViewBuilder
    private func choiceView() -> some View {
        VStack(spacing: 60) {
            Form {
                Section(content: {
                    TextField("Whisperer Name", text: $newDeviceName, prompt: Text("Required for whispering"))
                        .onSubmit {
                            WhisperData.updateDeviceName(self.newDeviceName)
                            self.currentDeviceName = WhisperData.deviceName
                        }
                        .textInputAutocapitalization(TextInputAutocapitalization.never)
                        .disableAutocorrection(true)
                }, header: {
                    Text("Whisperer Name")
                })
            }
            .frame(maxWidth: 300, maxHeight: 105)
            HStack(spacing: 60) {
                VStack(spacing: 60) {
                    Button(action: { self.set_mode(.whisper) }) {
                        Text("Whisper")
                            .foregroundColor(.white)
                            .fontWeight(.bold)
                            .padding(10)
                    }
                    .background(WhisperData.deviceName == "" ? Color.gray : Color.accentColor)
                    .cornerRadius(15)
                    .disabled(currentDeviceName == "")
                    Button(action: { self.set_mode(.whisper, always: true) }) {
                        Text("Always\nWhisper")
                            .foregroundColor(.white)
                            .fontWeight(.bold)
                            .padding(10)
                    }
                    .background(WhisperData.deviceName == "" ? Color.gray : Color.accentColor)
                    .cornerRadius(15)
                    .disabled(currentDeviceName == "")
                }
                VStack(spacing: 60) {
                    Button(action: { self.set_mode(.listen) }) {
                        Text("Listen")
                            .foregroundColor(.white)
                            .fontWeight(.bold)
                            .padding(EdgeInsets(top: 10, leading: 25, bottom: 10, trailing: 25))
                    }
                    .background(Color.accentColor)
                    .cornerRadius(15)
                    Button(action: { self.set_mode(.listen, always: true) }) {
                        Text("Always\nListen")
                            .foregroundColor(.white)
                            .fontWeight(.bold)
                            .padding(EdgeInsets(top: 10, leading: 20, bottom: 10, trailing: 20))
                    }
                    .background(Color.accentColor)
                    .cornerRadius(15)
                }
            }
        }
    }
    
    private func set_mode(_ mode: OperatingMode, always: Bool = false) {
        self.mode = mode
        if always {
            MainViewModel.save_initial_mode(mode)
        } else {
            MainViewModel.save_initial_mode(.ask)
        }
    }
}

struct MainView_Previews: PreviewProvider {
    static var previews: some View {
        MainView()
    }
}