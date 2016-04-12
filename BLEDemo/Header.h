//
//  Header.h
//  BLEDemo
//
//  Created by aaron on 16/4/9.
//  Copyright © 2016年 aaron. All rights reserved.
//

#ifndef Header_h
#define Header_h

#define kPeripheralName @"aaron's Device" //外围设备名称
#define kServiceUUID @"D5DC3450-27EF-4C3F-94D3-1F4AB15631FF" //服务的UUID
#define kNotifyUUID  @"6A3D4B29-123D-4F2A-12A8-D5E211411400" //特征的UUID
#define kReadUUID @"6A3D4B29-123D-4F2A-12A8-D5E211411401" //特征的UUID
#define kWriteUUID @"6A3D4B29-123D-4F2A-12A8-D5E211411402" //特征的UUID
#define kRestoreIdentifierKey @"aaron's demo"
#define k2A56 @"2A56"  //骑行相关配置数据,此数据包由手机通过 Characteristic Write 的方法传递给码表


#endif /* Header_h */
