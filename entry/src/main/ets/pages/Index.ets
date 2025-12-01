import { requestPermission } from '../utils/RequestPermission';
import { common } from '@kit.AbilityKit';
import bleScanManager from '../utils/BleScanManager';
import bleAdvertisingManager from '../utils/BleAdvertisingManager';

const DANGER_THRESHOLD: number = 1.0;
const WARNING_THRESHOLD: number = 3.0;

/**
 * Defines the parameters for the continuous pulsing animation.
 */
const pulseAnimationOptions: AnimateParam = {
  duration: 1000,
  iterations: -1, // Infinite loop
  playMode: PlayMode.Alternate,
  tempo: 1.0,
};

@Entry
@Component
struct SafeZoneApp {
  // --- State Variables ---
  @State currentDistance: number = 10.0; // Distance in meters
  @State statusText: ResourceStr = $r('app.string.index_scanning')
  @State dialColor: Resource = $r('app.color.COLOR_SAFE');
  @State isDanger: boolean = false;
  @State targetName: ResourceStr = $r('app.string.target_name');
  @State glowScale: number = 1.0;
  @State isAdvertising: boolean = false;
  @State isScanning: boolean = false;

  private scanInterval: number = -1;
  private uiContext = this.getUIContext();


  updateProximityStatus(distance: number, deviceLabel?: string) {
    this.currentDistance = distance;

    let newStatus: ResourceStr;
    let newColor: Resource;
    this.isDanger = false;

    if (distance <= DANGER_THRESHOLD) {
      newStatus = $r('app.string.danger');
      newColor = $r('app.color.COLOR_DANGER');
      this.isDanger = true;
    } else if (distance <= WARNING_THRESHOLD) {
      newStatus = $r('app.string.warning');
      newColor = $r('app.color.COLOR_WARNING');
    } else {
      newStatus = $r('app.string.safe_zone');
      newColor = $r('app.color.COLOR_SAFE');
    }

    this.statusText = newStatus;
    this.dialColor = newColor;

    // Update target name when we have a device
    if (deviceLabel) {
      this.targetName = `Connected to ${deviceLabel}`;
    } else if (this.currentDistance <= 10.0 && !this.targetName.toString().includes('Connected')) {
      this.targetName = $r('app.string.connected_message');
    }
  }

  /**
   * Start real BLE scanning.
   */
  private startBleScan() {
    // Hook UI to scan manager via callback
    bleScanManager.onDistanceUpdate = (distance: number, deviceName?: string) => {
      this.updateProximityStatus(distance, deviceName);
    };

    bleScanManager.startScan();
    this.isScanning = true;
    this.statusText = $r('app.string.index_scanning');
    this.targetName = $r('app.string.target_name');
  }

  /**
   * Stop BLE scanning.
   */
  private stopBleScan() {
    bleScanManager.onDistanceUpdate = undefined;
    bleScanManager.stopScan();
    this.isScanning = false;
  }

  async aboutToAppear() {
    const realContext = this.uiContext.getHostContext();
    await requestPermission(['ohos.permission.ACCESS_BLUETOOTH'], realContext as common.UIAbilityContext);

    this.startBleScan();
    this.toggleAdvertising();

  }

  aboutToDisappear() {
    // Clean up simulated interval
    if (this.scanInterval !== -1) {
      clearInterval(this.scanInterval);
    }
    if (this.isScanning) {
      this.stopBleScan();
    }
    if (this.isAdvertising) {
      bleAdvertisingManager.stopAdvertising();
      this.isAdvertising = false;
    }
  }

  /**
   * Toggle BLE advertising from UI (so one device can both scan & advertise if needed).
   */
  private async toggleAdvertising() {
    if (!this.isAdvertising) {
      await bleAdvertisingManager.startAdvertising();
      this.isAdvertising = true;
    } else {
      await bleAdvertisingManager.stopAdvertising();
      this.isAdvertising = false;
    }
  }

  build() {
    Flex({ direction: FlexDirection.Column, alignItems: ItemAlign.Center, justifyContent: FlexAlign.Center }) {

      Text(this.targetName)
        .fontSize(14)
        .fontColor(Color.Gray)
        .margin({ top: 10 })

      Stack({ alignContent: Alignment.Center }) {

        Circle()
          .width(250)
          .height(250)
          .opacity(0.3)
          .fill(this.dialColor)
          .scale({ x: this.glowScale, y: this.glowScale })
          .shadow({
            radius: 40,
            color: this.isDanger ? this.dialColor : Color.Transparent,
            offsetX: 0,
            offsetY: 0
          })
          .animation({ duration: 300, curve: Curve.EaseOut })

        Column({ space: 10 }) {
          Text(`${this.currentDistance.toFixed(1)} M`)
            .fontSize(64)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.COLOR_TEXT_DEFAULT'))
            .lineHeight(64)

          Text(this.statusText)
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.dialColor)
            .letterSpacing(1.5)
            .textCase(TextCase.UpperCase)
        }

      }
      .margin({ top: 40, bottom: 40 })

      Column({ space: 8 }) {
        Text(this.isScanning ? $r('app.string.scan_message') : $r('app.string.scan_stopped'))
          .fontSize(12)
          .fontColor(Color.Gray)
          .opacity(0.7)


        .margin({ top: 10 })
      }

    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.COLOR_TEXT_DEFAULT'))
    .padding(30)
  }
}
