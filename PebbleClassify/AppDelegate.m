
#import "AppDelegate.h"
#import <PebbleKit/PebbleKit.h>

@interface AppDelegate () <PBPebbleCentralDelegate>
@end

#define BATCH_SIZE 10
#define ACCEL_BUF_SIZE BATCH_SIZE * 10

typedef struct Accel1 {
    int x;
    int y;
    int z;
} Accel;

@implementation AppDelegate {
	PBWatch *_targetWatch;
	
	// view
	UITextField * _accelValuesField;
	UITextView * _resultView;
	
	// samples
	Accel samples[ACCEL_BUF_SIZE];
}

- (void) processAccel:(Accel) sample {
    static int pointer =0;
    
    // save the sample in a buffer
    samples[pointer++] = sample;
    
    // process a batch
	// Note: We currently use only one batch to derive the features,
	// so ACCEL_BUF_SIZE could just be BATCH_SIZE for this code
    if(pointer%BATCH_SIZE == 0) {
        float averageX=0, averageY=0, averageZ=0;
        float difX=0, difY=0, difZ=0;
		float averageDiff;
        
        for(int i=BATCH_SIZE; i>0; i--) {
            averageX += samples[pointer-i].x;
            averageY += samples[pointer-i].y;
            averageZ += samples[pointer-i].z;
        }
        for(int i=BATCH_SIZE-1; i>0; i--) {
            difX += abs(samples[pointer-i].x - samples[pointer-i-1].x);
            difY += abs(samples[pointer-i].y - samples[pointer-i-1].y);
            difZ += abs(samples[pointer-i].z - samples[pointer-i-1].z);
        }
        averageX /= BATCH_SIZE;
        averageY /= BATCH_SIZE;
        averageZ /= BATCH_SIZE;
		averageDiff = (difX + difY + difZ)/3;
		
		int resting = (averageDiff < 150);
		int typing = (-averageZ > (averageX + averageY)/2) && (averageDiff < 400) && (averageDiff > 150);
		int walking = (averageX > (averageY - averageZ)) && (difX > (difY+difZ)/2) && (averageDiff > 400);
		int running = (averageX < (averageY - averageZ)) && (averageDiff > 1000);
		
		if(resting) {
			_resultView.textColor = [UIColor blueColor];
			_resultView.text = @"Resting!";
		} else if(typing) {
			_resultView.textColor = [UIColor greenColor];
			_resultView.text = @"Typing!";
		} else if(walking) {
			_resultView.textColor = [UIColor yellowColor];
			_resultView.text = @"Walking!";
		} else if(running) {
			_resultView.textColor = [UIColor redColor];
			_resultView.text = @"Running!";
		} else {
			_resultView.textColor = [UIColor whiteColor];
			_resultView.text = @"    ...";
		}
		
		NSLog(@"XYZA: %.0f, %.0f, %.0f; AveDiff: %.0f; diffs: %.0f, %.0f, %.0f", averageX, averageY, averageZ, averageDiff, difX, difY, difZ);
    }
    
    if(pointer == ACCEL_BUF_SIZE)
        pointer = 0;  // back to start of circular buffer
}

- (void)setTargetWatch:(PBWatch*)watch {
	_targetWatch = watch;
	
	// Configure our communications channel to target this app:
	uint8_t bytes[] = {0x00, 0x9B, 0x83, 0xE1, 0x01, 0xC2, 0x4B, 0x6F, 0xBB, 0x9A, 0xA0, 0xFB, 0xA2, 0xC2, 0x5C, 0x03};
	NSData *uuid = [NSData dataWithBytes:bytes length:sizeof(bytes)];
	[[PBPebbleCentral defaultCentral] setAppUUID:uuid];
	
	[watch appMessagesLaunch:^(PBWatch *watch, NSError *error) {
		if (!error) {
			NSLog(@"Successfully launched app.");
			[watch appMessagesAddReceiveUpdateHandler:^BOOL(PBWatch *watch, NSDictionary *update) {
				Accel sample;
				sample.x = [[update objectForKey:@'x'] intValue];
				sample.y = [[update objectForKey:@'y'] intValue];
				sample.z = [[update objectForKey:@'z'] intValue];
        		_accelValuesField.text = [NSString stringWithFormat:@"x, y, z\r\n: %d %d %d", sample.x, sample.y, sample.z];
	        	[self processAccel:sample];
				return YES;
       		}];
    	} else {
			NSLog(@"Error launching app - Error: %@", error);
			NSString *message = [NSString stringWithFormat:@"Could not launch app on %@ :'(", [watch name]];
      		[[[UIAlertView alloc] initWithTitle:@"Connected..." message:message delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil] show];
    	}
  	}];
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
	self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
	
	_resultView = [[UITextView alloc] initWithFrame:CGRectMake(10, 120, 350, 100)];
	_resultView.backgroundColor = [UIColor clearColor];
	_resultView.textColor = [UIColor grayColor];
	_resultView.font = [UIFont systemFontOfSize:64.0f];
	_resultView.text = @"Starting!";
	[self.window addSubview:_resultView];
	
	CGRect textField1Frame = CGRectMake(10, 500, 300, 50);
	_accelValuesField = [[UITextField alloc] initWithFrame:textField1Frame];
	_accelValuesField.backgroundColor = [UIColor whiteColor];
	_accelValuesField.textColor = [UIColor blackColor];
	_accelValuesField.font = [UIFont systemFontOfSize:14.0f];
	[self.window addSubview:_accelValuesField];
	
	
	[self.window makeKeyAndVisible];
	
	// We'd like to get called when Pebbles connect and disconnect, so become the delegate of PBPebbleCentral:
	[[PBPebbleCentral defaultCentral] setDelegate:self];
	
	// Initialize with the last connected watch:
	[self setTargetWatch:[[PBPebbleCentral defaultCentral] lastConnectedWatch]];
	return YES;
}

/*
 *  PBPebbleCentral delegate methods
 */

- (void)pebbleCentral:(PBPebbleCentral*)central watchDidConnect:(PBWatch*)watch isNew:(BOOL)isNew {
	[self setTargetWatch:watch];
}

- (void)pebbleCentral:(PBPebbleCentral*)central watchDidDisconnect:(PBWatch*)watch {
	[[[UIAlertView alloc] initWithTitle:@"Disconnected!" message:[watch name] delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil] show];
	if (_targetWatch == watch || [watch isEqual:_targetWatch]) {
    	[self setTargetWatch:nil];
	}
}

@end
