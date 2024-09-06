// Copyright 2023 Daniel C Brotsky.  All rights reserved.
//
// All material in this project and repository is licensed under the
// GNU Affero General Public License v3. See the LICENSE file for details.

import SwiftUI

struct ListenControlView: View {
    @Environment(\.colorScheme) private var colorScheme
	@AppStorage("typing_volume_setting") private var typingVolume: Double = PreferenceData.typingVolume

    @Binding var size: FontSizes.FontSize
    @Binding var magnify: Bool
	@Binding var interjecting: Bool
	var maybeStop: () -> Void

    @State var alertSound = PreferenceData.alertSound
	@State var speaking: Bool = PreferenceData.speakWhenListening
	@State var typing: Bool = PreferenceData.hearTyping

    var body: some View {
		HStack(alignment: .center) {
			typingButton()
            speechButton()
            maybeFontSizeButtons()
            maybeFontSizeToggle()
			Button(action: { maybeStop() }) {
                stopButtonLabel()
            }
            .background(Color.accentColor)
            .cornerRadius(15)
        }
        .dynamicTypeSize(.large)
        .font(FontSizes.fontFor(FontSizes.minTextSize))
    }
    
	@ViewBuilder private func typingButton() -> some View {
		Menu {
			Button {
				typingVolume = 1
				PreferenceData.typingVolume = 1
			} label: {
				if typingVolume == 1 {
					Label("Loud Typing", systemImage: "checkmark.square")
				} else {
					Label("Loud Typing", systemImage: "speaker.wave.3")
				}
			}
			Button {
				typingVolume = 0.5
				PreferenceData.typingVolume = 0.5
			} label: {
				if typingVolume == 0.5 {
					Label("Medium Typing", systemImage: "checkmark.square")
				} else {
					Label("Medium Typing", systemImage: "speaker.wave.2")
				}
			}
			Button {
				typingVolume = 0.25
				PreferenceData.typingVolume = 0.25
			} label: {
				if typingVolume == 0.25 {
					Label("Quiet Typing", systemImage: "checkmark.square")
				} else {
					Label("Quiet Typing", systemImage: "speaker.wave.1")
				}
			}
		} label: {
			buttonImage(name: typing ? "typing-bubble" : "typing-no-bubble", pad: 5)
		} primaryAction: {
			typing.toggle()
			PreferenceData.hearTyping = typing
		}
		Spacer()
	}

	@ViewBuilder private func speechButton() -> some View {
		Button {
			speaking.toggle()
			PreferenceData.speakWhenListening = speaking
		} label: {
			buttonImage(name: speaking ? "voice-over-on" : "voice-over-off", pad: 5)
		}
		Spacer()
	}

    @ViewBuilder private func maybeFontSizeButtons() -> some View {
        if isOnPhone() {
            EmptyView()
        } else {
            Button {
                self.size = FontSizes.nextTextSmaller(self.size)
				PreferenceData.sizeWhenListening = self.size
            } label: {
				buttonImage(name: "font-down-button", pad: 0)
            }
            .disabled(size == FontSizes.minTextSize)
            Button {
                self.size = FontSizes.nextTextLarger(self.size)
				PreferenceData.sizeWhenListening = self.size
            } label: {
				buttonImage(name: "font-up-button", pad: 0)
            }
            .disabled(size == FontSizes.maxTextSize)
            Spacer()
        }
    }
    
    @ViewBuilder private func maybeFontSizeToggle() -> some View {
        if isOnPhone() {
            EmptyView()
        } else {
            Toggle(isOn: $magnify) {
                Text("Large Sizes")
            }
			.onChange(of: magnify) {
				PreferenceData.magnifyWhenListening = magnify
			}
            .frame(maxWidth: 105)
            Spacer()
        }
    }

	private func buttonImage(name: String, pad: CGFloat) -> some View {
		Image(name)
			.renderingMode(.template)
			.resizable()
			.padding(pad)
			.frame(width: 50, height: 50)
			.border(colorScheme == .light ? .black : .white, width: 1)
	}

    private func stopButtonLabel() -> some View {
        Text(isOnPhone() ? "Stop" : "Stop Listening")
            .foregroundColor(.white)
            .font(.body)
            .fontWeight(.bold)
            .padding(10)
    }

    private func isOnPhone() -> Bool {
        return UIDevice.current.userInterfaceIdiom == .phone
    }
}