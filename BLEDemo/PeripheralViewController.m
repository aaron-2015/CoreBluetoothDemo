//
//  PeripheralViewController.m
//  BLEDemo
//
//  Created by aaron on 16/4/8.
//  Copyright © 2016年 aaron. All rights reserved.
//

#import "PeripheralViewController.h"
#import <CoreBluetooth/CoreBluetooth.h>
#import "Header.h"


@interface PeripheralViewController ()<CBPeripheralManagerDelegate>
@property (strong, nonatomic) CBPeripheralManager *peripheralManager;  //外围设备管理器
@property (strong, nonatomic) NSMutableArray *centralList;             //订阅此外围设备特征的中心设备
@property (strong, nonatomic) CBMutableCharacteristic *characteristic; //特征
@property (strong, nonatomic) CBMutableService *service;               //服务

@property (weak, nonatomic) IBOutlet UITextView *logText;

@end

@implementation PeripheralViewController

#pragma mark - life cycle

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
}

#pragma mark - acton

- (IBAction)start:(UIButton *)sender {
    
    NSLog(@"启动外设");
    
    if (_peripheralManager == nil) {
        _peripheralManager = [[CBPeripheralManager alloc] initWithDelegate:self queue:nil];
        _centralList = [NSMutableArray array];
    }
    
}

- (IBAction)update:(UIButton *)sender {
    
    NSLog(@"更新特征值");
    [self updataCharacteristic];
}

- (void)writeToLogWithText:(NSString *)text{
    
    NSLog(@"%@",text);
    self.logText.text = [NSString stringWithFormat:@"%@\n%@",self.logText.text,text];
}

#pragma mark - CBPeripheralManagerDelegate

- (void)peripheralManagerDidUpdateState:(CBPeripheralManager *)peripheral{
    

    switch (peripheral.state) {
        case CBPeripheralManagerStatePoweredOn:
            [self writeToLogWithText:@"外围设备BLE已打开"];
            
            [self setupService];
            break;
            
        default:
            [self writeToLogWithText:@"此设备不支持BLE或未打开蓝牙功能，无法作为外围设备"];
            break;
    }
}

- (void)peripheralManager:(CBPeripheralManager *)peripheral didAddService:(CBService *)service error:(nullable NSError *)error{
    
    NSDictionary *dict = @{CBAdvertisementDataLocalNameKey:kPeripheralName};
    [_peripheralManager startAdvertising:dict];
    [self writeToLogWithText:@"向外围设备添加了服务"];
}

- (void)peripheralManagerDidStartAdvertising:(CBPeripheralManager *)peripheral error:(nullable NSError *)error{
 
    [self writeToLogWithText:@"启动广播..."];
}


//订阅特征
- (void)peripheralManager:(CBPeripheralManager *)peripheral central:(CBCentral *)central didSubscribeToCharacteristic:(CBCharacteristic *)characteristic{
    
    [self writeToLogWithText:[NSString stringWithFormat:@"中心设备：%@ 已订阅特征：%@.",central.identifier.UUIDString,characteristic.UUID]];
    if (![_centralList containsObject:central]) {
        [_centralList addObject:central];
    }
    
}

//取消订阅
- (void)peripheralManager:(CBPeripheralManager *)peripheral central:(CBCentral *)central didUnsubscribeFromCharacteristic:(CBCharacteristic *)characteristic{
 
    [self writeToLogWithText:[NSString stringWithFormat:@"中心设备：%@ 已取消订阅特征：%@.",central.identifier.UUIDString,characteristic.UUID]];
}

- (void)peripheralManager:(CBPeripheralManager *)peripheral didReceiveReadRequest:(CBATTRequest *)request{
    
    [self writeToLogWithText:@"中心设备读外设数据"];
    [self writeToLogWithText:[[NSString alloc] initWithData:request.value encoding:NSUTF8StringEncoding]];
}

-(void)peripheralManager:(CBPeripheralManager *)peripheral willRestoreState:(NSDictionary *)dict{
    
    [self writeToLogWithText:@"willRestoreState"];
}

- (void)peripheralManager:(CBPeripheralManager *)peripheral didReceiveWriteRequests:(NSArray<CBATTRequest *> *)requests{
    
    [self writeToLogWithText:@"收到中心写来的数据"];
    CBATTRequest *request = requests.lastObject;
    [self writeToLogWithText:[[NSString alloc] initWithData:request.value encoding:NSUTF8StringEncoding]];
    [peripheral respondToRequest:request withResult:CBATTErrorSuccess];
    
}


#pragma mark - private method

//创建服务,特征并添加服务到外围设备
- (void)setupService{
    
    //可通知的特征
//    CBUUID *characteristicUUID = [CBUUID UUIDWithString:kNotifyUUID];
//    _characteristic = [[CBMutableCharacteristic alloc] initWithType:characteristicUUID properties:CBCharacteristicPropertyNotify value:nil permissions:CBAttributePermissionsReadable];
    
    //可读写的特征
    CBUUID *UUID2 = [CBUUID UUIDWithString:kWriteUUID];
    _characteristic = [[CBMutableCharacteristic alloc] initWithType:UUID2 properties:CBCharacteristicPropertyWrite|CBCharacteristicPropertyNotify value:nil permissions:CBAttributePermissionsWriteEncryptionRequired];
//
    //只读的特征
//    CBUUID *UUID3 = [CBUUID UUIDWithString:kReadUUID];
//    NSData *characteristicValue = [@"aaron才" dataUsingEncoding:NSUTF8StringEncoding];
//    _characteristic = [[CBMutableCharacteristic alloc] initWithType:UUID3 properties:CBCharacteristicPropertyRead value:characteristicValue permissions:CBAttributePermissionsReadable];
    
    CBUUID *serviceUUID = [CBUUID UUIDWithString:kServiceUUID];
    _service = [[CBMutableService alloc] initWithType:serviceUUID primary:YES];
    [_service setCharacteristics:@[_characteristic]];
    
    [_peripheralManager addService:_service];
    
    
}

- (void)updataCharacteristic{
    
    NSString *valueStr = [NSString stringWithFormat:@"%@: %@",kPeripheralName,[NSDate date]];
    NSData *data = [valueStr dataUsingEncoding:NSUTF8StringEncoding];
    [_peripheralManager updateValue:data forCharacteristic:_characteristic onSubscribedCentrals:nil];
    
    [self writeToLogWithText:[NSString stringWithFormat:@"更新特征值:%@",valueStr]];
}

@end
