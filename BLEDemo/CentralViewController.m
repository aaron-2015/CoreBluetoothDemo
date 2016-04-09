//
//  CentralViewController.m
//  BLEDemo
//
//  Created by aaron on 16/4/8.
//  Copyright © 2016年 aaron. All rights reserved.
//

#import "CentralViewController.h"
#import <CoreBluetooth/CoreBluetooth.h>
#import "Header.h"

@interface CentralViewController ()<CBCentralManagerDelegate,CBPeripheralDelegate>


@property (nonatomic, strong) CBCentralManager *centralManager; //中心管理者
@property (nonatomic, strong) NSMutableArray *peripherals; //连接的外围设备
@property (nonatomic, strong) CBCharacteristic *curCharacter; //当前服务的特征
@property (nonatomic, strong) CBPeripheral *curPeripherals;

@property (weak, nonatomic) IBOutlet UITextView *logText;

@end

@implementation CentralViewController

#pragma mark - life cycle

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    _centralManager = [[CBCentralManager alloc] initWithDelegate:self queue:nil];
    _peripherals = [NSMutableArray array];
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

- (void)centralManagerDidUpdateState:(CBCentralManager *)central{
    
    switch (central.state) {
        case CBCentralManagerStatePoweredOn:
            [self writeToLogWithText:@"中心设备已打开"];
            [central scanForPeripheralsWithServices:nil options:nil];
            break;
            
        default:
            [self writeToLogWithText:@"此设备不支持BLE或未打开蓝牙功能"];
            break;
    }
}

- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary<NSString *,id> *)advertisementData RSSI:(NSNumber *)RSSI{
    
    [self writeToLogWithText:[NSString stringWithFormat:@"发现外围设备:%@",peripheral]];
//    [_centralManager stopScan];
    if ([peripheral.name hasPrefix:@"iP"]|| [peripheral.name hasPrefix:@"aaron"]) {
        if (![_peripherals containsObject:peripheral]) {
            [_peripherals addObject:peripheral];
        }
        [self writeToLogWithText:[NSString stringWithFormat:@"开始连接外围设备--%@",peripheral]];
        [_centralManager connectPeripheral:peripheral options:nil];
    }
}

- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral{

    [self writeToLogWithText:@"连接设备成功"];
    peripheral.delegate = self;
    
    //外围设备开始寻找服务
    [peripheral discoverServices:nil];
}

#pragma mark - CBPeripheralDelegate

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error{
    
    [self writeToLogWithText:@"已发现可用服务"];
    for (CBService *service in peripheral.services) {
        //外围设备查找指定服务中的特征
        [peripheral discoverCharacteristics:nil forService:service];
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
        if (characteristic.properties & CBCharacteristicPropertyNotify) {
            if ([characteristic.UUID.UUIDString isEqualToString:kNotifyUUID] || [characteristic.UUID.UUIDString isEqualToString:kWriteUUID]) {
                _curCharacter = characteristic;
                [peripheral setNotifyValue:YES forCharacteristic:characteristic];
                [self writeToLogWithText:@"已订阅特征通知"];
            }
        }
        
        //情景二：写数据
        if (characteristic.properties & CBCharacteristicPropertyWrite) {
            if ([characteristic.UUID.UUIDString isEqualToString:kWriteUUID]) {
                [peripheral writeValue:[@"hello,外设" dataUsingEncoding:NSUTF8StringEncoding] forCharacteristic:characteristic type:CBCharacteristicWriteWithResponse];
                [self writeToLogWithText:@"写数据给外设"];
                _curPeripherals = peripheral;
                _curCharacter = characteristic;
            }
        }
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didUpdateNotificationStateForCharacteristic:(nonnull CBCharacteristic *)characteristic error:(nullable NSError *)error{
    
    NSString *value=[[NSString alloc]initWithData:characteristic.value encoding:NSUTF8StringEncoding];
    [self writeToLogWithText:[NSString stringWithFormat:@"读取到更新后通知：%@",value]];
}

- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(nonnull CBCharacteristic *)characteristic error:(nullable NSError *)error{
    
    NSString *value=[[NSString alloc]initWithData:characteristic.value encoding:NSUTF8StringEncoding];
    [self writeToLogWithText:[NSString stringWithFormat:@"读取特征值：%@",value]];
}

- (void)peripheral:(CBPeripheral *)peripheral didWriteValueForCharacteristic:(nonnull CBCharacteristic *)characteristic error:(nullable NSError *)error{
    
    NSString *value=[[NSString alloc]initWithData:characteristic.value encoding:NSUTF8StringEncoding];
    [self writeToLogWithText:[NSString stringWithFormat:@"读取写更新特征值：%@",value]];
}

@end
