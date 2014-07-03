//
//  ViewController.m
//  BeaconCentralTest
//
//  Created by 前田 誠也 on 2014/07/04.
//  Copyright (c) 2014年 Seiya Maeda. All rights reserved.
//

// 受信側セントラル Central

#import "ViewController.h"
#import <CoreLocation/CoreLocation.h>

// UUID
#define UUID @"096781F6-8F73-41D2-A768-FB45AE14BDC9"
// Beacon信号に含まれず、領域識別のための内部管理用の識別子
#define IDENTIFER @"info.maezono.beacontest"

@interface ViewController () <CLLocationManagerDelegate>

@property(nonatomic, strong) CLLocationManager *locationManager;
@property(nonatomic, strong) NSUUID *proximityUUID;
@property(nonatomic, strong) CLBeaconRegion *beaconRegion;

@end

@implementation ViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    
    if ([CLLocationManager isMonitoringAvailableForClass:[CLBeaconRegion class]])
    {
        // CLLocationManagerの生成とデリゲートの設定
        self.locationManager = [CLLocationManager new];
        self.locationManager.delegate = self;
        
        // 生成したUUIDからNSUUIDを作成
        self.proximityUUID = [[NSUUID alloc] initWithUUIDString:UUID];
        
        // CLBeaconRegionを作成
        self.beaconRegion = [[CLBeaconRegion alloc] initWithProximityUUID:self.proximityUUID
                                                               identifier:IDENTIFER];
        
        [self.locationManager startMonitoringForRegion:self.beaconRegion];
        
        NSLog(@"Beaconによる領域観測を開始");
    }else{
        NSLog(@"このデバイスでは領域観測を使用できません。");
    }
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - locationManager delegate

// モニタリング開始が正常に始まった時に呼ばれる
//　startMonitoringForRegionが呼ばれたら、こいつが呼ばれる
- (void)locationManager:(CLLocationManager *)manager didStartMonitoringForRegion:(CLRegion *)region
{
    NSLog(@"モニタリング正常に始まったよ");
    
    // ここでiOS7から追加された”CLLocationManager requestStateForRegion:”を呼び出し、現在自分が、iBeacon監視でどういう状態にいるかを知らせてくれるように要求します。
    [self.locationManager requestStateForRegion:self.beaconRegion];
}

// 領域へ入ったら呼ばれる
- (void)locationManager:(CLLocationManager *)manager didEnterRegion:(CLRegion *)region
{
    [self sendLocalNotificationForMessage:@"Enter Region"];
    
    // Beaconの観測を開始する
    if([region isMemberOfClass:[CLBeaconRegion class]] && [CLLocationManager isRangingAvailable])
    {
        [self.locationManager startRangingBeaconsInRegion:(CLBeaconRegion*)region];
    }
    
    NSLog(@"Enter Region");
}

// 領域から出たら呼ばれる
- (void)locationManager:(CLLocationManager *)manager didExitRegion:(CLRegion *)region
{
    // ローカル通知
    [self sendLocalNotificationForMessage:@"Exit Region"];
    
    // Beaconの観測を停止する
    if([region isMemberOfClass:[CLBeaconRegion class]] && [CLLocationManager isRangingAvailable])
    {
        [self.locationManager stopRangingBeaconsInRegion:(CLBeaconRegion*)region];
    }
    
    NSLog(@"Exit Region");
}

//ユーザが領域境界を横切らなければ、
//上記のメソッドが呼び出されることはありません。特に、ユーザが既に領域内にいる場合、位置情報
//マネージャがlocationManager:didEnterRegion:を呼び出すことはありません

// 領域へ入った後のハンドリング
// locationManager:didEnterRegion:メソッドが正常に呼ばれたらこいつが呼ばれる
- (void)locationManager:(CLLocationManager *)manager didRangeBeacons:(NSArray *)beacons inRegion:(CLBeaconRegion *)region
{
    if(beacons.count > 0)
    {
        // 最も近いBeaconについて処理する
        CLBeacon *beacon = beacons.firstObject;
        
        NSString *rangeMessage;
        
        // Beaconの距離でメッセージを変える
        switch (beacon.proximity) {
            case CLProximityImmediate:
                rangeMessage = @"Range Immediate: ";
                break;
            case CLProximityNear:
                rangeMessage = @"Range Near: ";
                break;
            case CLProximityFar:
                rangeMessage = @"Range Far: ";
                break;
            default:
                rangeMessage = @"Range Unknown: ";
                break;
        }
        
        NSLog(@"%@", rangeMessage);
        
        // ローカル通知
        NSString *message = [NSString stringWithFormat:@"major:%@, minor:%@, accuracy:%f, rssi:%ld", beacon.major, beacon.minor, beacon.accuracy, (long)beacon.rssi];
        
        NSLog(@"%@", message);
        
        [self sendLocalNotificationForMessage:[rangeMessage stringByAppendingString:message]];
    }
}

-(void)locationManager:(CLLocationManager *)manager didDetermineState:(CLRegionState)state forRegion:(CLRegion *)region{
    
    switch (state) {
        case CLRegionStateInside:
            if([region isMemberOfClass:[CLBeaconRegion class]] && [CLLocationManager isRangingAvailable]){
                NSLog(@"Enter %@",region.identifier);
                //Beacon の範囲内に入った時に行う処理を記述する
                //CLRegionStateInside が渡ってきていれば、すでになんらかのiBeaconのリージョン内にいるので、iOS7から追加された”CLLocationManager startRangingBeaconsInRegion:”を呼び、通知の受け取りを開始します。
                [self.locationManager startRangingBeaconsInRegion:self.beaconRegion];
            }
            break;
            
        case CLRegionStateOutside:
            NSLog(@"Outside %@",region.identifier);
            break;
        case CLRegionStateUnknown:
            NSLog(@"Unknown %@",region.identifier);
            break;
        default:
            break;
    }
}

// エラー系メソッド
// startMonitoringForRegionが失敗した時に呼ばれる
-(void)locationManager:(CLLocationManager *)manager monitoringDidFailForRegion:(CLRegion *)region withError:(NSError *)error{
    
    NSLog(@"monitoringDidFailForRegion:%@(%@)", region.identifier, error);
    
}
// イベントの取得時にエラーがでた時に呼ばれる
// 位置情報サービスへのアクセスが拒否された場合にも（http://dev.classmethod.jp/smartphone/iphone/ios-tips-5/）
-(void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error{
    
    NSLog(@"didFailWithError:%@", error);
}
// 何らかの不具合によりエラーが発生した場合に呼ばれる
-(void)locationManager:(CLLocationManager *)manager rangingBeaconsDidFailForRegion:(CLBeaconRegion *)region withError:(NSError *)error{
    
    NSLog(@"didFailWithError:%@(%@)", region.identifier, error);
}

#pragma mark - youthful method

// LocalNotificationを送る処理
- (void)sendLocalNotificationForMessage:(NSString *)message
{
    UILocalNotification *localNotification = [UILocalNotification new];
    localNotification.alertBody = message;
    localNotification.fireDate = [NSDate date];
    localNotification.soundName = UILocalNotificationDefaultSoundName;
    [[UIApplication sharedApplication] scheduleLocalNotification:localNotification];
}

@end
