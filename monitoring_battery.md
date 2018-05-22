## バッテリーの状態を監視する方法 (iOS & Swift)

#### バッテリーの監視を開始

~~~
func startBatteryMonitoring() {
  UIDevice.current.isBatteryMonitoringEnabled = true
  // バッテリー残量の変化を監視
  NotificationCenter.default.addObserver(
    self,
    selector: #selector(MainViewController.batteryLevelChanged(notification:)),
    name: Notification.Name.UIDeviceBatteryLevelDidChange, object: nil)
  // バッテリー給電状況の変化を監視
  NotificationCenter.default.addObserver(
    self,
    selector: #selector(MainViewController.batteryStateChanged(notification:)),
    name: Notification.Name.UIDeviceBatteryStateDidChange, object: nil)
}
~~~

#### バッテリーの監視を終了

~~~
func stopBatteryMonitoring() {
  UIDevice.current.isBatteryMonitoringEnabled = false
  NotificationCenter.default.removeObserver(
    self,
    name: Notification.Name.UIDeviceBatteryLevelDidChange, object: nil)
  NotificationCenter.default.removeObserver(
    self,
    name: Notification.Name.UIDeviceBatteryStateDidChange, object: nil)
}
~~~

#### バッテリー残量の変化に対するメソッド

~~~
@objc func batteryLevelChanged(notification: Notification) {
    displayBatteryLevel()
}
~~~

#### バッテリーの給電状況の変化に対するメソッド

~~~
@objc func batteryStateChanged(notification: Notification) {
  displayBatteryState()
}
~~~
