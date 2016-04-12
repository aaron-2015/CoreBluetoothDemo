//
//  CentralViewController.m
//  BLEDemo
//
//  Created by aaron on 16/4/8.
//  Copyright © 2016年 aaron. All rights reserved.
//

#import "CentralViewController.h"
#import <CoreBluetooth/CoreBluetooth.h>
#import <CoreTelephony/CTCallCenter.h>
#import <CoreTelephony/CTTelephonyNetworkInfo.h>
#import <CoreTelephony/CTCarrier.h>
#import <CoreTelephony/CTCall.h>
#import "Header.h"
extern NSString *CTSettingCopyMyPhoneNumber();

@interface CentralViewController ()<CBCentralManagerDelegate,CBPeripheralDelegate>


@property (nonatomic, strong) CBCentralManager *centralManager; //中心管理者
@property (nonatomic, strong) NSMutableArray *peripherals; //连接的外围设备
@property (nonatomic, strong) CBCharacteristic *curCharacter; //当前服务的特征
@property (nonatomic, strong) CBCharacteristic *teleCharacter; //来电提醒特征
@property (nonatomic, strong) CBCharacteristic *cleanCharacter; //清除数据特征
@property (nonatomic, strong) CBCharacteristic *rideCharacter; //骑行数据特征
@property (nonatomic, strong) CBPeripheral *curPeripherals;

@property (nonatomic, strong)  NSTimer *timer;

//电话状态
@property (nonatomic, strong) CTCallCenter *callCenter;

@property (weak, nonatomic) IBOutlet UITextView *logText;

@property (weak, nonatomic) IBOutlet UITextField *speedText;
@end

@implementation CentralViewController

#pragma mark - life cycle

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    //01,设置info.plist
//    <key>UIBackgroundModes</key>
//    <array>
//    <string>bluetooth-central</string>
//    <string>bluetooth-peripheral</string>
//    </array>
    
    
    //02 ,改变出初始化方式
    _centralManager = [[CBCentralManager alloc] initWithDelegate:self
                                                           queue:nil
                                                         options:@{CBCentralManagerOptionRestoreIdentifierKey:kRestoreIdentifierKey}];
    _peripherals = [NSMutableArray array];
    
    [self getCarrierInfo];
}

- (void)dealloc{
    [_timer invalidate];
}

- (void)getCarrierInfo {
    // 获取运营商信息
    CTTelephonyNetworkInfo *info = [[CTTelephonyNetworkInfo alloc] init];
    CTCarrier *carrier = info.subscriberCellularProvider;
    NSLog(@"carrier:%@", [carrier description]);
    
    // 如果运营商变化将更新运营商输出
    info.subscriberCellularProviderDidUpdateNotifier = ^(CTCarrier *carrier) {
        NSLog(@"carrier:%@", [carrier description]);
    };
    
    // 输出手机的数据业务信息
    NSLog(@"Radio Access Technology:%@", info.currentRadioAccessTechnology);
    
    // 监控通话信息
    CTCallCenter *center = [[CTCallCenter alloc] init];
    _callCenter = center;
    center.callEventHandler = ^(CTCall *call) {
        NSSet *curCalls = _callCenter.currentCalls;
        NSLog(@"current calls:%@", curCalls);
        NSLog(@"call:%@", [call description]);
        NSLog(@"Number:%@", [self myNumber]);
        
        if ([call.callState isEqualToString:CTCallStateIncoming]) { //来电
            [self UDID2A57WriteforCharacteristic:_teleCharacter withState:CTCallStateIncoming];
            [self pause:nil];
        }
        else if ([call.callState isEqualToString:CTCallStateDisconnected]){ //挂断
            [self UDID2A57WriteforCharacteristic:_teleCharacter withState:CTCallStateDisconnected];
            [self resume:nil];
        }
        
    };
}

- (NSString *)myNumber{
    return CTSettingCopyMyPhoneNumber();
}

- (void)writeToLogWithText:(NSString *)text{
    
    NSLog(@"%@",text);
    self.logText.text = [NSString stringWithFormat:@"%@\n%@",self.logText.text,text];
}

#pragma mark - private method 

- (IBAction)cancelDidClick:(UIButton *)sender {
    
    [self cancelNotify];
}

- (IBAction)confignotify:(UIButton *)sender {
    
    [self configNotify];
}

- (IBAction)sendData:(UIButton *)sender {
    
    if (_curCharacter != nil && _curPeripherals !=nil) {
        [_curPeripherals writeValue:[@"hello,外设" dataUsingEncoding:NSUTF8StringEncoding] forCharacteristic:_curCharacter type:CBCharacteristicWriteWithResponse];
        [self writeToLogWithText:@"写数据给外设"];
    }
}

- (IBAction)start:(UIButton *)sender {
    if (![_timer isValid]) {
        _timer =  [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(UDID2A5BWriteforCharacteristic) userInfo:nil repeats:YES];
    }
}

- (IBAction)pause:(id)sender {
    [_timer setFireDate:[NSDate distantFuture]];
}

- (IBAction)resume:(id)sender {
    [_timer setFireDate:[NSDate date]];
}

- (IBAction)claen:(UIButton *)sender {
    [self UDID2A58ReadforCharacteristic];
}


//取消订阅
- (void)cancelNotify{
    
    CBPeripheral *peripheral = _peripherals.firstObject;
    [peripheral setNotifyValue:NO forCharacteristic:_curCharacter];
    [self writeToLogWithText:@"取消订阅特征通知"];
}

//订阅特征
- (void)configNotify{
    
    CBPeripheral *peripheral = _peripherals.firstObject;
    [peripheral setNotifyValue:YES forCharacteristic:_curCharacter];
    [self writeToLogWithText:@"订阅特征通知"];
}

#pragma mark - CBCentralManagerDelegate

- (void)centralManager:(CBCentralManager *)central willRestoreState:(NSDictionary<NSString *,id> *)dict{
    
//    NSArray *scanServices = dict[CBCentralManagerRestoredStateScanServicesKey];
//    NSArray *scanOptions = dict[CBCentralManagerRestoredStateScanOptionsKey];
    
    NSArray *peripherals = dict[CBCentralManagerRestoredStatePeripheralsKey];
    for (CBPeripheral *peripheral in peripherals) {
        [self.peripherals addObject:peripheral];
        peripheral.delegate = self;
    }
}

- (void)centralManagerDidUpdateState:(CBCentralManager *)central{
    
    if (central.state == CBCentralManagerStatePoweredOn) {
        [self writeToLogWithText:@"中心设备已打开"];
        [_centralManager scanForPeripheralsWithServices:nil options:nil];
        
        //03,检查是否restore connected peripherals
        for (CBPeripheral *peripheral in _peripherals) {
            if (peripheral.state == CBPeripheralStateConnected) {
                NSUInteger serviceIdx = [peripheral.services indexOfObjectPassingTest:^BOOL(CBService * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                    return [obj.UUID isEqual:kServiceUUID];
                }];
                
                if (serviceIdx == NSNotFound) {
                    [peripheral discoverServices:@[kServiceUUID]];
                    continue;
                }
                
                CBService *service = peripheral.services[serviceIdx];
                NSUInteger charIdx = [service.characteristics indexOfObjectPassingTest:^BOOL(CBCharacteristic * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                    return [obj.UUID isEqual:kNotifyUUID];
                }];
                
                if (charIdx == NSNotFound) {
                    [peripheral discoverCharacteristics:@[kNotifyUUID] forService:service];
                    continue;
                }
                
                CBCharacteristic *characteristic = service.characteristics[charIdx];
                if (!characteristic.isNotifying) {
                    [peripheral setNotifyValue:YES forCharacteristic:characteristic];
                }
            }
        }
        
    }else{
        [_peripherals removeAllObjects];
    }
}

- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary<NSString *,id> *)advertisementData RSSI:(NSNumber *)RSSI{
    
    [self writeToLogWithText:[NSString stringWithFormat:@"发现外围设备:%@",peripheral]];
//    [_centralManager stopScan];
//    if ([peripheral.name hasPrefix:@"iP"]|| [peripheral.name hasPrefix:@"aaron"]) {
//        if (![_peripherals containsObject:peripheral]) {
//            [_peripherals addObject:peripheral];
//        }
//        [self writeToLogWithText:[NSString stringWithFormat:@"开始连接外围设备--%@",peripheral]];
//        [_centralManager connectPeripheral:peripheral options:nil];
//    }
    
    if ([peripheral.name hasPrefix:@"XINGZHE"]) {
        [self writeToLogWithText:[NSString stringWithFormat:@"开始连接行者--%@",peripheral]];
        [_peripherals addObject:peripheral];
        [_centralManager connectPeripheral:peripheral options:nil];
    }
}

- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral{

    [_centralManager stopScan];
    [self writeToLogWithText:@"连接设备成功"];
    peripheral.delegate = self;
    _curPeripherals = peripheral;
    //外围设备开始寻找服务
    [peripheral discoverServices:nil];
}

#pragma mark - CBPeripheralDelegate

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error{
    
    for (CBService *service in peripheral.services) {
        //外围设备查找指定服务中的特征
        if ([service.UUID.UUIDString isEqualToString:@"3958"]) {
            [self writeToLogWithText:@"已发现可用服务3958"];
            [peripheral discoverCharacteristics:nil forService:service]; //指定service UDID
        }
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(nonnull CBService *)service error:(nullable NSError *)error{
    
    [self writeToLogWithText:@"已发现可用特征"];
    for (CBCharacteristic *characteristic in service.characteristics) {
        
        //情景一：读取
//        if (characteristic.properties & CBCharacteristicPropertyRead) {
//            if ([characteristic.UUID.UUIDString isEqualToString:kReadUUID]) {
//                [peripheral readValueForCharacteristic:characteristic];
//                if (characteristic.value) {
//                    NSString *value=[[NSString alloc]initWithData:characteristic.value encoding:NSUTF8StringEncoding];
//                    NSLog(@"读取到特征值：%@",value);
//                }
//            }
//        }

        //情景二：通知
//        if (characteristic.properties & CBCharacteristicPropertyNotify) {
//            if ([characteristic.UUID.UUIDString isEqualToString:kNotifyUUID] || [characteristic.UUID.UUIDString isEqualToString:kWriteUUID]) {
//                _curCharacter = characteristic;
//                [peripheral setNotifyValue:YES forCharacteristic:characteristic];
//                [self writeToLogWithText:@"已订阅特征通知"];
//            }
//        }
        
        //情景二：写数据
//        if (characteristic.properties & CBCharacteristicPropertyWrite) {
//            if ([characteristic.UUID.UUIDString isEqualToString:kWriteUUID]) {
//                [peripheral writeValue:[@"hello,外设" dataUsingEncoding:NSUTF8StringEncoding] forCharacteristic:characteristic type:CBCharacteristicWriteWithResponse];
//                [self writeToLogWithText:@"写数据给外设"];
//                
//                _curPeripherals = peripheral;
//                _curCharacter = characteristic;
//            }
//        }
        
        //2A56
        if ( (characteristic.properties & CBCharacteristicPropertyWrite) && [characteristic.UUID.UUIDString isEqualToString:@"2A56"]) {
            [self UDID2A56WriteforCharacteristic:characteristic];
        }
        
        //2A57，来电提醒功能
        if ( (characteristic.properties & CBCharacteristicPropertyWrite) && [characteristic.UUID.UUIDString isEqualToString:@"2A57"]) {
            _teleCharacter = characteristic;
        }
        
        //2A58，清除运动数据功能
        if ( (characteristic.properties & CBCharacteristicPropertyRead) && [characteristic.UUID.UUIDString isEqualToString:@"2A58"]) {
            _cleanCharacter = characteristic;
        }
        
        //2A5B
        if ((characteristic.properties & CBCharacteristicPropertyWrite) &&[characteristic.UUID.UUIDString isEqualToString:@"2A5B"]) {
            [self writeToLogWithText:@"2A5B,写骑行数据包"];
            _rideCharacter = characteristic;
        }
    }
}

//2A5B
- (void)UDID2A5BWriteforCharacteristic{
    if ([_rideCharacter.UUID.UUIDString isEqualToString:@"2A5B"]) {
        
        UInt8 Flag = 8;
        UInt16 speed = arc4random()%500;
        UInt32 ThirdDst = 100;
        UInt32 ThirdTime = 1024;
        UInt32 Calorie = 100;
        UInt16 Altilitude = 10010;
        UInt8 HeartRate = 90;
        UInt8 Cadence = 0;
        UInt8 AvgCadence = 0;
        
        Byte array[20];
        array[0] = Flag & 0xff;
        
        array[1] = speed & 0xff;
        array[2] = (speed >> 8) &0xff;
        
        array[3] = ThirdDst &0xff;
        array[4] = (ThirdDst >> 8) & 0xff;
        array[5] = (ThirdDst >> 16) & 0xff;
        array[6] = (ThirdDst >> 24) & 0xff;
        
        array[7] = ThirdTime &0xff;
        array[8] = (ThirdTime >> 8) & 0xff;
        array[9] = (ThirdTime >> 16) & 0xff;
        array[10] = (ThirdTime >> 24) & 0xff;
        
        array[11] = Calorie &0xff;
        array[12] = (Calorie >> 8) & 0xff;
        array[13] = (Calorie >> 16) & 0xff;
        array[14] = (Calorie >> 24) & 0xff;
        
        array[15] = Altilitude & 0xff;
        array[16] = (Altilitude >> 8) &0xff;
        
        array[17] = HeartRate;
        
        array[18] = Cadence;
        
        array[19] = AvgCadence;
        
        NSData *data = [NSData dataWithBytes:array length:20];
        
        [_curPeripherals writeValue:data forCharacteristic:_rideCharacter type:CBCharacteristicWriteWithResponse];
    }
}

//2A56
- (void)UDID2A56WriteforCharacteristic:(CBCharacteristic *)characteristic{
    
    if ([characteristic.UUID.UUIDString isEqualToString:@"2A56"]) {
        [self writeToLogWithText:@"2A56,初始化骑行相关配置数据"];
        
        NSDate *date = [NSDate date];
        NSDateFormatter *dataFormatter = [[NSDateFormatter alloc] init];
        dataFormatter.dateFormat =@"HH:mm:ss";
//        NSDateComponents *cmps = [[NSDate date] deltaFromDate:createDate];
        
        UInt8 Hour = 8;
        UInt32 Time = 0;
        UInt8 Uint = 1;
        UInt16 Perimeter = 1000;
        UInt32 Weight = 60000;
        
        Byte array[12];
        array[0] = Hour & 0xff;
        
        array[1] = Time & 0xff;
        array[2] = (Time >> 8) &0xff;
        array[3] = (Time >> 16) &0xff;
        array[4] = (Time >> 24) &0xff;
        
        array[5] = Uint & 0xff;
        
        array[6] = Perimeter & 0xff;
        array[7] = (Perimeter >> 8) & 0xff;
        
        array[8]  = Weight & 0xff;
        array[9]  = (Weight >> 8) & 0xff;
        array[10] = (Weight >> 16) & 0xff;
        array[11] = (Weight >> 24) & 0xff;
        
        NSData *data = [NSData dataWithBytes:array length:sizeof(array)];
        
        [_curPeripherals writeValue:data forCharacteristic:characteristic type:CBCharacteristicWriteWithResponse];
    }
}

//2A57 来点提醒
- (void)UDID2A57WriteforCharacteristic:(CBCharacteristic *)characteristic withState:(NSString *)CTCallState{
    if ([characteristic.UUID.UUIDString isEqualToString:@"2A57"]) {
        
        [self writeToLogWithText:@"来点提醒"];
        
        UInt8 Hour;
        NSString *content;
        if ([CTCallState isEqualToString:CTCallStateIncoming]) {
            Hour = 1;
            content = @"telephoneIncoming";
        } else {
            Hour = 0;
            content = @"telephoneDisconnected";
        }
        
         Byte array[1];
        array[0] = Hour;
        
        NSMutableData *data = [[NSMutableData alloc] init];
        [data appendBytes:array length:1];
        [data appendData:[content dataUsingEncoding:NSUTF8StringEncoding]];
        
        [_curPeripherals writeValue:data forCharacteristic:characteristic type:CBCharacteristicWriteWithResponse];
    }
}

//2A58
- (void)UDID2A58ReadforCharacteristic{
    if ([_cleanCharacter.UUID.UUIDString isEqualToString:@"2A58"]) {
        [self writeToLogWithText:@"清除数据"];
        [_timer invalidate];
        [_curPeripherals readValueForCharacteristic:_cleanCharacter];
    }
}


//// int 2 byte
//BYTE *Int2Byte(int nVal)
//{
//    BYTE *pByte = new BYTE[4];
//    for (int i = 0; i<4;i++)
//    {
//        pByte[i] = (BYTE)(nVal >> 8*(3-i) & 0xff);
//    }
//    return pByte;
//}
//
//// byte 2 int
//int Byte2Int(BYTE *pb)
//{
//    // assume the length of pb is 4
//    int nValue=0;
//    for(int i=0;i < 4; i++)
//    {
//        nValue += ( pb[i] & 0xFF)<<(8*(3-i));
//    }
//    return nValue;
//}

- (void)int2bytetest{
    Byte array[] = {0};
    int nval= 8;
    array[0] = nval & 0xff;
    
    NSLog(@"%s",array);
}

- (void)peripheral:(CBPeripheral *)peripheral didUpdateNotificationStateForCharacteristic:(nonnull CBCharacteristic *)characteristic error:(nullable NSError *)error{
    
    NSString *value=[[NSString alloc]initWithData:characteristic.value encoding:NSUTF8StringEncoding];
    [self writeToLogWithText:[NSString stringWithFormat:@"读取特征值：%@",value]];
}

- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(nonnull CBCharacteristic *)characteristic error:(nullable NSError *)error{
    
    NSString *value=[[NSString alloc]initWithData:characteristic.value encoding:NSUTF8StringEncoding];
    [self writeToLogWithText:[NSString stringWithFormat:@"读取特征值：%@",value]];
    
    if ([characteristic.UUID.UUIDString isEqualToString:@"2A58"]) {
       [self writeToLogWithText:@"清除数据功能"];
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didWriteValueForCharacteristic:(nonnull CBCharacteristic *)characteristic error:(nullable NSError *)error{
    
    NSString *UDIDString = characteristic.UUID.UUIDString;
    [self writeToLogWithText:[NSString stringWithFormat:@"写数据到UDID：%@",UDIDString]];
}

@end
