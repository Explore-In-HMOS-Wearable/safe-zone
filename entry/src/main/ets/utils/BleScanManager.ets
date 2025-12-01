import { ble } from '@kit.ConnectivityKit';
import { BusinessError } from '@ohos.base';

const TAG: string = 'BleScanManager';

// See Core Assigned Numbers in Bluetooth Core Specification.
const BLE_ADV_TYPE_FLAG = 0x01;
const BLE_ADV_TYPE_16_BIT_SERVICE_UUIDS_INCOMPLETE = 0x02;
const BLE_ADV_TYPE_16_BIT_SERVICE_UUIDS_COMPLETE = 0x03;
const BLE_ADV_TYPE_32_BIT_SERVICE_UUIDS_INCOMPLETE = 0x04;
const BLE_ADV_TYPE_32_BIT_SERVICE_UUIDS_COMPLETE = 0x05;
const BLE_ADV_TYPE_128_BIT_SERVICE_UUIDS_INCOMPLETE = 0x06;
const BLE_ADV_TYPE_128_BIT_SERVICE_UUIDS_COMPLETE = 0x07;
const BLE_ADV_TYPE_LOCAL_NAME_SHORT = 0x08;
const BLE_ADV_TYPE_LOCAL_NAME_COMPLETE = 0x09;
const BLE_ADV_TYPE_TX_POWER_LEVEL = 0x0A;
const BLE_ADV_TYPE_16_BIT_SERVICE_SOLICITATION_UUIDS = 0x14;
const BLE_ADV_TYPE_128_BIT_SERVICE_SOLICITATION_UUIDS = 0x15;
const BLE_ADV_TYPE_32_BIT_SERVICE_SOLICITATION_UUIDS = 0x1F;
const BLE_ADV_TYPE_16_BIT_SERVICE_DATA = 0x16;
const BLE_ADV_TYPE_32_BIT_SERVICE_DATA = 0x20;
const BLE_ADV_TYPE_128_BIT_SERVICE_DATA = 0x21;
const BLE_ADV_TYPE_MANUFACTURER_SPECIFIC_DATA = 0xFF;

const BLUETOOTH_UUID_16_BIT_LENGTH = 2;
const BLUETOOTH_UUID_32_BIT_LENGTH = 4;
const BLUETOOTH_UUID_128_BIT_LENGTH = 16;

const BLUETOOTH_MANUFACTURE_ID_LENGTH = 2;

interface BleScanResultWithTxPower extends ble.ScanResult {
  txPower?: number;
}

// For the UI to subscribe to distance updates
export type DistanceUpdateCallback = (distance: number, deviceName?: string) => void;

export class BleScanManager {
  bleScanner: ble.BleScanner = ble.createBleScanner();

  public onDistanceUpdate?: DistanceUpdateCallback;

  // 1. Define the callback for scan result reporting events.
  onReceiveEvent = (scanReport: ble.ScanReport) => {
    console.info(TAG, `BLE scan device find result: ${JSON.stringify(scanReport)}`);
    if (scanReport.scanResult.length === 0) {
      return;
    }

    // For simplicity, we take the first result that matches our filter.
    const result = scanReport.scanResult[0];

    console.info(TAG, `BLE scan result: ${result.deviceId}`);

    // Parse advertising payload as before
    this.parseScanResult(result.data);


    // Try to get an approximate distance from RSSI
    const rssi: number = result.rssi; // Adjust property name if your SDK differs
    const extendedResult = result as BleScanResultWithTxPower;
    const txPower = extendedResult.txPower ?? -59;

    const distance = this.estimateDistanceFromRssi(rssi, txPower);
    const deviceLabel: string = result.deviceName ?? result.deviceId ?? '';

    console.info(TAG, `Estimated distance: ${distance.toFixed(2)} m, device: ${deviceLabel}`);

    if (this.onDistanceUpdate) {
      this.onDistanceUpdate(distance, deviceLabel);
    }
  };

  /**
   * Rough RSSI -> distance estimation.
   * You can tune txPower & n based on real measurements.
   */
  private estimateDistanceFromRssi(rssi: number, txPower: number = -59): number {
    if (rssi === 0) {
      return 10; // unknown
    }

    // Path loss exponent (2 ~ 4). 2 for free space, higher for indoor.
    const n = 2.0;

    const ratioDb = txPower - rssi;
    const ratioLinear = ratioDb / (10 * n);
    const distance = Math.pow(10, ratioLinear);

    // Clamp to 0.1 - 10 m for UI
    return Math.max(0.1, Math.min(10, distance));
  }

  public parseScanResult(data: ArrayBuffer) {
    let advData = new Uint8Array(data);
    if (advData.byteLength == 0) {
      console.warn(TAG, 'adv data length is 0');
      return;
    }

    let advertiseFlags: number = -1;
    let txPowerLevel: number = -1;
    let localName: string = '';
    let serviceUuids: string[] = [];
    let serviceSolicitationUuids: string[] = [];
    let manufactureSpecificDatas: Record<number, Uint8Array> = {};
    let serviceDatas: Record<string, Uint8Array> = {};

    let curPos = 0;
    while (curPos < advData.byteLength) {
      let length = advData[curPos++];
      if (length == 0) {
        break;
      }

      let advDataLength = length - 1;
      let advDataType = advData[curPos++];

      switch (advDataType) {
        case BLE_ADV_TYPE_FLAG:
          advertiseFlags = advData[curPos];
          break;
        case BLE_ADV_TYPE_LOCAL_NAME_SHORT:
        case BLE_ADV_TYPE_LOCAL_NAME_COMPLETE:
          localName = advData.slice(curPos, curPos + advDataLength).toString();
          break;
        case BLE_ADV_TYPE_TX_POWER_LEVEL:
          txPowerLevel = advData[curPos];
          break;
        case BLE_ADV_TYPE_16_BIT_SERVICE_UUIDS_INCOMPLETE:
        case BLE_ADV_TYPE_16_BIT_SERVICE_UUIDS_COMPLETE:
          this.parseServiceUuid(BLUETOOTH_UUID_16_BIT_LENGTH, curPos, advDataLength, advData, serviceUuids);
          break;
        case BLE_ADV_TYPE_32_BIT_SERVICE_UUIDS_INCOMPLETE:
        case BLE_ADV_TYPE_32_BIT_SERVICE_UUIDS_COMPLETE:
          this.parseServiceUuid(BLUETOOTH_UUID_32_BIT_LENGTH, curPos, advDataLength, advData, serviceUuids);
          break;
        case BLE_ADV_TYPE_128_BIT_SERVICE_UUIDS_INCOMPLETE:
        case BLE_ADV_TYPE_128_BIT_SERVICE_UUIDS_COMPLETE:
          this.parseServiceUuid(BLUETOOTH_UUID_128_BIT_LENGTH, curPos, advDataLength, advData, serviceUuids);
          break;
        case BLE_ADV_TYPE_16_BIT_SERVICE_SOLICITATION_UUIDS:
          this.parseServiceSolicitationUuid(
            BLUETOOTH_UUID_16_BIT_LENGTH, curPos, advDataLength, advData, serviceSolicitationUuids);
          break;
        case BLE_ADV_TYPE_32_BIT_SERVICE_SOLICITATION_UUIDS:
          this.parseServiceSolicitationUuid(
            BLUETOOTH_UUID_32_BIT_LENGTH, curPos, advDataLength, advData, serviceSolicitationUuids);
          break;
        case BLE_ADV_TYPE_128_BIT_SERVICE_SOLICITATION_UUIDS:
          this.parseServiceSolicitationUuid(
            BLUETOOTH_UUID_128_BIT_LENGTH, curPos, advDataLength, advData, serviceSolicitationUuids);
          break;
        case BLE_ADV_TYPE_16_BIT_SERVICE_DATA:
          this.parseServiceData(
            BLUETOOTH_UUID_16_BIT_LENGTH, curPos, advDataLength, advData, serviceDatas);
          break;
        case BLE_ADV_TYPE_32_BIT_SERVICE_DATA:
          this.parseServiceData(
            BLUETOOTH_UUID_32_BIT_LENGTH, curPos, advDataLength, advData, serviceDatas);
          break;
        case BLE_ADV_TYPE_128_BIT_SERVICE_DATA:
          this.parseServiceData(
            BLUETOOTH_UUID_128_BIT_LENGTH, curPos, advDataLength, advData, serviceDatas);
          break;
        case BLE_ADV_TYPE_MANUFACTURER_SPECIFIC_DATA:
          this.parseManufactureData(curPos, advDataLength, advData, manufactureSpecificDatas);
          break;
        default:
          break;
      }
      curPos += advDataLength;
    }
    console.info(TAG, `advertiseFlags: ${advertiseFlags}`)
    console.info(TAG, `txPowerLevel: ${txPowerLevel}`)
    console.info(TAG, `localName: ${localName}`)
    console.info(TAG, `serviceUuids:  ${JSON.stringify(serviceUuids)}`)
    console.info(TAG, `serviceSolicitationUuids:  ${JSON.stringify(serviceSolicitationUuids)}`)
    console.info(TAG, `manufactureSpecificDatas:  ${JSON.stringify(manufactureSpecificDatas)}`)
    console.info(TAG, `serviceDatas: ${JSON.stringify(serviceDatas)}`)
  }

  private parseServiceUuid(uuidLength: number, curPos: number, advDataLength: number,
    advData: Uint8Array, serviceUuids: string[]) {
    while (advDataLength > 0) {
      let tmpData: Uint8Array = advData.slice(curPos, curPos + uuidLength);
      serviceUuids.push(this.getUuidFromUint8Array(uuidLength, tmpData));
      advDataLength -= uuidLength;
      curPos += uuidLength;
    }
  }

  private parseServiceSolicitationUuid(uuidLength: number, curPos: number, advDataLength: number,
    advData: Uint8Array, serviceSolicitationUuids: string[]) {
    while (advDataLength > 0) {
      let tmpData: Uint8Array = advData.slice(curPos, curPos + uuidLength);
      serviceSolicitationUuids.push(this.getUuidFromUint8Array(uuidLength, tmpData));
      advDataLength -= uuidLength;
      curPos += uuidLength;
    }
  }

  private getUuidFromUint8Array(uuidLength: number, uuidData: Uint8Array): string {
    let uuid = '';
    let temp: string = '';
    for (let i = uuidLength - 1; i > -1; i--) {
      temp += uuidData[i].toString(16).padStart(2, '0');
    }
    switch (uuidLength) {
      case BLUETOOTH_UUID_16_BIT_LENGTH:
        uuid = `0000${temp}-0000-1000-8000-00805F9B34FB`;
        break;
      case BLUETOOTH_UUID_32_BIT_LENGTH:
        uuid = `${temp}-0000-1000-8000-00805F9B34FB`;
        break;
      case BLUETOOTH_UUID_128_BIT_LENGTH:
        uuid = `${temp.substring(0, 8)}-${temp.substring(8, 12)}-${temp.substring(12, 16)}-${temp.substring(16, 20)}-${temp.substring(20, 32)}`;
        break;
      default:
        break;
    }
    return uuid;
  }

  private parseServiceData(uuidLength: number, curPos: number, advDataLength: number,
    advData: Uint8Array, serviceDatas: Record<string, Uint8Array>) {
    let uuid: Uint8Array = advData.slice(curPos, curPos + uuidLength);
    let data: Uint8Array = advData.slice(curPos + uuidLength, curPos + advDataLength);
    serviceDatas[this.getUuidFromUint8Array(uuidLength, uuid)] = data;
  }

  private parseManufactureData(curPos: number, advDataLength: number,
    advData: Uint8Array, manufactureSpecificDatas: Record<number, Uint8Array>) {
    let manufactureId: number = (advData[curPos + 1] << 8) + advData[curPos];
    let data: Uint8Array = advData.slice(curPos + BLUETOOTH_MANUFACTURE_ID_LENGTH, curPos + advDataLength);
    manufactureSpecificDatas[manufactureId] = data;
  }

  // 2. Start a scan.
  public startScan() {
    let manufactureId = 4567;
    let manufactureData: Uint8Array = new Uint8Array([1, 2, 3, 4]);
    let manufactureDataMask: Uint8Array = new Uint8Array([0xFF, 0xFF, 0xFF, 0xFF]);
    let scanFilter: ble.ScanFilter = {
      manufactureId: manufactureId,
      manufactureData: manufactureData.buffer,
      manufactureDataMask: manufactureDataMask.buffer
    };

    let scanOptions: ble.ScanOptions = {
      interval: 1000,
      dutyMode: ble.ScanDuty.SCAN_MODE_LOW_POWER,
      matchMode: ble.MatchMode.MATCH_MODE_AGGRESSIVE
    }
    try {
      this.bleScanner.on('BLEDeviceFind', this.onReceiveEvent);
      this.bleScanner.startScan([scanFilter], scanOptions);
      console.info(TAG, 'startBleScan success');
    } catch (err) {
      console.error(TAG, `errCode: ${(err as BusinessError).code}, errMessage: ${(err as BusinessError).message}`);
    }
  }

  // 3. Stop the scan.
  public stopScan() {
    try {
      this.bleScanner.off('BLEDeviceFind', this.onReceiveEvent);
      this.bleScanner.stopScan();
      console.info(TAG, 'stopBleScan success');
    } catch (err) {
      console.error(TAG, `errCode: ${(err as BusinessError).code}, errMessage: ${(err as BusinessError).message}`);
    }
  }
}

let bleScanManager = new BleScanManager();
export default bleScanManager as BleScanManager;
