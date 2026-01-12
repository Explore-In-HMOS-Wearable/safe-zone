import { ble } from '@kit.ConnectivityKit';
import { BusinessError } from '@kit.BasicServicesKit';

const TAG: string = 'BleAdvertisingManager';

export class BleAdvertisingManager {
  private advHandle: number = 0xFF;

  // 1. Define the BLE advertising status reporting event.
  onReceiveEvent = (data: ble.AdvertisingStateChangeInfo) => {
    AppStorage.setOrCreate('advertiserState', data.state);
  };

  // 2. Start BLE advertising for the first time.
  public async startAdvertising() {
    let setting: ble.AdvertiseSetting = {
      interval: 1000,
      txPower: 0,
      connectable: true
    };

    let manufactureValueBuffer = new Uint8Array(4);
    manufactureValueBuffer[0] = 1;
    manufactureValueBuffer[1] = 2;
    manufactureValueBuffer[2] = 3;
    manufactureValueBuffer[3] = 4;

    let serviceValueBuffer = new Uint8Array(4);
    serviceValueBuffer[0] = 5;
    serviceValueBuffer[1] = 6;
    serviceValueBuffer[2] = 7;
    serviceValueBuffer[3] = 8;

    let manufactureDataUnit: ble.ManufactureData = {
      manufactureId: 4567,
      manufactureValue: manufactureValueBuffer.buffer
    };

    let serviceDataUnit1: ble.ServiceData = {
      serviceUuid: '00001999-0000-1000-8000-00805f9b34fb',
      serviceValue: serviceValueBuffer.buffer
    };
    let serviceDataUnit2: ble.ServiceData = {
      serviceUuid: '19991999-0000-1000-8000-00805f9b34fb',
      serviceValue: serviceValueBuffer.buffer
    };

    let advData: ble.AdvertiseData = {
      serviceUuids: ['00001888-0000-1000-8000-00805f9b34fb', '18881888-0000-1000-8000-00805f9b34fb'],
      manufactureData: [manufactureDataUnit],
      serviceData: [],
      includeDeviceName: false
    };

    let advResponse: ble.AdvertiseData = {
      serviceUuids: [],
      manufactureData: [],
      serviceData: [serviceDataUnit1, serviceDataUnit2]
    };

    let advertisingParams: ble.AdvertisingParams = {
      advertisingSettings: setting,
      advertisingData: advData,
      advertisingResponse: advResponse,
      duration: 0
    }

    try {
      ble.on('advertisingStateChange', this.onReceiveEvent);
      this.advHandle = await ble.startAdvertising(advertisingParams);
    } catch (err) {
      console.error(TAG, `errCode: ${(err as BusinessError).code}, errMessage: ${(err as BusinessError).message}`);
    }
  }

  // 3. Disable the BLE advertising with the specified ID
  public async disableAdvertising() {
    let advertisingDisableParams: ble.AdvertisingDisableParams = {
      advertisingId: this.advHandle
    }
    try {
      await ble.disableAdvertising(advertisingDisableParams);
    } catch (err) {
      console.error(TAG, `errCode: ${(err as BusinessError).code}, errMessage: ${(err as BusinessError).message}`);
    }
  }

  // 4. Enable the BLE advertising with the specified ID
  public async enableAdvertising(enableDuration: number) {
    let advertisingEnableParams: ble.AdvertisingEnableParams = {
      advertisingId: this.advHandle,
      duration: enableDuration
    }
    try {
      await ble.enableAdvertising(advertisingEnableParams);
    } catch (err) {
      console.error(TAG, `errCode: ${(err as BusinessError).code}, errMessage: ${(err as BusinessError).message}`);
    }
  }

  // 5. Stop BLE advertising to release related resources.
  public async stopAdvertising() {
    try {
      await ble.stopAdvertising(this.advHandle);
      ble.off('advertisingStateChange', this.onReceiveEvent);
      console.info(TAG, 'stopAdvertising success');
    } catch (err) {
      console.error(TAG, `errCode: ${(err as BusinessError).code}, errMessage: ${(err as BusinessError).message}`);
    }
  }
}

let bleAdvertisingManager = new BleAdvertisingManager();
export default bleAdvertisingManager as BleAdvertisingManager;
