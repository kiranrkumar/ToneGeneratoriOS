//
//  ViewController.m
//  ToneGenerator
//
//  Created by Kumar, Kiran on 10/11/17.
//  Copyright © 2017 Kiran Kumar. All rights reserved.
//

#import "ViewController.h"

@import AudioToolbox;
@import AVFoundation;

#define kOutputBus 0
#define kInputBus 1

@interface ViewController ()

@property (weak, nonatomic) IBOutlet UILabel *toneType;
@property (weak, nonatomic) IBOutlet UISlider *freqSliderVal;
@property (weak, nonatomic) IBOutlet UITextField *freqTxtFld;
@property (weak, nonatomic) IBOutlet UISlider *harmSliderVal;
@property (weak, nonatomic) IBOutlet UITextField *harmTxtFld;
@property (weak, nonatomic) IBOutlet UISlider *outSliderVal;
@property (weak, nonatomic) IBOutlet UITextField *outTxtFld;
@property (weak, nonatomic) IBOutlet UIButton *playPauseBtn;
@property (weak, nonatomic) IBOutlet UIImageView *waveformImg;



@end

@implementation ViewController

static AudioComponentInstance audioUnit;
static const float sampleRate = 44100.0f;


float freqVal = 440.0f;
float harmVal = 33.0f;
static float amp = 0.6;
NSMutableString* curWaveType;

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    _allToneTypes = [[NSArray alloc] initWithObjects:@"Sine", @"Triangle", @"Sawtooth", @"Square", nil];
    _curTone = 0; //ToneTypeSine
    
    //init relevant values for the callback function (might be redundant)
    freqVal = [_freqSliderVal value];
    harmVal = [_harmSliderVal value];
    amp = [_outSliderVal value];
    
    //init values by calling the slider value changed methods
    [self freqSliderChanged:self];
    [self harmSliderChanged:self];
    [self outSliderChanged:self];
    [self setCurPlayState:PlayStateStopped];
    
    //set up array of waveform images
    [self setWaveformImages: [[NSArray alloc] initWithObjects:
                              [UIImage imageNamed:@"sine.png"],
                              [UIImage imageNamed:@"triangle.png"],
                              [UIImage imageNamed:@"saw.png"],
                              [UIImage imageNamed:@"square.png"],
                              nil]];
    
    //Set the UIImage view to show the scaled waveform image
    [[self waveformImg] setContentMode:UIViewContentModeScaleAspectFit];
    [[self waveformImg] setImage:[[self waveformImages] objectAtIndex:[self curTone]]];
    
    //set up the audio session and audiounit
    [self setupAudio];
    
    //"press" the play button to start playback
    [self playPauseBtnPressed:self];
    
}

//implement built-in method for when any part of the screen has been touched
- (void) touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [self.view endEditing:YES]; //forces all entry fields to resign first responder
}

//View controller has been set up to be a delegate for all textFields. The view controller has thus been implemented to make any textfield resign first responder upon hitting return
- (BOOL) textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    return YES;
}

//audio callback values
static double theta = 0;
static double cmplxToneCurVal = 0;
static double triCurVal = 0;
static double sawCurVal = 0;
static double sqCurVal = 0;
static float triangleUp = 1; //whether the triangle wave is moving up or down
double samplingInterval = 0;

// Audio callback function! Name isn't fixed (it gets set into a struct), but parameters and return type are!
static OSStatus playbackCallback(void *inRefCon,                        //user data
                                 AudioUnitRenderActionFlags *ioFlags,   //flags about rendered audio data
                                 const AudioTimeStamp *inTimeStamp,     //time stamp
                                 UInt32 inBusNumber,                    //bus number
                                 UInt32 inNumberFrames,                 //number of frames for the callback
                                 AudioBufferList *ioData                //the buffers themselves
) {
    //get a reference to the view controller
    ViewController *viewCon = (__bridge ViewController*)inRefCon;

    
    double harmonics; //stores the difference between the complex wave sample value and the sine value
    
    
    //loop through all the audio buffers first
    for (int i = 0; i < ioData->mNumberBuffers; ++i) {
        AudioBuffer buffer = ioData->mBuffers[i];
        //get the audio data from this buffer
        UInt32 *frameBuffer = buffer.mData; //using UInt32 since we're dealing with stereo data with SInt16 in each channel (handy little shortcut)
        
        //loop through each frame of this buffer. We'll store data here to go back into the buffer
        for (UInt32 frame = 0; frame < inNumberFrames; ++frame) {
            
            //keep updating the sampling interval in case frequency changes
            samplingInterval = freqVal / sampleRate;
            
            //get the sin of the current theta
            double sinInRadians = sin(theta);
            
            //determine which waveform value to use
            switch ([viewCon curTone]) {
                case ToneTypeTriangle:
                    cmplxToneCurVal = triCurVal;
                    break;
                case ToneTypeSawtooth:
                    cmplxToneCurVal = sawCurVal;
                    break;
                case ToneTypeSquare:
                    cmplxToneCurVal = sqCurVal;
                    break;
                default:
                    cmplxToneCurVal = sinInRadians;
                    break;
            }
            
            //add the appropriate percentage of the harmonics to the sine value
            harmonics = cmplxToneCurVal - sinInRadians;
            double sampleVal = sinInRadians + harmonics * harmVal/100.0f;
            
            //convert our sample value to the data type we need
            // QUESTION: Why are we dividing by 2pi??
            SInt16 val = sampleVal / (2 * M_PI) * SHRT_MAX * amp * .95; //little bit of attenuation just in case ;)
            
            //duplicate this to make it stereo
            SInt16 newFrameInMemory[2] = {val, val};
            
            //Use some "C Magic" to convert this to an UInt32 value
            UInt32 newFrame32 = *((UInt32*)&newFrameInMemory);
            //^as I understand this, this should work because the address of the array is the first of the two elements. I imagine C casts however many consecutive blocks of memory constitute a UInt32. Does signed vs. unsigned not matter? Does C simply look at the number of bits in the memory block and use them however it needs to for the data type? I feel like that'd make sense since it's similar to using chars and ints interchangably
            
            
            //set the stereo frame into the buffer
            frameBuffer[frame] = newFrame32;
            
            //update relevant values
            double increment = 2 * M_PI * samplingInterval;
            theta += increment;
            if (theta > 2.0 * M_PI) {
                theta -= (2.0 * M_PI);
            }
            
            //Prepare the other wave type samples for the next iteration
            
            //triangle value
            triCurVal += (4 * triangleUp * samplingInterval);
            if (fabs(triCurVal) > 1) {
                triCurVal = triangleUp * (2 - fabs(triCurVal));
                triangleUp *= -1;
            }
            
            //sawtooth value
            sawCurVal += 2 * samplingInterval;
            if (sawCurVal > 1) {
                sawCurVal = sawCurVal - 2;
            }
            
            //square
            sqCurVal = (theta <= M_PI) ? 1 : -1;
        }
    }
    return noErr;
}

//AU setup function. Similar to what I did with initPA for PortAudio
- (void)setupAudio {
    //describe the audio component we want
    AudioComponentDescription desc;
    desc.componentType = kAudioUnitType_Output;
    desc.componentSubType = kAudioUnitSubType_RemoteIO;
    desc.componentManufacturer = kAudioUnitManufacturer_Apple;
    desc.componentFlags = 0;
    desc.componentFlagsMask = 0;
    
    //Find a component with this audio description
    // QUESTION: What does it mean to "search for the next component?" Are there are bunch of components out there in a collection that the program will just look through?
    AudioComponent comp = AudioComponentFindNext(NULL, &desc);
    
    //Create a new instance of an audio component with the above description,
    //storing in the static variable created above
    OSStatus status = AudioComponentInstanceNew(comp, &audioUnit);
    if (status != noErr) {
        NSAssert(status == noErr, @"Error creating the audio component");
    }
    
    //describe the audio itself
    AudioStreamBasicDescription audioFormat;
    
    audioFormat.mSampleRate = sampleRate;
    audioFormat.mFormatID = kAudioFormatLinearPCM;
    audioFormat.mFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked;
    audioFormat.mFramesPerPacket = 1;
    audioFormat.mChannelsPerFrame = 2;
    audioFormat.mBitsPerChannel = 16;
    audioFormat.mBytesPerFrame = sizeof(SInt16) * audioFormat.mChannelsPerFrame;
    audioFormat.mBytesPerPacket = audioFormat.mFramesPerPacket * audioFormat.mBytesPerFrame;
    
    //Set the audio unit's stream format property by passing it our audioFormat struct
    status = AudioUnitSetProperty(audioUnit,
                                  kAudioUnitProperty_StreamFormat,
                                  kAudioUnitScope_Input, //we're funneling audio into this unit to later output
                                  kOutputBus, //this audio is going to the output bus
                                  &audioFormat,
                                  sizeof(audioFormat));
    
    if (status != noErr) {
        NSAssert(status == noErr, @"Error assigning the audio format to the audio unit.");
    }
    
    //create the structure to store the callback
    AURenderCallbackStruct callbackStruct;
    callbackStruct.inputProc = playbackCallback;
    callbackStruct.inputProcRefCon = (__bridge void*)self; //give, as a parameter to the callback, a reference to the view controller.
    //QUESTION: What is toll-free bridging, and how is it different from a simple cast?
    
    //set another property of the audio unit - this time the callback
    status = AudioUnitSetProperty(audioUnit,
                                  kAudioUnitProperty_SetRenderCallback,
                                  kAudioUnitScope_Input,
                                  kOutputBus,
                                  &callbackStruct,
                                  sizeof(callbackStruct));
    
    if (status != noErr) {
        NSAssert(status == noErr, @"Error assigning the callback struct to the audio unit");
    }
    
    //Initialize the audio unit
    status = AudioUnitInitialize(audioUnit);
    
    if (status != noErr) {
        NSAssert(status == noErr, @"Error initializing the audio unit");
    }
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void) changeImage {
    [[self waveformImg] setImage:[[self waveformImages] objectAtIndex:[self curTone]]];
}

- (IBAction)nextBtnPressed:(id)sender {
    if (_curTone == -1) {
        _curTone = 0;
    }
    else {
        _curTone = (_curTone + 1) % [_allToneTypes count];
    }
    [_toneType setText:_allToneTypes[_curTone]];
    
    switch (_curTone) {
        case ToneTypeSine:
            curWaveType = [[NSMutableString alloc] initWithString:@"Sine"];
            break;
        case ToneTypeTriangle:
            curWaveType = [[NSMutableString alloc] initWithString:@"Triangle"];
            break;
        case ToneTypeSquare:
            curWaveType = [[NSMutableString alloc] initWithString:@"Square"];
            break;
        case ToneTypeSawtooth:
            curWaveType = [[NSMutableString alloc] initWithString:@"Sawtooth"];
            break;
        default:
            NSLog(@"Not a valid Wave Type!");
            break;
    }
    
    [self changeImage];
    
    [self.view endEditing:YES]; //forces all entry fields to resign first responder
    
}
- (IBAction)prevBtnPressed:(id)sender {
    if (_curTone == -1) {
        _curTone = 0;
    }
    else {
        _curTone = (_curTone - 1);
        if (_curTone > [_allToneTypes count])
            _curTone = [_allToneTypes count] - 1;
        
    }
    [_toneType setText:_allToneTypes[_curTone]];
    
    switch (_curTone) {
        case ToneTypeSine:
            curWaveType = [[NSMutableString alloc] initWithString:@"Sine"];
            break;
        case ToneTypeTriangle:
            curWaveType = [[NSMutableString alloc] initWithString:@"Triangle"];
            break;
        case ToneTypeSquare:
            curWaveType = [[NSMutableString alloc] initWithString:@"Square"];
            break;
        case ToneTypeSawtooth:
            curWaveType = [[NSMutableString alloc] initWithString:@"Sawtooth"];
            break;
        default:
            NSLog(@"Not a valid Wave Type!");
            break;
    }
    
    [self changeImage];
    
    [self.view endEditing:YES]; //forces all entry fields to resign first responder
}

- (IBAction)freqSliderChanged:(id)sender {
    freqVal = [[self freqSliderVal] value];
    self.freqTxtFld.text = [[NSString alloc] initWithFormat:@"%.0f", freqVal];
}
- (IBAction)freqTxtUpdated:(id)sender {
    //clamp the frequency text field to the slider maximum if necessary
    freqVal = MIN([[[self freqTxtFld] text] floatValue],
                  [[self freqSliderVal] maximumValue]);
    freqVal = MAX(freqVal, [[self freqSliderVal] minimumValue]);
    //reset the text field to whatever the appropriate frequency is
    [[self freqTxtFld] setText:
      [[NSString alloc] initWithFormat:@"%.0f", freqVal]];
    
    [[self freqSliderVal] setValue:freqVal];
    [[self freqTxtFld] resignFirstResponder]; //make the keyboard disappear
}

- (IBAction)harmSliderChanged:(id)sender {
    harmVal = [[self harmSliderVal] value];
    [[self harmTxtFld] setText:[[NSString alloc] initWithFormat:@"%d", (int)harmVal]];
    
}

- (IBAction)harmTxtUpdated:(id)sender {
    harmVal = MIN([[self harmSliderVal] maximumValue],
                  [[[self harmTxtFld] text] floatValue]);
    harmVal = MAX([[self harmSliderVal] minimumValue],
                  harmVal);
    [[self harmTxtFld] setText:[[NSString alloc] initWithFormat:@"%d", (int)harmVal]];
    [[self harmSliderVal] setValue:harmVal];
    [[self harmTxtFld] resignFirstResponder];
}

- (IBAction)outSliderChanged:(id)sender {
    amp = self.outSliderVal.value;
    self.outTxtFld.text = [[NSString alloc] initWithFormat:@"%.1f", mag2db(amp)];
}

- (IBAction)outTxtUpdated:(id)sender {
    float curMagVal = db2mag([[[self outTxtFld] text] floatValue]);
    curMagVal = fminf([[self outSliderVal] maximumValue], curMagVal);
    curMagVal = fmaxf([[self outSliderVal] minimumValue], curMagVal);
    [[self outSliderVal] setValue:curMagVal];
    [[self outTxtFld] setText:[[NSString alloc] initWithFormat:@"%0.2f", mag2db(curMagVal)]];
    amp = curMagVal;
    
}

- (IBAction)playPauseBtnPressed:(id)sender {
    if ([self curPlayState] == PlayStatePlaying) {
        [self setCurPlayState:PlayStateStopped];
        [self.playPauseBtn setTitle:@"Play" forState:UIControlStateNormal];
        
        OSStatus status = AudioOutputUnitStop(audioUnit);
        if (status != noErr) {
            NSAssert(status == noErr, @"Error stopping the audio unit");
        }
        
        NSError *error;
        [[AVAudioSession sharedInstance] setActive:NO error:&error];
        
    } else {
        [self setCurPlayState:PlayStatePlaying];
        [self.playPauseBtn setTitle:@"Stop" forState:UIControlStateNormal];
        
        //set up the audio session
        NSError *error;
        [[AVAudioSession sharedInstance] setActive:YES error:&error];
        if (error != nil) {
            NSAssert(error == nil, @"Error activating the audio session");
        }
        [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:&error];
        if (error != nil) {
            NSAssert(error == nil, @"Error setting audio session category to playback");
        }
        
        //start the audio unit
        OSStatus status = AudioOutputUnitStart(audioUnit);
        if (status != noErr) {
            NSAssert(status == noErr, @"Error starting the audio unit");
        }
    }
}
@end

float mag2db(float myVal) {
    return 20.0f * (float)log10(myVal + FLT_EPSILON);
}

float db2mag(float myVal) {
    return powf(10.0f, myVal / 20.0f);
}
