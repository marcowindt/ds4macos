# ds4macos

## Troubleshoot

🚨 ds4macos does not work with the latest version of Dolphin at the moment. Until [the issue](https://github.com/marcowindt/ds4macos/issues/8) is fixed you should use version [5.0-14363](https://dolphin-emu.org/download/dev/a208d529de0b95c77a39b8faed9eb5b2c077347a/) or earlier of Dolphin if you want to use this application. 

## Build & Run

- Open this project in Xcode
- Make sure your Signing & Capabilities settings are correct, change the bundle identifier if needed
- Press run

## DualShock 4 Controllers

This application is designed to also have motion data available from DS4 controllers in the Dolphin emulator on MacOS.
If you aren't interested in using the accelerometer and gyro of DS4 controler(s) then this application is not needed, 
since simple button mapping works straight away with Dolphin.

Although made for DS4 controllers, it is implemented using existing libraries in MacOS.
Thus in principle other types of controllers may work as well, but need to be compatible with MacOS already and only DS4 controllers have been tested with this application.

## Dolphin

This app is made to be used with the Dolphin emulator. 
Within Dolphin you go to alternative input devices and setup the DSU client to listen to the server running on your computer with port 26760 (you can find your ip address by running something like `ifconfig` in a Terminal).

### Controller Profile

You may use the controller profile in this repository, the left thumbstick is mapped as the WiiMote's nunchunck thumbstick.

1. If using the profile from this repository place it within the Config folder of Dolhpin:
	- `/Users/username/Library/Application Support/Dolphin/Config/Profiles/Wiimote/ds4macos.ini`

Otherwise, just map it yourself it's very simple.

## Credits

A lot of this application's code was made possible by looking at an existing DSU server
implementation for Joy Con controllers at https://github.com/joaorb64/joycond-cemuhook/tree/master

Also the specification of the DSU protocol at https://v1993.github.io/cemuhook-protocol/ is of
great value

## Screenshots

<img src="https://github.com/marcowindt/ds4macos/blob/main/screenshot1.png" alt="Screenshot of the application info view"/>
<img src="https://github.com/marcowindt/ds4macos/blob/main/screenshot2.png" alt="Screenshot of the server settings"/>
<img src="https://github.com/marcowindt/ds4macos/blob/main/screenshot3.png" alt="Screenshot of the general settings"/>
