//
//  CentralViewController.m
//  BLEDemo
//
//  Created by aaron on 16/4/8.
//  Copyright © 2016年 aaron. All rights reserved.
//

#import "CentralViewController.h"
#import <CoreBluetooth/CoreBluetooth.h>

@interface CentralViewController ()<CBCentralManagerDelegate,CBPeripheralDelegate>

@property (nonatomic, strong) CBCentralManager *centralManager; //中心管理者
@property (nonatomic, strong) NSMutableArray *peripherals; //连接的外围设备

@end

@implementation CentralViewController

#pragma mark - life cycle

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    _centralManager = [[CBCentralManager alloc] initWithDelegate:self queue:nil];
    _peripherals = [NSMutableArray array];
}


#pragma mark - CBCentralManagerDelegate

- (void)centralManagerDidUpdateState:(CBCentralManager *)central{
    
    switch (central.state) {
        case CBCentralManagerStatePoweredOn:
            NSLog(@"中心设备已打开");
            [central scanForPeripheralsWithServices:nil options:nil];
            break;
            
        default:
            NSLog(@"此设备不支持BLE或未打开蓝牙功能");
            break;
    }
}

- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary<NSString *,id> *)advertisementData RSSI:(NSNumber *)RSSI{
    NSLog(@"发现外围设备:%@",peripheral);
//    [_centralManager stopScan];
    if ([peripheral.name hasPrefix:@"12"]) {
        if (![_peripherals containsObject:peripheral]) {
            [_peripherals addObject:peripheral];
        }
        NSLog(@"开始连接外围设备--%@",peripheral);
        [_centralManager connectPeripheral:peripheral options:nil];
    }
}

- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral{
    NSLog(@"连接设备成功;%@",peripheral);
    
    peripheral.delegate = self;
    
    //外围设备开始寻找服务
    [peripheral discoverServices:nil];
}

#pragma mark - CBPeripheralDelegate

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error{
//    NSLog(@"外围设备发现services\n");
    
    for (CBService *service in peripheral.services) {
//        NSLog(@"service:%@\n",service);
        //外围设备查找指定服务中的特征
        [peripheral discoverCharacteristics:nil forService:service];
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(nonnull CBService *)service error:(nullable NSError *)error{
//    NSLog(@"外围设备查找指定服务中的特征");
    
    for (CBCharacteristic *characteristic in service.characteristics) {
//        NSLog(@"%@--%@",service,characteristic);
        
        //情景一：读取
        if (characteristic.properties & CBCharacteristicPropertyRead) {
            [peripheral readValueForCharacteristic:characteristic];
            if (characteristic.value) {
                NSString *value=[[NSString alloc]initWithData:characteristic.value encoding:NSUTF8StringEncoding];
                NSLog(@"读取到特征值：%@",value);
            }
        }

        //情景二：通知
        if (characteristic.properties & CBCharacteristicPropertyNotify) {
            [peripheral setNotifyValue:YES forCharacteristic:characteristic];
            NSLog(@"更新前通知：%@",characteristic);
        }
        
        //情景二：写数据
        if (characteristic.properties & CBCharacteristicPropertyWrite) {
            [peripheral writeValue:[@"1234" dataUsingEncoding:NSUTF8StringEncoding] forCharacteristic:characteristic type:CBCharacteristicWriteWithResponse];
            NSLog(@"写前：%@",characteristic);
        }
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didUpdateNotificationStateForCharacteristic:(nonnull CBCharacteristic *)characteristic error:(nullable NSError *)error{
//    NSLog(@"收到特征更新通知...");
    NSLog(@"更新后通知：%@",characteristic);
}

- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(nonnull CBCharacteristic *)characteristic error:(nullable NSError *)error{
    NSString *value=[[NSString alloc]initWithData:characteristic.value encoding:NSUTF8StringEncoding];
    NSLog(@"读更新后的特征值：%@",value);
}

- (void)peripheral:(CBPeripheral *)peripheral didWriteValueForCharacteristic:(nonnull CBCharacteristic *)characteristic error:(nullable NSError *)error{
    NSString *value=[[NSString alloc]initWithData:characteristic.value encoding:NSUTF8StringEncoding];
    NSLog(@"写更新后的特征值：%@",value);
}

@end
