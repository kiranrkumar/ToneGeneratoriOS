//
//  ViewController.h
//  ToneGenerator
//
//  Created by Kumar, Kiran on 10/11/17.
//  Copyright © 2017 Kiran Kumar. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, PlayState) {
    PlayStatePlaying,
    PlayStateStopped
};

//better descriptors for the type of tone in the waveform array
typedef NS_ENUM(NSInteger, ToneType) {
    ToneTypeSine,
    ToneTypeTriangle,
    ToneTypeSawtooth,
    ToneTypeSquare
};

//convenience functions
float mag2db(float);
float db2mag(float);

@interface ViewController : UIViewController

@property NSArray* allToneTypes;
@property NSUInteger curTone;
@property (nonatomic) PlayState curPlayState;
@property (nonatomic) ToneType curToneType;
@property float harmPct;
@property float outGain;
@property NSArray* waveformImages;

- (void) changeImage;

@end

