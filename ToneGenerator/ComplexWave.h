//
//  ComplexWave.h
//  ToneGenerator
//
//  Created by Kumar, Kiran on 10/13/17.
//  Copyright © 2017 Kiran Kumar. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface ComplexWave : NSObject

@property NSString* type;

-(float) genNextSampleWithFreq:(float)curFreq fs:(float)curFs sample:(float)curSample;

@end
