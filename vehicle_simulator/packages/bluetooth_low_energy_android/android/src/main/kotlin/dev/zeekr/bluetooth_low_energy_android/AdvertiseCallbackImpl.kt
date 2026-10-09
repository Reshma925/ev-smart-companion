package dev.zeekr.bluetooth_low_energy_android

import android.bluetooth.le.AdvertiseCallback
import android.bluetooth.le.AdvertiseSettings
import android.util.Log

class AdvertiseCallbackImpl(manager: PeripheralManagerImpl) : AdvertiseCallback() {
    companion object {
        private const val TAG = "BluetoothLowEnergy"
    }

    private val mManager: PeripheralManagerImpl

    init {
        mManager = manager
    }

    override fun onStartSuccess(settingsInEffect: AdvertiseSettings) {
        super.onStartSuccess(settingsInEffect)
        Log.i(TAG, "Android AdvertiseCallback.onStartSuccess: settings=$settingsInEffect")
        mManager.onStartSuccess(settingsInEffect)
    }

    override fun onStartFailure(errorCode: Int) {
        super.onStartFailure(errorCode)
        Log.e(TAG, "Android AdvertiseCallback.onStartFailure: statusCode=$errorCode")
        mManager.onStartFailure(errorCode)
    }
}