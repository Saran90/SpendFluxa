// Asset pack module for the Gemma 3 1B int4 model.
// This module is declared as an install-time asset pack, meaning Play will
// deliver it alongside the base APK — no extra download step for users.
//
// To switch to on-demand delivery in the future (e.g. for a larger model),
// change deliveryType to "on-demand" in the AndroidManifest.xml.
plugins {
    id("com.android.asset-pack")
}

assetPack {
    packName = "model_delivery"
    dynamicDelivery {
        deliveryType = "install-time"
    }
}
