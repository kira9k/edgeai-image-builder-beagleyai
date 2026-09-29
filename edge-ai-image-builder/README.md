# Edge AI image builder

This repository builds customized TI SDK images (eg [PROCESSOR-SDK-LINUX-AM67A](https://www.ti.com/tool/PROCESSOR-SDK-AM67A)) targeting Beagleboard hardware.

By default, TI SDK images target EVM boards so a few modifications must be made. Specficially:
- UBoot
- Linux kernel + `.dts` files and overlays
- [TI Vision Apps](https://software-dl.ti.com/jacinto7/esd/processor-sdk-rtos-j722s/latest/exports/docs/vision_apps/docs/user_guide/index.html) (firmware for c7x + r5f cores and Linux communication code)
- [cc33xx Wi-Fi/Bluetooth module drivers + firmware](https://www.ti.com/tool/CC33XX-SOFTWARE)

Gitlab CI on this repo builds the images and publishes to https://www.beagleboard.org/distros

## Supported boards

- [BeagleY-AI](https://www.beagleboard.org/boards/beagley-ai) - [11.00.00.08](https://www.ti.com/tool/download/PROCESSOR-SDK-LINUX-AM67A/11.00.00.08)
