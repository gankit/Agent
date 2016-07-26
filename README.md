# Agent - An app to play with Google's Cloud Speech API

This app allows users to issue voice commands and remember stuff. Start recording by hitting the Record button and/or by pressing the main button with headphones plugged in. 

Commands should start with *read*, *watch*, *visit* or *remember*. For exampe: `watch The Big Short` will fetch the movie **The Big Short** using the OMDB API and save it to the local Code Data database. 

This app is based on [Google's Streaming gRPC sample app][sample-app]. It uses [Cloud Speech API](https://cloud.google.com/speech/) to recognize speech in recorded audio, [Goodreads API][goodreads-api] for Book search, [Yelp API][yelp-api] for Place search and [OMDB API][omdb-api] for Movie search.

## Prerequisites
- An API key for the Cloud Speech API (See
[the docs][getting-started] to learn more)
- An OSX machine or emulator
- [Xcode 7][xcode]
- [Cocoapods][cocoapods] version 1.0 or later
- API keys for [Goodreads][goodreads-api] and [Yelp][yelp-api].

## Quickstart
- Clone this repo and `cd` into this directory.
- Run `pod install` to download and build Cocoapods dependencies.
- Open the project by running `open Agent.xcworkspace`.
- In `Agent/SpeechRecognitionService.m`, replace `YOUR_GOOGLE_API_KEY` with the API key obtained above.
- In `Agent/SavedTableViewController.m`, replace `YOUR_GOODREADS_API_KEY` with the API key obtained from Goodreads.
- In `Agent/SavedTableViewController.m`, replace `YOUR_YELP_API_TOKEN` with the API token obtained from Yelp.
- Build and run the app.


## Running the app

- As with all Google Cloud APIs, every call to the Speech API must be associated
with a project within the [Google Cloud Console][cloud-console] that has the
Speech API enabled. This is described in more detail in the [getting started
doc][getting-started], but in brief:
- Create a project (or use an existing one) in the [Cloud
Console][cloud-console]
- [Enable billing][billing] and the [Speech API][enable-speech].
- Create an [API key][api-key], and save this for later.

- Clone this repository on GitHub. If you have [`git`][git] installed, you can do this by executing the following command:

$ git clone https://github.com/gankit/Agent.git

This will download the repository of samples into the directory
`ios-docs-samples`.

- `cd` into this directory in the repository you just cloned, and run the command `pod install` to prepare all Cocoapods-related dependencies.

- `open Agent.xcworkspace` to open this project in Xcode. Since we are using Cocoapods, be sure to open the workspace and not Agent.xcodeproj.

- In Xcode's Project Navigator, open the `SpeechRecognitionService.m` file within the `Speech` directory.

- Find the line where the `GOOGLE_API_KEY` is set. Replace the string value with the API key obtained from the Cloud console above. This key is the credential used to authenticate all requests to the Speech API. Calls to the API are thus associated with the project you created above, for access and billing purposes.

- You are now ready to build and run the project. In Xcode you can do this by clicking the 'Play' button in the top left. This will launch the app on the simulator or on the device you've selected. Be sure that the 'Agent' target is selected in the popup near the top left of the Xcode window. 

- Tap the `Record` button. This uses a custom AudioController class to capture audio in an in-memory instance of NSMutableData. When this data reaches a certain size, it is sent to the SpeechRecognitionService class, which streams it to the speech recognition service. Packets are streamed as instances of the RecognizeRequest object, and the first RecognizeRequest object sent also includes configuration information in an instance of InitialRecognizeRequest. As it runs, the AudioController logs the number of samples and average sample magnitude for each packet that it captures.

- Speak a command that starts with either *read*, *watch*, *visit* or *remember*

## Attribution
- Sounds from [RCP Tones](http://rcptones.com)
- Icon from [Icon Store](https://iconstore.co/icons/animals-pixel-art/)


[vision-zip]: https://github.com/GoogleCloudPlatform/cloud-vision/archive/master.zip
[getting-started]: https://cloud.google.com/vision/docs/getting-started
[cloud-console]: https://console.cloud.google.com
[git]: https://git-scm.com/
[xcode]: https://developer.apple.com/xcode/
[billing]: https://console.cloud.google.com/billing?project=_
[enable-speech]: https://console.cloud.google.com/apis/api/speech.googleapis.com/overview?project=_
[api-key]: https://console.cloud.google.com/apis/credentials?project=_
[cocoapods]: https://cocoapods.org/
[gRPC Objective-C setup]: https://github.com/grpc/grpc/tree/master/src/objective-c
[goodreads-api]: https://www.goodreads.com/api
[yelp-api]: https://www.yelp.com/developers/v3/preview
[sample-app]: https://github.com/GoogleCloudPlatform/ios-docs-samples/blob/master/speech/Objective-C/Speech-gRPC-Streaming/README.md
[omdb-api]: http://www.omdbapi.com/
