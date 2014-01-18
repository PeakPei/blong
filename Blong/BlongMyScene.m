//
//  BlongMyScene.m
//  Blong
//
//  Created by Will Carlough on 7/7/13.
//  Copyright (c) 2013 Will Carlough. All rights reserved.
//

#import "BlongMyScene.h"
#import "BlongGameCenterHelper.h"


@implementation BlongMyScene

const uint32_t ballCat = 0x1 << 1;
const uint32_t paddleCat = 0x1 << 2;
const uint32_t wallCat = 0x1 << 3;
const uint32_t brickCat = 0x1 << 4;

float maxVelocity = 300;
float maxYVelocity;

int countdown = 30;

// for starting
bool started;
bool touchedLeft;
bool touchedRight;

// sounds for preloading
SKAction *makeNoise;
SKAction *bip;
SKAction *bop;
SKAction *explosion;
SKAction *gameOver;
SKAction *sound11;
SKAction *sound29;

// leveling
// bigger
int minRows = 5;
int maxRows = 10;
int incRows = 3;

int minCols = 3;
int maxCols = 3;
int incCols = 0;

int minBalls = 2;
int maxBalls = 4;
int incBalls = 10;

// smaller
int minCockBlock = 10;
int maxCockBlock = 5;
int incCockBlock = 4;

int minScale = 1;
int maxScale = .1;
int incScale = 2;

int minTimer = 30;
int maxTimer = 10;
int incTimer = 1;


-(id)initWithSize:(CGSize)size {
    if (self = [super initWithSize:size]) {
        maxYVelocity = maxVelocity*.7;
        
        // score
        _score = 0;
        _scoreLabel = [SKLabelNode labelNodeWithFontNamed:@"AvenirNext-Heavy"];
        [self updateScore:0];
        _scoreLabel.fontColor = [SKColor whiteColor];
        _scoreLabel.position = CGPointMake(_scoreLabel.frame.size.width/2, 0);
        [self addChild:_scoreLabel];

        _availableBlockSlots = [NSMutableArray array];

        self.backgroundColor = [SKColor blackColor];
        
        // paddles
        _leftPaddle = [BlongPaddle paddle:@"left_paddle"];
        _leftPaddle.position = CGPointMake(3.5 * _leftPaddle.frame.size.width, CGRectGetMidY(self.frame));
        [self addChild:_leftPaddle];
        _rightPaddle = [BlongPaddle paddle:@"right_paddle"];
        _rightPaddle.position = CGPointMake(self.frame.size.width - 3.5*_rightPaddle.frame.size.width, CGRectGetMidY(self.frame));
        [self addChild:_rightPaddle];
        
        // bricks and balls holders
        _bricks = [NSMutableArray array];
        _balls = [NSMutableArray array];
        _level = 1;
        
        // physics and walls
        SKNode *topWall = [SKNode node];
        topWall.physicsBody = [SKPhysicsBody bodyWithEdgeFromPoint:CGPointMake(0,0) toPoint:CGPointMake(self.frame.size.width,0)];
        topWall.physicsBody.restitution = 1;
        topWall.physicsBody.categoryBitMask = wallCat;
        topWall.physicsBody.friction = 0;
        topWall.position = CGPointMake(0, self.frame.size.height);
        [self addChild:topWall];

        SKNode *bottomWall = [SKNode node];
        bottomWall.physicsBody = [SKPhysicsBody bodyWithEdgeFromPoint:CGPointMake(0,0) toPoint:CGPointMake(self.frame.size.width,0)];
        bottomWall.physicsBody.restitution = 1;
        bottomWall.physicsBody.categoryBitMask = wallCat;
        bottomWall.physicsBody.friction = NO;
        bottomWall.position = CGPointMake(0,0);
        [self addChild:bottomWall];
                          
        self.physicsWorld.gravity = CGVectorMake(0, 0);
        self.physicsWorld.contactDelegate = self;
        self.physicsWorld.speed = 1;
        
        // pause button
        [BlongPauseButton pauseButtonWithScene:self];
        
        // SKActions
        CGPoint textStart = CGPointMake(CGRectGetMidX(self.frame), self.frame.size.height);
        CGPoint textEnd = CGPointMake(CGRectGetMidX(self.frame), CGRectGetMidY(self.frame));
        _topToMiddle = [BlongEasing easeOutElasticFrom:textStart to:textEnd for:.5];
        _wait = [SKAction waitForDuration:.3];
        _shrinkAway = [SKAction scaleTo:0 duration:.3];
        _fadeOut = [SKAction fadeOutWithDuration:2];
        
        // sounds
        bip = [SKAction playSoundFileNamed:@"bip.wav" waitForCompletion:NO];
        bop = [SKAction playSoundFileNamed:@"bop.wav" waitForCompletion:NO];
        makeNoise = [SKAction playSoundFileNamed:@"level_start.wav" waitForCompletion:NO];
        explosion = [SKAction playSoundFileNamed:@"game_over2.wav" waitForCompletion:NO];
        gameOver = [SKAction playSoundFileNamed:@"game_over.wav" waitForCompletion:NO];
        sound11 = [SKAction playSoundFileNamed:@"11.wav" waitForCompletion:NO];
        sound29 = [SKAction playSoundFileNamed:@"29.wav" waitForCompletion:NO];

        touchedLeft = NO;
        touchedRight = NO;
        started = NO;
        self.paused = NO;
        
        [self firstLevel];
        
    }
    return self;
}

-(void)firstLevel {
    _brokenThrough = NO;
    _rows = 6;
    _cols = 3;
    for (int i = 0; i < _rows*_cols; i++) {
        [_availableBlockSlots addObject:[NSString stringWithFormat:@"%d", i]];
    }
    for (int i = 0; i<_rows; i++) {
        for (int j = 0; j<_cols; j++) {
            [BlongBrick brickWithScene:self fromRandom:YES];
        }
    }
}

-(void)startLevel {
    _brokenThrough = NO;
    
    _rows = 5 + _level;
    _cols = 3;
    for (int i = 0; i < _rows*_cols; i++) {
        [_availableBlockSlots addObject:[NSString stringWithFormat:@"%d", i]];
    }

    // ready
    SKLabelNode *ready = [SKLabelNode labelNodeWithFontNamed:@"AvenirNext-Heavy"];
    ready.text = @"READY";
    ready.position = CGPointMake(CGRectGetMidX(self.frame), self.frame.size.height + ready.frame.size.height/2);
    [self addChild:ready];
    [ready runAction:[SKAction sequence:@[_wait, _wait, _topToMiddle, _wait, _wait, _shrinkAway]]];
    
    // balls
    [self runAction:[SKAction sequence:@[_wait,_wait,_wait, [SKAction runBlock:^{
                                                                        [BlongBall ballOnLeft:YES withScene:self];
                                                                        [BlongBall ballOnLeft:NO withScene:self];}], sound11]]];
    
    
    // steady
    SKLabelNode *steady = [SKLabelNode labelNodeWithFontNamed:@"AvenirNext-Heavy"];
    steady.text = @"STEADY";
    steady.position = CGPointMake(CGRectGetMidX(self.frame), self.frame.size.height + ready.frame.size.height/2);
    steady.zPosition = 1;
    [self addChild:steady];
    [steady runAction:[SKAction sequence:@[_wait, _wait, _wait, _wait, _wait, _wait, _topToMiddle, _shrinkAway]]];
    
    // bricks
    SKAction *moveInBricks = [SKAction runBlock:^{
        for (int i = 0; i<_rows; i++) {
            for (int j = 0; j<_cols; j++) {
                [BlongBrick brickWithScene:self fromRandom:YES];
            }
        }
    }];
    [self runAction:[SKAction sequence:@[_wait, _wait, _wait, _wait, _wait, _wait, _wait, moveInBricks, sound29]]];

    // blong
    SKSpriteNode *blong = [SKSpriteNode spriteNodeWithImageNamed:@"blong_background"];
    SKAction *startPhysics = [SKAction runBlock:^{
        self.physicsWorld.speed = 1;
    }];
    [blong setAlpha:0];
    SKAction *fadeIn = [SKAction fadeAlphaTo:.2 duration:0];

    [blong runAction:[SKAction sequence:@[_wait, _wait, _wait, _wait, _wait, _wait, _wait, _wait, _wait, startPhysics, makeNoise, fadeIn, _fadeOut]]];
    blong.position = CGPointMake(CGRectGetMidX(self.frame), CGRectGetMidY(self.frame));
    [self addChild:blong];
    
    if (_cockblockTimer.isValid) {
        [_cockblockTimer invalidate];
    }
    _cockblockTimer = [NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(incrementCockblock:) userInfo:nil repeats:YES];

}

-(void)incrementCockblock:(NSTimer *)timer {
    if (!self.paused) {
        _nextCockblock++;
        if (_nextCockblock >= 10) {
            _nextCockblock = 0;
            [BlongBrick brickWithScene:self fromRandom:NO];
        }
    }
}

-(void)updateScore:(int) pointsAdded {
    _score = _score + pointsAdded;
    _scoreLabel.text = [NSString stringWithFormat:@"%06d", _score];
}

-(void)didBeginContact:(SKPhysicsContact *)contact {
    SKPhysicsBody *ball, *secondBody;
    if (contact.bodyA.categoryBitMask < contact.bodyB.categoryBitMask) {
        ball = contact.bodyA;
        secondBody = contact.bodyB;
    } else {
        ball = contact.bodyB;
        secondBody = contact.bodyA;
    }
    
    // TODO: make this less shitty
    if (secondBody.categoryBitMask & paddleCat) {
        float relativeIntersectY = ball.node.position.y - secondBody.node.position.y;

        
//        this should be cooler and preserve momentum, but doesn't and ends up with nans
//        NSLog(@"relative intersect: %f", relativeIntersectY);
//        float newY = 200 * relativeIntersectY/secondBody.node.frame.size.height;
//        float totalVelocity = sqrtf((ball.velocity.dx * ball.velocity.dx) + (ball.velocity.dy * ball.velocity.dy));
//        NSLog(@"old total: %f, x,y: %f,%f", totalVelocity, ball.velocity.dx, ball.velocity.dy);
//        float newX = sqrtf((totalVelocity * totalVelocity) - (newY * newY));
//        if (ball.velocity.dx > 0) {
//            newX = -newX;
//        }
//        ball.velocity = CGVectorMake(newX, newY);
//        float newTotalVelocity = sqrtf((ball.velocity.dx * ball.velocity.dx) + (ball.velocity.dy * ball.velocity.dy));
//        NSLog(@"new total: %f, x,y: %f,%f", newTotalVelocity, newX, newY);

        if (fabsf(ball.velocity.dy) < 500) {
            float yVelocity = maxVelocity * relativeIntersectY/secondBody.node.frame.size.height * 2;
            CGVector velocity = [self calculateVelocityFromY:yVelocity];
            BOOL right = ball.node.position.x > CGRectGetMidX(self.frame);
            if (right) {
                velocity.dx = -velocity.dx;
            }
            ball.velocity = velocity;
        }
        [self runAction:bip];
    }
    
    // this is a check to see if it's moving too slowly horizontally, and give it a little push
    if (secondBody.categoryBitMask & wallCat) {
        if (fabsf(ball.velocity.dx) < 30) {
            if (ball.velocity.dx < 0) {
                [ball applyImpulse:CGVectorMake(-1, 0)];
            } else {
                [ball applyImpulse:CGVectorMake(1, 0)];
            }
        }
        
    }
    
    if (secondBody.categoryBitMask & brickCat) {
        [self removeBrick:(BlongBrick *)secondBody.node];
        [self runAction:bop];
    }
}

-(void)removeBrick:(BlongBrick *)brick {
    [self updateScore:1];
    SKAction *shrink = [SKAction scaleTo:0 duration:.1];
    SKAction *removeFromBricks = [SKAction runBlock:^{
        _lastBlockCleared = [brick.userData objectForKey:@"blockSlot"];
        [_availableBlockSlots addObject:_lastBlockCleared];
        [_bricks removeObject:brick];
        [self checkBreakthrough];
    }];
    SKAction *removeFromParent = [SKAction removeFromParent];
    
    [brick runAction: [SKAction sequence: @[shrink, removeFromBricks, removeFromParent]]];
    
}

-(void)checkBreakthrough {
    if (!_brokenThrough) {
        for (int i = 0; i < _rows; i++) {
            bool justBrokeThrough = YES;
            for (int j = 0; j < _cols; j++) {
                if (![_availableBlockSlots containsObject:[NSString stringWithFormat:@"%d", i*_cols + j]]) {
                    justBrokeThrough = NO;
                    break;
                }
            }
            if (justBrokeThrough) {
                SKLabelNode *breakthrough = [SKLabelNode labelNodeWithFontNamed:@"AvenirNext-Heavy"];
                breakthrough.text = @"BREAKTHROUGH";
                breakthrough.position = CGPointMake(CGRectGetMidX(self.frame), 0);
                breakthrough.fontColor = [SKColor blueColor];
                breakthrough.zPosition = 1;
                [self addChild:breakthrough];
                [breakthrough runAction:[SKAction sequence:@[_wait, _wait, _shrinkAway]]];
                CGPoint lastBrickPoint = [BlongBrick calculatePositionFromSlot:_lastBlockCleared withNode:[_balls objectAtIndex:0] withScene:self];
                [BlongBall ballWithX:lastBrickPoint.x withY:lastBrickPoint.y withScene:self];
                [self makeParticleAt:lastBrickPoint];
                _brokenThrough = YES;
                break; // dicks
            }
        }
    }
}

-(void)removeBall:(BlongBall *)ball {
    [_balls removeObject:ball];
    [ball runAction:[SKAction removeFromParent]];
}

-(CGVector)calculateVelocityFromY:(float) yVelocity {
    if (yVelocity >= maxYVelocity) {
        yVelocity = maxYVelocity;
    }
    if (yVelocity <= -maxYVelocity) {
        yVelocity = -maxYVelocity;
    }
    float xVelocity = sqrtf(powf(maxVelocity, 2) - powf(yVelocity, 2));
    return CGVectorMake(xVelocity, yVelocity);
}

-(void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {
    [self processTouches:touches withEvent:event];
}

-(void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {    
    [self processTouches:touches withEvent:event];
}

-(void)processTouches:(NSSet *)touches withEvent:(UIEvent *)event {
    for (UITouch *touch in touches) {
        [self processTouch:touch];
    }
}

-(void)processTouch:(UITouch *)touch {
    if (self.paused) {
        return;
    }
    
    CGPoint location = [touch locationInNode:self];
    if (location.x < CGRectGetMidX(self.frame)) {
        CGPoint point = CGPointMake(_leftPaddle.position.x, location.y);
        _leftPaddle.position = point;
        if (!touchedLeft) {
            touchedLeft = YES;
            [BlongBall shootBallAtPoint:point withScene:self];
        }
    } else {
        CGPoint point = CGPointMake(_rightPaddle.position.x, location.y);
        _rightPaddle.position = point;
        if (!touchedRight) {
            touchedRight = YES;
            [BlongBall shootBallAtPoint:point withScene:self];
        }
    }
    if (touchedLeft && touchedRight) {
        started = YES;
    }
}

-(void)newLevel {
    _level++;
    self.physicsWorld.speed = 0;
    [self stopCountdown];
    NSMutableArray *ballSequence = [NSMutableArray array];
    for (BlongBall *ball in _balls) {
        [ballSequence addObject:_wait];
        [ballSequence addObject:[SKAction runBlock:^{
            [self makeParticleAt:ball.position];
            [ball removeFromParent];
            [self updateScore:10];
            [self runAction:explosion];
        }]];
    }
    [self runAction:[SKAction sequence:ballSequence]];
    _nextCockblock = 0;

    _balls = [NSMutableArray array];
    
    SKLabelNode *levelText = [SKLabelNode labelNodeWithFontNamed:@"AvenirNext-Heavy"];
    levelText.text = [NSString stringWithFormat:@"Level %d", _level];
    levelText.position = CGPointMake(CGRectGetMidX(self.frame), levelText.frame.size.height * 2);
    [levelText setAlpha:0];
    [self addChild:levelText];
    SKAction *waitFadeIn_fadeOutStartLevel = [SKAction sequence:@[
          [SKAction waitForDuration:.5],
          [SKAction fadeInWithDuration:1],
          [SKAction waitForDuration:.5],
          [SKAction fadeOutWithDuration:1],
          [SKAction runBlock:^{[self startLevel];}]
    ]];

    [levelText runAction:waitFadeIn_fadeOutStartLevel];
    
    [_leftPaddle shrink:.9];
    [_rightPaddle shrink:.9];
}

-(void)gameOver {
    [BlongGameCenterHelper reportScore:_score];
    SKScene *gameOverScene = [[BlongGameOverScene alloc] initWithSize:self.size];
    SKTransition *transition = [SKTransition fadeWithDuration:2];
    [self runAction:gameOver];
    [self.view presentScene:gameOverScene transition:transition];
}

-(void)update:(NSTimeInterval)currentTime {
    if (self.physicsWorld.speed > 0 && !self.paused && started) {
        if (_balls.count == 0) {
            self.physicsWorld.speed = 0;
            [self gameOver];
        } else if (_balls.count == 1 && _level != 1) {
            [self startCountdown];
        } else if (_balls.count > 1 && _countdownTimer.isValid) {
            [self stopCountdown];
        }
        
        // sometimes balls stick around forever and i don't know why
        for (BlongBall *ball in _balls) {
            if (ball.position.x < 0 || ball.position.x > self.frame.size.width ||
                ball.position.y < 0 || ball.position.y > self.frame.size.height) {
                [self removeBall:ball];
                break;
            }
        }
        
        if (_bricks.count == 0) {
            [self newLevel];
        }
    }
}

-(void)stopCountdown {
    [_countdownTimer invalidate];
    [_countdownClock removeFromParent];
}

-(void)startCountdown {
    if (!_countdownTimer || !_countdownTimer.isValid) {
        _countdownTimer = [NSTimer scheduledTimerWithTimeInterval:.01f target:self selector:@selector(updateCountdown:) userInfo:nil repeats:YES];
        _secondsLeft = countdown;
        _countdownClock = [SKLabelNode labelNodeWithFontNamed:@"AvenirNext-Heavy"];
        _countdownClock.horizontalAlignmentMode = SKLabelHorizontalAlignmentModeLeft;
        _countdownClock.text = [NSString stringWithFormat:@"%.02f", _secondsLeft];
        _countdownClock.fontColor = [SKColor redColor];
        _countdownClock.position = CGPointMake(CGRectGetMidX(self.frame) - _countdownClock.frame.size.width/2, 0);
        _countdownClock.zPosition = 1;
        [self addChild:_countdownClock];
    }
}

-(void) updateCountdown:(NSTimer *)timer {
    if (!self.paused) {
        _secondsLeft -= .01;
        _countdownClock.text = [NSString stringWithFormat:@"%.02f", _secondsLeft];
        if (_secondsLeft <= 0.0) {
            self.paused = YES;
            [_countdownTimer invalidate];
            _countdownClock.text = @"0.00";
            [self gameOver];
        }
    }
}

-(void)makeParticleAt:(CGPoint) point {
    NSString *particlePath = [[NSBundle mainBundle] pathForResource:@"MyParticle" ofType:@"sks"];
    SKEmitterNode *particle = [NSKeyedUnarchiver unarchiveObjectWithFile:particlePath];
    particle.position = point;
    SKAction *stop = [SKAction runBlock:^{
        particle.particleBirthRate = 0;
    }];
    [particle runAction:[SKAction sequence:@[_wait, stop, [SKAction waitForDuration:2], [SKAction removeFromParent]]]];
    [self addChild:particle];
}

-(CGPoint) getRandomOffScreenPointForNode:(SKNode * )node {
    float x = arc4random() % (int) self.scene.frame.size.width;
    float y;
    BOOL top = arc4random() % 2;
    if (top) {
        y = self.scene.frame.size.height + node.frame.size.height;
    } else {
        y = -node.frame.size.height;
    }
    
    return CGPointMake(x,y);
}

-(CGPoint) topLeft {
    return CGPointMake(CGRectGetMidX(self.frame) - ((((float)self.cols)/2.0)*self.brickSize.width) + self.brickSize.width/2.0, self.frame.size.height - self.brickSize.height/2.0);
}

-(void)didSimulatePhysics {
    
}

@end
