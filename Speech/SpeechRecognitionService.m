//
// Copyright 2016 Google Inc. All Rights Reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

#import "SpeechRecognitionService.h"

#import <GRPCClient/GRPCCall.h>
#import <RxLibrary/GRXBufferedPipe.h>
#import <ProtoRPC/ProtoRPC.h>

#define API_KEY @"AIzaSyCfQ4XpgLZmn1_M8SLrAnae59-clyjnmT8"
#define HOST @"speech.googleapis.com"

@interface SpeechRecognitionService ()

@property (nonatomic, assign) BOOL streaming;
@property (nonatomic, strong) Speech *client;
@property (nonatomic, strong) GRXBufferedPipe *writer;
@property (nonatomic, strong) GRPCProtoCall *call;

@end

@implementation SpeechRecognitionService

+ (instancetype) sharedInstance {
  static SpeechRecognitionService *instance = nil;
  if (!instance) {
    instance = [[self alloc] init];
    instance.sampleRate = 16000.0; // default value
  }
  return instance;
}

- (void) streamAudioData:(NSData *) audioData
          withCompletion:(SpeechRecognitionCompletionHandler)completion {

  if (!_streaming) {
    // if we aren't already streaming, set up a gRPC connection
    _client = [[Speech alloc] initWithHost:HOST];
    _writer = [[GRXBufferedPipe alloc] init];
    _call = [_client RPCToStreamingRecognizeWithRequestsWriter:_writer
                                         eventHandler:^(BOOL done, StreamingRecognizeResponse *response, NSError *error) {
                                           completion(response, error);
                                         }];

    // authenticate using an API key obtained from the Google Cloud Console
    _call.requestHeaders[@"X-Goog-Api-Key"] = API_KEY;
    NSLog(@"HEADERS: %@", _call.requestHeaders);

    [_call start];
    _streaming = YES;

    // send an initial request message to configure the service
    RecognitionConfig *recognitionConfig = [RecognitionConfig message];
    recognitionConfig.encoding = RecognitionConfig_AudioEncoding_Linear16;
    recognitionConfig.sampleRate = self.sampleRate;
    recognitionConfig.languageCode = @"en-US";
    recognitionConfig.maxAlternatives = 30;
      recognitionConfig.speechContext.phrasesArray = [NSMutableArray arrayWithObjects:@"yes", @"no", @"watch", @"read", nil];
    StreamingRecognitionConfig *streamingRecognitionConfig = [StreamingRecognitionConfig message];
    streamingRecognitionConfig.config = recognitionConfig;
    streamingRecognitionConfig.singleUtterance = YES;
    streamingRecognitionConfig.interimResults = YES;
      
    StreamingRecognizeRequest *streamingRecognizeRequest = [StreamingRecognizeRequest message];
    streamingRecognizeRequest.streamingConfig = streamingRecognitionConfig;

    [_writer writeValue:streamingRecognizeRequest];
  }

  // send a request message containing the audio data
  StreamingRecognizeRequest *streamingRecognizeRequest = [StreamingRecognizeRequest message];
  streamingRecognizeRequest.audioContent = audioData;
  [_writer writeValue:streamingRecognizeRequest];
}

- (void) stopStreaming {
  if (!_streaming) {
    return;
  }
  [_writer finishWithError:nil];
  _streaming = NO;
}

- (BOOL) isStreaming {
  return _streaming;
}

@end
