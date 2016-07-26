//
//  SavedTableViewController.m
//  Speech
//
//  Created by Ankit Gupta on 7/21/16.
//

#import <AVFoundation/AVFoundation.h>
#import <MediaPlayer/MediaPlayer.h>
#import "XMLDictionary.h"

#import "SavedTableViewController.h"
#import "SavedTableViewCell.h"
#import "AudioController.h"
#import "SpeechRecognitionService.h"
#import "google/cloud/speech/v1beta1/CloudSpeech.pbrpc.h"

#import "AppDelegate.h"
#import "SavedEntity.h"

#define SAMPLE_RATE 16000.0f
#define API_KEY @"AIzaSyCfQ4XpgLZmn1_M8SLrAnae59-clyjnmT8"

@interface SavedTableViewController () <AudioControllerDelegate, AVSpeechSynthesizerDelegate, NSFetchedResultsControllerDelegate>
@property (nonatomic, strong) UITextView *textView;
@property (nonatomic, strong) NSMutableData *audioData;

@property (nonatomic) BOOL isRecording;
@property (nonatomic, strong) AVSpeechSynthesizer *synthesizer;
@property (nonatomic) NSInteger myDeactivationAttempts;
@property (nonatomic, strong) AVAudioPlayer *audioPlayer;

@end

@implementation SavedTableViewController
@synthesize fetchedResultsController = _fetchedResultsController;

- (void)viewDidLoad {
    [super viewDidLoad];
    
    NSError *error = nil;
    if (![[self fetchedResultsController] performFetch:&error]) {
        // Update to handle the error appropriately.
        NSLog(@"Error fetching data: %@", error);
    }

    AVAudioSession *audioSession = [AVAudioSession sharedInstance];
    
    BOOL success = [audioSession setCategory:AVAudioSessionCategoryPlayAndRecord
                                 withOptions:AVAudioSessionCategoryOptionDuckOthers
                                       error:&error];
    if (!success) {
        NSLog(@"AVAudioSession error while setting category due to - %@",error);
    }
    
    success = [audioSession setActive:YES error:&error];
    if (!success) {
        NSLog(@"Error activating the AVAudioSession session due to - %@",error);
    }
    
    [AudioController sharedInstance].delegate = self;
    [[UIApplication sharedApplication] beginReceivingRemoteControlEvents];
    if ([self canBecomeFirstResponder]) {
        [self becomeFirstResponder];
    }
    
    self.tableView.rowHeight = 80.0f;
    
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)remoteControlReceivedWithEvent:(UIEvent *)theEvent
{
    if (theEvent.type == UIEventTypeRemoteControl) {
        switch(theEvent.subtype) {
            case UIEventSubtypeRemoteControlTogglePlayPause:
                if ([self.synthesizer isSpeaking]) {
                    [self.synthesizer stopSpeakingAtBoundary:AVSpeechBoundaryImmediate];
                }
                if (self.isRecording) {
                    [self stopAudio:nil];
                }
                else {
                    [self recordAudio:nil];
                }
                break;
            case UIEventSubtypeRemoteControlPlay:
                [self recordAudio:nil];
                break;
            case UIEventSubtypeRemoteControlPause:
                [self stopAudio:nil];
                break;
            case UIEventSubtypeRemoteControlStop:
                [self stopAudio:nil];
                break;
            default:
                return;
        }
    }
}

- (IBAction)recordAudio:(id)sender {
    if (self.isRecording) {
        return;
    }
    
    _audioData = [[NSMutableData alloc] init];
    [[AudioController sharedInstance] prepareWithSampleRate:SAMPLE_RATE];
    [[SpeechRecognitionService sharedInstance] setSampleRate:SAMPLE_RATE];
    [[AudioController sharedInstance] start];
    self.isRecording = TRUE;
    [self playSound:@"digi_plink.aif"];
    [self showAudioTranscriptView];
}

- (IBAction)stopAudio:(id)sender {
    [[AudioController sharedInstance] stop];
    [[SpeechRecognitionService sharedInstance] stopStreaming];
    self.isRecording = FALSE;
    
    [self dismissAudioTranscriptView];
    
}

- (void) processSampleData:(NSData *)data
{
    [self.audioData appendData:data];
    NSInteger frameCount = [data length] / 2;
    int16_t *samples = (int16_t *) [data bytes];
    int64_t sum = 0;
    for (int i = 0; i < frameCount; i++) {
        sum += abs(samples[i]);
    }
    NSLog(@"audio %d %d", (int) frameCount, (int) (sum * 1.0 / frameCount));
    
    // We recommend sending samples in 100ms chunks
    int chunk_size = 0.1 /* seconds/chunk */ * SAMPLE_RATE * 2 /* bytes/sample */ ; /* bytes/chunk */
    
    if ([self.audioData length] > chunk_size) {
        NSLog(@"SENDING");
        [[SpeechRecognitionService sharedInstance] streamAudioData:self.audioData
                                                    withCompletion:^(StreamingRecognizeResponse *response, NSError *error) {
                                                        if (response) {
                                                            BOOL finished = NO;
                                                            NSLog(@"RESPONSE RECEIVED");
                                                            if (error) {
                                                                NSLog(@"ERROR: %@", error);
                                                            } else {
                                                                NSLog(@"RESPONSE: %@", response);
                                                                for (StreamingRecognitionResult *result in response.resultsArray) {
                                                                    if (result.isFinal) {
                                                                        finished = YES;
                                                                        
                                                                        [self stopAudio:nil];
                                                                        [self processFinalResult:result];
                                                                    }
                                                                    _textView.text = result.alternativesArray.firstObject.transcript;
                                                                }
                                                            }
                                                        } else {
                                                            [self stopAudio:nil];
                                                        }
                                                    }];
        self.audioData = [[NSMutableData alloc] init];
    }
}

- (void)processFinalResult:(StreamingRecognitionResult *)finalResult {
    SpeechRecognitionAlternative *firstAlternative = finalResult.alternativesArray.firstObject;
    NSString *transcript = [self standardizeString:firstAlternative.transcript];
    if ([transcript rangeOfString:@"watch"].location == 0) {
        [self playSound:@"music_marimba_chord.aif"];
        // Process movie
        NSString *queryString = [transcript substringFromIndex:5];
        queryString = [queryString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        NSString *urlAsString = [NSString stringWithFormat:@"http://www.omdbapi.com/?s==%@", [[self standardizeString:queryString] stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]]];
        NSURL *url = [[NSURL alloc] initWithString:urlAsString];
        NSLog(@"%@", urlAsString);
        NSURLSession *urlSession = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]];
        [[urlSession dataTaskWithURL:url completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
            NSLog(@"Error: %@", error);
            NSDictionary *dataDictionary = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
            NSArray *results = [dataDictionary valueForKey:@"Search"];
            [self saveMediaToCoreData:results forTranscript:queryString];
        }] resume];

    }
    else if ([transcript rangeOfString:@"read"].location == 0) {
        [self playSound:@"music_marimba_chord.aif"];

        NSString *queryString = [transcript substringFromIndex:4];
        queryString = [queryString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        // Process book
        NSString *urlAsString = [NSString stringWithFormat:@"https://www.goodreads.com/search/index.xml?key=KhgAOBLxNTRNPqB7dTKOnQ&q=%@", [[self standardizeString:queryString] stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]]];
        NSURL *url = [[NSURL alloc] initWithString:urlAsString];
        NSLog(@"%@", urlAsString);
        
        NSURLSession *urlSession = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]];
        
        [[urlSession dataTaskWithURL:url completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
            NSLog(@"Error: %@", error);
            NSDictionary *xmlDict = [NSDictionary dictionaryWithXMLData:data];
            NSArray *books = [[[xmlDict valueForKey:@"search"] valueForKey:@"results"] valueForKey:@"work"];
            [self saveBookToCoreData:books forTranscript:queryString];
        }] resume];
    }
    else if ([transcript rangeOfString:@"visit"].location == 0) {
        [self playSound:@"music_marimba_chord.aif"];
        
        NSString *queryString = [transcript substringFromIndex:5];
        queryString = [queryString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        // Process book
        NSString *urlAsString = [NSString stringWithFormat:@"https://api.yelp.com/v3/businesses/search?term=%@&location=San+Francisco", [[self standardizeString:queryString] stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]]];
        NSURL *url = [[NSURL alloc] initWithString:urlAsString];
        NSLog(@"%@", urlAsString);
        
        NSString *token = @"n1bLzokRKBQC-F4ZuUqQsr7z4q39A-eys7m4jYYMTHTEALkhsEuW1Krckb0VoZVdc0k4sWEh9PJC7n1rnQ3JqOG-qoByCuuxHXQOpg5xM7t2gdmlHi2c1k9opbeSV3Yx";
        
        NSString *authValue = [NSString stringWithFormat:@"Bearer %@",token];
        
        //Configure your session with common header fields like authorization etc
        NSURLSessionConfiguration *sessionConfiguration = [NSURLSessionConfiguration defaultSessionConfiguration];
        sessionConfiguration.HTTPAdditionalHeaders = @{@"Authorization": authValue};

        NSURLSession *urlSession = [NSURLSession sessionWithConfiguration:sessionConfiguration];
        
        [[urlSession dataTaskWithURL:url completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
            NSLog(@"Error: %@", error);
            NSDictionary *dataDictionary = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
            NSArray *results = [dataDictionary valueForKey:@"businesses"];
            [self savePlaceToCoreData:results forTranscript:queryString];
        }] resume];
    }
    else if ([transcript rangeOfString:@"buy"].location == 0) {
        [self playSound:@"music_marimba_chord.aif"];
        
        NSString *queryString = [transcript substringFromIndex:3];
        queryString = [queryString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        NSString *jsonQueryParam = [[NSString stringWithFormat:@"{\"search\": \"%@\"}", queryString] stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
        // Process book
        NSString *urlAsString = [NSString stringWithFormat:@"https://api.semantics3.com/test/v1/products?q=%@",jsonQueryParam];
        NSURL *url = [[NSURL alloc] initWithString:urlAsString];
        NSLog(@"%@", urlAsString);
        
        NSString *token = @"SEM352E049B0E78E29E007DA115B7907ED40";
        
        //Configure your session with common header fields like authorization etc
        NSURLSessionConfiguration *sessionConfiguration = [NSURLSessionConfiguration defaultSessionConfiguration];
        sessionConfiguration.HTTPAdditionalHeaders = @{@"api_key": token};
        
        NSURLSession *urlSession = [NSURLSession sessionWithConfiguration:sessionConfiguration];
        
        [[urlSession dataTaskWithURL:url completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
            NSLog(@"Error: %@", error);
            NSDictionary *dataDictionary = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
            NSArray *results = [dataDictionary valueForKey:@"results"];
            [self saveProductToCoreData:results forTranscript:queryString];
        }] resume];
    }
    else if ([transcript rangeOfString:@"remember"].location == 0) {
        [self playSound:@"music_marimba_chord.aif"];
        
        NSString *queryString = [transcript substringFromIndex:8];
        queryString = [[queryString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] capitalizedString];
        // Process thought
        [self saveThoughtToCoreDataForTranscript:queryString];

    }
    else {
        [self playSound:@"beep_short_off.aif"];
        [self speak:[NSArray arrayWithObjects:@"Sorry. I didn't get that.", nil] withPreUtteranceDelays:[NSArray arrayWithObjects:[NSNumber numberWithDouble:0], nil]];
    }

}

- (void)speak:(NSArray *)utterances withPreUtteranceDelays:(NSArray *)delays {
    NSLog(@"%@", [utterances description]);
    if (!self.synthesizer) {
        self.synthesizer = [[AVSpeechSynthesizer alloc]init];
        self.synthesizer.delegate = self;
    }
    int i = 0;
    for (NSString *text in utterances) {
        AVSpeechUtterance *utterance = [AVSpeechUtterance speechUtteranceWithString:text];
        [utterance setVolume:0.25f];
        [utterance setPreUtteranceDelay:[[delays objectAtIndex:i] doubleValue]];
        [self.synthesizer speakUtterance:utterance];
        i++;
    }
    AVSpeechUtterance *utterance = [AVSpeechUtterance speechUtteranceWithString:@""];
    [self.synthesizer speakUtterance:utterance];
    
}

- (void)playSound:(NSString *)soundFileName {
    // Find the sound file.
    NSString *file = [soundFileName stringByDeletingPathExtension];
    NSString *extension = [soundFileName pathExtension];
    NSURL *soundFileURL = [[NSBundle mainBundle] URLForResource:file withExtension:extension];
    
    NSError *error = nil;
    
    // Create and prepare the sound.
    self.audioPlayer = [[AVAudioPlayer alloc] initWithContentsOfURL:soundFileURL error:&error];
    self.audioPlayer.volume = 0.5f;
    [self.audioPlayer play];
}
- (NSString *) standardizeString:(NSString *)inputString {
    return [[inputString lowercaseString] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

- (NSString *) sanitizeStringForSpeech:(NSString *)inputString {
    inputString = [inputString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    inputString = [inputString stringByReplacingOccurrencesOfString:@"." withString:@""];
    return inputString;
}

- (void)showAudioTranscriptView {
    if (!self.textView) {
        self.textView = [[UITextView alloc] initWithFrame:CGRectMake(0, self.navigationController.view.frame.size.height, self.navigationController.view.frame.size.width, 40.0f)];
        [self.navigationController.view addSubview:self.textView];
        self.textView.backgroundColor = [UIColor blackColor];
        self.textView.textColor = [UIColor colorWithWhite:0.9 alpha:1.0];
        self.textView.textAlignment = NSTextAlignmentCenter;
    }
    _textView.text = nil;
    [UIView animateWithDuration:0.3 delay:0.0 options:UIViewAnimationOptionCurveEaseOut animations:^{
        CGRect rect = self.textView.frame;
        rect.origin = CGPointMake(rect.origin.x, self.navigationController.view.frame.size.height-40.0f);
        self.textView.frame = rect;
    } completion:nil];
}

- (void)dismissAudioTranscriptView {
    [UIView animateWithDuration:0.3 delay:4.0 options:UIViewAnimationOptionCurveEaseOut animations:^{
        CGRect rect = self.textView.frame;
        rect.origin = CGPointMake(rect.origin.x, self.navigationController.view.frame.size.height);
        self.textView.frame = rect;
    } completion:^(BOOL finished) {
        _textView.text = nil;
    }];
}

#pragma mark -
#pragma mark AVSpeechSynthesizerDelegate Handlers
- (void)speechSynthesizer:(AVSpeechSynthesizer *)synthesizer didStartSpeechUtterance:(AVSpeechUtterance *)utterance
{
    NSLog(@"AVSpeechSynthesizerFacade::didStartSpeechUtterance enter");
    
    // Nothing to do
}


- (void)speechSynthesizer:(AVSpeechSynthesizer *)synthesizer didCancelSpeechUtterance:(AVSpeechUtterance *)utterance
{
    NSLog(@"AVSpeechSynthesizerFacade::didCancelSpeechUtterance enter");
}

- (void)speechSynthesizer:(AVSpeechSynthesizer *)synthesizer
 didFinishSpeechUtterance:(AVSpeechUtterance *)utterance {
    if ([utterance.speechString isEqualToString:@""]) {
        // End of speech
    }
}

#pragma mark -
- (void)saveBookToCoreData:(NSArray *)results forTranscript:(NSString *)transcript{
    AppDelegate *appDelegate=(AppDelegate*)[UIApplication sharedApplication].delegate;
    NSManagedObjectContext *context=[appDelegate managedObjectContext];
    NSEntityDescription *entityForBook = [NSEntityDescription entityForName:@"SavedEntity" inManagedObjectContext:context];
    SavedEntity *book = [[SavedEntity alloc] initWithEntity:entityForBook insertIntoManagedObjectContext:context];
    
    NSDictionary *topResult = results.firstObject;
    NSDictionary *topBook =  [topResult valueForKey:@"best_book"];
    
    
    book.dateAdded = [NSDate date];
    book.title = [[topBook valueForKey:@"title"] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    book.author = [[[topBook valueForKey:@"author"] valueForKey:@"name"] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    book.url = [NSString stringWithFormat:@"https://www.goodreads.com/book/show/%@", [topResult valueForKey:@"id"]];
    book.transcript = transcript;
    NSMutableArray *alternatives = [results mutableCopy];
    [alternatives removeObjectAtIndex:0];
    NSData *alternativesData = [NSKeyedArchiver archivedDataWithRootObject:alternatives];
    book.alternatives = alternativesData;
    book.type = @"Book";
    NSError *error;
    [context save:&error];
    NSLog(@"Saved. Error: %@", error);
}

- (void)saveMediaToCoreData:(NSArray *)results forTranscript:(NSString *)transcript{
    AppDelegate *appDelegate=(AppDelegate*)[UIApplication sharedApplication].delegate;
    NSManagedObjectContext *context=[appDelegate managedObjectContext];
    NSEntityDescription *entityForBook = [NSEntityDescription entityForName:@"SavedEntity" inManagedObjectContext:context];
    SavedEntity *media = [[SavedEntity alloc] initWithEntity:entityForBook insertIntoManagedObjectContext:context];
    
    NSDictionary *topResult = results.firstObject;
    
    media.dateAdded = [NSDate date];
    NSString *title = [[topResult valueForKey:@"Title"] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSString *year = [[topResult valueForKey:@"Year"] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    
    media.title = [NSString stringWithFormat:@"%@ (%@)", title, year];
    media.mediaType = [[[topResult valueForKey:@"Type"] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] capitalizedString];
    media.url = [NSString stringWithFormat:@"http://www.imdb.com/title/%@", [topResult valueForKey:@"imdbID"]];
    media.transcript = transcript;
    NSMutableArray *alternatives = [results mutableCopy];
    [alternatives removeObjectAtIndex:0];
    NSData *alternativesData = [NSKeyedArchiver archivedDataWithRootObject:alternatives];
    media.alternatives = alternativesData;
    media.type = @"Media";
    NSError *error;
    [context save:&error];
    NSLog(@"Saved. Error: %@", error);
}

- (void)savePlaceToCoreData:(NSArray *)results forTranscript:(NSString *)transcript{
    AppDelegate *appDelegate=(AppDelegate*)[UIApplication sharedApplication].delegate;
    NSManagedObjectContext *context=[appDelegate managedObjectContext];
    NSEntityDescription *entityForBook = [NSEntityDescription entityForName:@"SavedEntity" inManagedObjectContext:context];
    SavedEntity *place = [[SavedEntity alloc] initWithEntity:entityForBook insertIntoManagedObjectContext:context];
    
    NSDictionary *topResult = results.firstObject;
    
    place.dateAdded = [NSDate date];
    NSString *name = [[topResult valueForKey:@"name"] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSString *image_url = [[topResult valueForKey:@"image_url"] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSString *metadata = [NSString stringWithFormat:@"%@ stars. %@ reviews. %@",[[topResult valueForKey:@"rating"] stringValue], [[topResult valueForKey:@"review_count"] stringValue], [[topResult valueForKey:@"price"] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]];
    
    place.title = name;
    place.placeMetadata = metadata;
    place.url = [[topResult valueForKey:@"url"] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    place.imageUrl = image_url;
    place.transcript = transcript;
    NSMutableArray *alternatives = [results mutableCopy];
    [alternatives removeObjectAtIndex:0];
    NSData *alternativesData = [NSKeyedArchiver archivedDataWithRootObject:alternatives];
    place.alternatives = alternativesData;
    place.type = @"Place";
    NSError *error;
    [context save:&error];
    NSLog(@"Saved. Error: %@", error);
}

- (void)saveProductToCoreData:(NSArray *)results forTranscript:(NSString *)transcript{
    AppDelegate *appDelegate=(AppDelegate*)[UIApplication sharedApplication].delegate;
    NSManagedObjectContext *context=[appDelegate managedObjectContext];
    NSEntityDescription *entityForBook = [NSEntityDescription entityForName:@"SavedEntity" inManagedObjectContext:context];
    SavedEntity *product = [[SavedEntity alloc] initWithEntity:entityForBook insertIntoManagedObjectContext:context];
    
    NSDictionary *topResult = results.firstObject;
    
    product.dateAdded = [NSDate date];
    NSString *name = [[topResult valueForKey:@"name"] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSString *metadata = [NSString stringWithFormat:@"%d other results",(int)(results.count - 1)];
    
    product.title = name;
    product.productMetadata = metadata;
    product.transcript = transcript;
    NSMutableArray *alternatives = [results mutableCopy];
    [alternatives removeObjectAtIndex:0];
    NSData *alternativesData = [NSKeyedArchiver archivedDataWithRootObject:alternatives];
    product.alternatives = alternativesData;
    product.type = @"Commodity";
    NSError *error;
    [context save:&error];
    NSLog(@"Saved. Error: %@", error);
}

- (void)saveThoughtToCoreDataForTranscript:(NSString *)transcript {
    AppDelegate *appDelegate=(AppDelegate*)[UIApplication sharedApplication].delegate;
    NSManagedObjectContext *context=[appDelegate managedObjectContext];
    NSEntityDescription *entityForBook = [NSEntityDescription entityForName:@"SavedEntity" inManagedObjectContext:context];
    SavedEntity *savedEntity = [[SavedEntity alloc] initWithEntity:entityForBook insertIntoManagedObjectContext:context];
    
    savedEntity.dateAdded = [NSDate date];
    savedEntity.title = transcript;
    savedEntity.transcript = transcript;
    savedEntity.type = @"General";
    NSError *error;
    [context save:&error];
    NSLog(@"Saved. Error: %@", error);
    
}
- (NSFetchedResultsController *)fetchedResultsController {
    
    if (_fetchedResultsController != nil) {
        return _fetchedResultsController;
    }
    AppDelegate *appDelegate=(AppDelegate*)[UIApplication sharedApplication].delegate;
    NSManagedObjectContext *managedObjectContext=[appDelegate managedObjectContext];

    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    NSEntityDescription *entity = [NSEntityDescription
                                   entityForName:@"SavedEntity" inManagedObjectContext:managedObjectContext];
    [fetchRequest setEntity:entity];
    
    NSSortDescriptor *sort = [[NSSortDescriptor alloc]
                              initWithKey:@"dateAdded" ascending:NO];
    [fetchRequest setSortDescriptors:[NSArray arrayWithObject:sort]];
    
    [fetchRequest setFetchBatchSize:20];
    
    NSFetchedResultsController *theFetchedResultsController =
    [[NSFetchedResultsController alloc] initWithFetchRequest:fetchRequest
                                        managedObjectContext:managedObjectContext sectionNameKeyPath:nil
                                                   cacheName:@"Root"];
    self.fetchedResultsController = theFetchedResultsController;
    _fetchedResultsController.delegate = self;
    
    return _fetchedResultsController;
    
}

#pragma mark - NSFetchedResultsController Delegate

- (void)controllerWillChangeContent:(NSFetchedResultsController *)controller {
    // The fetch controller is about to start sending change notifications, so prepare the table view for updates.
    [self.tableView beginUpdates];
}


- (void)controller:(NSFetchedResultsController *)controller didChangeObject:(id)anObject atIndexPath:(NSIndexPath *)indexPath forChangeType:(NSFetchedResultsChangeType)type newIndexPath:(NSIndexPath *)newIndexPath {
    
    UITableView *tableView = self.tableView;
    
    switch(type) {
            
        case NSFetchedResultsChangeInsert:
            [tableView insertRowsAtIndexPaths:[NSArray arrayWithObject:newIndexPath] withRowAnimation:UITableViewRowAnimationFade];
            break;
            
        case NSFetchedResultsChangeDelete:
            [tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationFade];
            break;
            
        case NSFetchedResultsChangeUpdate:
            [self configureCell:[tableView cellForRowAtIndexPath:indexPath] atIndexPath:indexPath];
            break;
            
        case NSFetchedResultsChangeMove:
            [tableView deleteRowsAtIndexPaths:[NSArray
                                               arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationFade];
            [tableView insertRowsAtIndexPaths:[NSArray
                                               arrayWithObject:newIndexPath] withRowAnimation:UITableViewRowAnimationFade];
            break;
    }
}


- (void)controller:(NSFetchedResultsController *)controller didChangeSection:(id )sectionInfo atIndex:(NSUInteger)sectionIndex forChangeType:(NSFetchedResultsChangeType)type {
    
    switch(type) {
            
        case NSFetchedResultsChangeInsert:
            [self.tableView insertSections:[NSIndexSet indexSetWithIndex:sectionIndex] withRowAnimation:UITableViewRowAnimationFade];
            break;
            
        case NSFetchedResultsChangeDelete:
            [self.tableView deleteSections:[NSIndexSet indexSetWithIndex:sectionIndex] withRowAnimation:UITableViewRowAnimationFade];
            break;
    }
}


- (void)controllerDidChangeContent:(NSFetchedResultsController *)controller {
    // The fetch controller has sent all current change notifications, so tell the table view to process all updates.
    [self.tableView endUpdates];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return [[_fetchedResultsController sections] count];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    id  sectionInfo = [[_fetchedResultsController sections] objectAtIndex:section];
    return [sectionInfo numberOfObjects];
}

- (void)configureCell:(UITableViewCell *)cell atIndexPath:(NSIndexPath *)indexPath {
    SavedEntity *savedEntity = [_fetchedResultsController objectAtIndexPath:indexPath];
    SavedTableViewCell *savedCell = (SavedTableViewCell *)cell;
    if ([savedEntity.type isEqualToString:@"Media"]) {
        savedCell.nameLabel.text = savedEntity.title;
        savedCell.authorLabel.text = savedEntity.mediaType;
        savedCell.transcriptLabel.text = [NSString stringWithFormat:@"\"%@\"", [savedEntity.transcript stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]];
    }
    else if([savedEntity.type isEqualToString:@"Book"]) {
        savedCell.nameLabel.text = savedEntity.title;
        savedCell.authorLabel.text = [NSString stringWithFormat:@"Book by %@", savedEntity.author];
        savedCell.transcriptLabel.text = [NSString stringWithFormat:@"\"%@\"", [savedEntity.transcript stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]];
    }
    else if([savedEntity.type isEqualToString:@"Place"]) {
        savedCell.nameLabel.text = savedEntity.title;
        savedCell.authorLabel.text = savedEntity.placeMetadata;
        savedCell.transcriptLabel.text = [NSString stringWithFormat:@"\"%@\"", [savedEntity.transcript stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]];
    }
    else if([savedEntity.type isEqualToString:@"Commodity"]) {
        savedCell.nameLabel.text = savedEntity.title;
        savedCell.authorLabel.text = savedEntity.productMetadata;
        savedCell.transcriptLabel.text = [NSString stringWithFormat:@"\"%@\"", [savedEntity.transcript stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]];
    }
    else {
        savedCell.nameLabel.text = savedEntity.transcript;
        savedCell.authorLabel.text = nil;
        savedCell.transcriptLabel.text = nil;
    }
}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"BookCell" forIndexPath:indexPath];
    [self configureCell:cell atIndexPath:indexPath];
    return cell;
}



// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    // Return NO if you do not want the specified item to be editable.
    return YES;
}



// Override to support editing the table view.
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        // Delete the row from the data source
        NSManagedObject *managedObject = [self.fetchedResultsController objectAtIndexPath:indexPath];
        AppDelegate *appDelegate=(AppDelegate*)[UIApplication sharedApplication].delegate;
        NSManagedObjectContext *managedObjectContext=[appDelegate managedObjectContext];
        [managedObjectContext deleteObject:managedObject];
        [managedObjectContext save:nil];
    } else if (editingStyle == UITableViewCellEditingStyleInsert) {
        // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
        NSLog(@"Unhandled editing style! %ld", (long)editingStyle);
    }
}


/*
// Override to support rearranging the table view.
- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath {
}
*/

/*
// Override to support conditional rearranging of the table view.
- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath {
    // Return NO if you do not want the item to be re-orderable.
    return YES;
}
*/

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
