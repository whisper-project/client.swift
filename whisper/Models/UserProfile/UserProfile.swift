// Copyright 2023 Daniel C Brotsky.  All rights reserved.
//
// All material in this project and repository is licensed under the
// GNU Affero General Public License v3. See the LICENSE file for details.

import Foundation
import Combine
import CryptoKit

protocol Conversation: Identifiable, Equatable, Comparable {
	var id: String { get }
	var name: String { get }
}

extension Conversation {
	static func ==(_ left: Self, _ right: Self) -> Bool {
		return left.id == right.id
	}
}

final class UserProfile: Identifiable, ObservableObject {
	static private(set) var shared = load() ?? create()

	private(set) var id: String
	private(set) var name: String = ""
	private(set) var whisperProfile: WhisperProfile
	private(set) var listenProfile: ListenProfile
	@Published private(set) var userPassword: String
	private var serverPassword: String
	@Published private(set) var timestamp = Date.now

	private init() {
		let profileId = UUID().uuidString
		id = profileId
		userPassword = ""
		serverPassword = ""
		whisperProfile = WhisperProfile(profileId)
		listenProfile = ListenProfile(profileId)
	}

	private init(id: String, name: String, password: String) {
		self.id = id
		self.name = name
		userPassword = password
		if password.isEmpty {
			serverPassword = ""
		} else {
			serverPassword = SHA256.hash(data: Data(password.utf8)).compactMap{ String(format: "%02x", $0) }.joined()
		}
		whisperProfile = WhisperProfile.load(id, serverPassword: serverPassword) ?? WhisperProfile(id)
		listenProfile = ListenProfile.load(id, serverPassword: serverPassword) ?? ListenProfile(id)
	}

	var username: String {
		get { name }
		set(newName) {
			guard name != newName else {
				// nothing to do
				return
			}
			name = newName
			postUsername()
			save()
		}
	}

	private func save(verb: String = "PUT", localOnly: Bool = false) {
		timestamp = Date.now
		let localValue = ["id": id, "name": name, "password": userPassword]
		guard let localData = try? JSONSerialization.data(withJSONObject: localValue) else {
			fatalError("Can't encode user profile data: \(localValue)")
		}
		guard localData.saveJsonToDocumentsDirectory("UserProfile") else {
			fatalError("Can't save user profile data")
		}
		if !localOnly && !serverPassword.isEmpty {
			let serverValue = ["id": id, "name": name, "password": serverPassword]
			guard let serverData = try? JSONSerialization.data(withJSONObject: serverValue) else {
				fatalError("Can't encode user profile data: \(serverValue)")
			}
			saveToServer(data: serverData, verb: verb)
		}
	}

	static private func load() -> UserProfile? {
		if let data = Data.loadJsonFromDocumentsDirectory("UserProfile"),
		   let obj = try? JSONSerialization.jsonObject(with: data),
		   let value = obj as? [String:String],
		   let id = value["id"],
		   let name = value["name"],
		   let password = value["password"]
		{
			return UserProfile(id: id, name: name, password: password)
		}
		return nil
	}

	private static func create() -> UserProfile {
		let profile = UserProfile()
		profile.save()
		return profile
	}

	private func saveToServer(data: Data, verb: String = "PUT") {
		let path = "/api/v2/userProfile" + (verb == "PUT" ? "/\(id)" : "")
		guard let url = URL(string: PreferenceData.whisperServer + path) else {
			fatalError("Can't create URL for user profile upload")
		}
		var request = URLRequest(url: url)
		request.httpMethod = verb
		if verb == "PUT" {
			request.setValue("Bearer \(serverPassword)", forHTTPHeaderField: "Authorization")
		}
		request.setValue("application/json", forHTTPHeaderField: "Content-Type")
		request.setValue(PreferenceData.clientId, forHTTPHeaderField: "X-Client-Id")
		request.httpBody = data
		Data.executeJSONRequest(request)
	}

	func update() {
		guard !serverPassword.isEmpty else {
			// not a shared profile, so no way to update
			return
		}
		func handler(_ code: Int, _ data: Data) {
			if code == 200,
			   let obj = try? JSONSerialization.jsonObject(with: data),
			   let value = obj as? [String:String],
			   let name = value["name"]
			{
				DispatchQueue.main.async {
					self.name = name
					self.save(localOnly: true)
				}
			}
		}
		let path = "/api/v2/userProfile/\(id)"
		guard let url = URL(string: PreferenceData.whisperServer + path) else {
			fatalError("Can't create URL for user profile download")
		}
		var request = URLRequest(url: url)
		request.setValue("Bearer \(serverPassword)", forHTTPHeaderField: "Authorization")
		request.setValue("\"\(self.name)\"", forHTTPHeaderField: "If-None-Match")
		request.setValue(PreferenceData.clientId, forHTTPHeaderField: "X-Client-Id")
		request.httpMethod = "GET"
		Data.executeJSONRequest(request, handler: handler)
		func notifyChange() {
			// we want our observed object to change when the whisper profile is updated
			DispatchQueue.main.async {
				self.timestamp = Date.now
			}
		}
		whisperProfile.update(notifyChange)
		listenProfile.update(notifyChange)
	}

	func stopSharing() {
		// reset the profile, but leave the name alone
		id = UUID().uuidString
		userPassword = ""
		serverPassword = ""
		whisperProfile = WhisperProfile(id)
		listenProfile = ListenProfile(id)
		save()
	}

	func startSharing() {
		// set the password, post the profile to server
		let letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789~!@#$%_+-="
		userPassword = String((0..<20).map{ _ in letters.randomElement()! })
		serverPassword = SHA256.hash(data: Data(userPassword.utf8)).compactMap{ String(format: "%02x", $0) }.joined()
		save(verb: "POST")
		whisperProfile.startSharing(serverPassword: serverPassword)
		listenProfile.startSharing(serverPassword: serverPassword)
	}

	func receiveSharing(id: String, password: String, completionHandler: @escaping (Bool, String) -> Void) {
		// try to update from the server.  If that fails, reset the whisper and listen profiles,
		// because they may have been loaded successfully from the server.
		func loadHandler(_ success: Bool, _ message: String) {
			if !success {
				userPassword = ""
				serverPassword = ""
				whisperProfile = WhisperProfile(self.id)
				listenProfile = ListenProfile(self.id)
			}
			completionHandler(success, message)
		}
		loadShared(id: id, password: password, completionHandler: loadHandler)
	}

	func loadShared(id: String, password: String, completionHandler: @escaping (Bool, String) -> Void) {
		guard !password.isEmpty else {
			fatalError("Can't use an empty password with a shared profile")
		}
		let serverPassword = SHA256.hash(data: Data(password.utf8)).compactMap{ String(format: "%02x", $0) }.joined()
		var whichUpdate = "name"
		var newName = name
		func dualHandler(_ result: Int) {
			switch result {
			case 200:
				if whichUpdate == "name" {
					whichUpdate = "whisper"
					whisperProfile.loadShared(id: id, serverPassword: serverPassword, completionHandler: dualHandler)
				} else if whichUpdate == "whisper" {
					whichUpdate = "listen"
					listenProfile.loadShared(id: id, serverPassword: serverPassword, completionHandler: dualHandler)
				} else {
					DispatchQueue.main.async {
						self.id = id
						self.name = newName
						self.userPassword = password
						self.serverPassword = serverPassword
						self.save(localOnly: true)
						completionHandler(true, "The profile was successfully shared to this device")
					}
				}
			case 403:
				completionHandler(false, "You have specified an incorrect password")
			case 404:
				completionHandler(false, "There is no profile with that Profile ID")
			case 409:
				completionHandler(false, "This profile is already shared from another device? Please report a bug.")
			case -1:
				completionHandler(false, "The whisper server returned invalid profile data. Please report a bug.")
			default:
				completionHandler(false, "There was a problem on the Whisper server: error code \(result).  Please try again.")
			}
		}
		func nameHandler(_ code: Int, _ data: Data) {
			if code < 200 || code >= 300 {
				dualHandler(code)
			} else if let obj = try? JSONSerialization.jsonObject(with: data),
					  let value = obj as? [String:String],
					  let name = value["name"]
			{
				newName = name
				dualHandler(200)
			} else {
				dualHandler(-1)
			}
		}
		let path = "/api/v2/userProfile/\(id)"
		guard let url = URL(string: PreferenceData.whisperServer + path) else {
			fatalError("Can't create URL for user profile download")
		}
		var request = URLRequest(url: url)
		request.setValue("Bearer \(serverPassword)", forHTTPHeaderField: "Authorization")
		request.setValue(PreferenceData.clientId, forHTTPHeaderField: "X-Client-Id")
		request.httpMethod = "GET"
		Data.executeJSONRequest(request, handler: nameHandler)
	}

	private func postUsername() {
		guard userPassword.isEmpty else {
			// this is a shared profile, the change will be posted automatically
			return
		}
		let path = "/api/v2/username"
		guard let url = URL(string: PreferenceData.whisperServer + path) else {
			fatalError("Can't create URL for username upload")
		}
		let localValue = [ "id": id, "name": username ]
		guard let localData = try? JSONSerialization.data(withJSONObject: localValue) else {
			fatalError("Can't encode user profile data: \(localValue)")
		}
		var request = URLRequest(url: url)
		request.httpMethod = "POST"
		request.setValue("application/json", forHTTPHeaderField: "Content-Type")
		request.setValue(PreferenceData.clientId, forHTTPHeaderField: "X-Client-Id")
		request.httpBody = localData
		logger.info("Posting updated username for profile \(self.id) to the server")
		Data.executeJSONRequest(request)
	}
}