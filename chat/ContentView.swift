//
//  ContentView.swift
//  chat
//
//  Created by Jashan on 08/06/21.
//

import SwiftUI
import PubNub

struct ContentView: View {

  @ObservedObject var pubnubStore: PubNubStore
  @State var entry = "Hello There."

  var body: some View {
    VStack {
      Spacer()

      TextField("", text: $entry, onCommit: submitUpdate)
        .textFieldStyle(RoundedBorderTextFieldStyle())
        .frame(width: 300.0, height: 40)

      Spacer()

      Button(action: submitUpdate) {
        Text("SEND MESSAGE")
          .padding()
          .foregroundColor(Color.white)
          .background(entry.isEmpty ? Color.secondary : Color.red)
          .cornerRadius(40)
      }
      .disabled(entry.isEmpty)
      .frame(width: 300.0)

      Spacer()

      List {
        ForEach(pubnubStore.messages.reversed()) { message in
          VStack(alignment: .leading) {
            Text(message.messageType)
            Text(message.messageText)
          }
        }
      }

      Spacer()
    }
  }

  func submitUpdate() {
    if !self.entry.isEmpty {
      pubnubStore.publish(update: EntryUpdate(update: self.entry))
      self.entry = ""
    }

    // Hides keyboard
    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
  }
}

// MARK:- View Stores
class PubNubStore: ObservableObject {
  @Published var messages: [Message] = []

  var pubnub: PubNub
  let channel: String = "the_guide"
  let clientUUID: String = "ReplaceWithYourClientIdentifier"

  init() {
    var pnconfig = PubNubConfiguration(publishKey: "pub-c-79e4530a-d425-44c5-9add-709143b66083", subscribeKey: "sub-c-a3ded094-c826-11eb-a9de-a6433017f026")
    pnconfig.uuid = clientUUID

    self.pubnub = PubNub(configuration: pnconfig)

    startListening()
    subscribe(to: self.channel)
  }

  lazy var listener: SubscriptionListener? = {
    let listener = SubscriptionListener()

    listener.didReceiveMessage = { [weak self] event in
      if let entry = try? event.payload.codableValue.decode(EntryUpdate.self) {

        self?.display(
          Message(messageType: "[MESSAGE: received]", messageText: "entry: \(entry.entry), update: \(entry.update)")
        )
      }
    }

    listener.didReceiveStatus = { [weak self] event in
      switch event {
      case .success(let connection):
        print("Status Success: \(connection.isConnected)")
      case .failure(let error):
        print("Status Error: \(error.localizedDescription)")
      }
    }

    return listener
  }()

  func startListening() {
    if let listener = listener {
      pubnub.add(listener)
    }
  }

  func subscribe(to channel: String) {
    pubnub.subscribe(to: [channel], withPresence: true)
  }

  func display(_ message: Message) {
    self.messages.append(message)
  }

  func publish(update entryUpdate: EntryUpdate) {
    pubnub.publish(channel: self.channel, message: entryUpdate) { [weak self] result in
      switch result {
      case let .success(timetoken):
        print("success: \(timetoken)")
      case let .failure(error):
        print("failed: \(error.localizedDescription)")
      }
    }
  }
}

// MARK:- Models

struct EntryUpdate: JSONCodable {
  var update: String
  var entry: String

  init(update: String, entry: String = "User") {
    self.update = update
    self.entry = entry
  }
}

struct Message: Identifiable {
  var id = UUID()
  var messageType: String
  var messageText: String
}

// MARK:- Extension Helpers
extension DateFormatter {
  static let defaultTimetoken: DateFormatter = {
    var formatter = DateFormatter()
    formatter.timeStyle = .medium
    formatter.dateStyle = .short
    formatter.locale = Locale(identifier: "en_US_POSIX")
    return formatter
  }()
}

extension Timetoken {
  var formattedDescription: String {
    return DateFormatter.defaultTimetoken.string(from: timetokenDate)
  }
}

// MARK:- View Preview
struct ContentView_Previews: PreviewProvider {
  static let store = PubNubStore()

  static var previews: some View {
    ContentView(pubnubStore: store)
  }
}
