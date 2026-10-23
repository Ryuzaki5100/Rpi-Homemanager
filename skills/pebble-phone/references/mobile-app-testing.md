# Testing with the Pebble mobile app

The `pebble` tool runs a PKJS runtime next to the emulator, which is enough for most development.

## Emulator PKJS

```bash
pebble install --emulator emery
pebble logs --emulator emery
pebble emu-app-config     # opens the settings page in a browser
pebble send-app-message --string 1=hello --int 2=42
```

`pebble emu-app-config` opens a browser window. In a headless/agent session it
can block; run it with a timeout or verify the config page separately, then test
the watch-side inbox handler with `pebble send-app-message`.

## Real mobile app against an emulator

The Pebble mobile app can connect to a PebbleOS emulator over TCP, but only one client can use the protocol port. Use a PebbleOS emulator built from source:

```bash
pbl configure --board=qemu_emery
pbl build
pbl qemu
```

Then install from the computer while the phone is disconnected from the port:

```bash
pebble install --qemu localhost:12344
```

## Android device/emulator

```bash
adb reverse tcp:12344 tcp:12344
adb shell am broadcast -a coredevices.coreapp.ADD_QEMU_WATCH \
  -n coredevices.coreapp/coredevices.coreapp.debug.QemuSetupReceiver \
  --es host 127.0.0.1 --ei port 12344
```

Fake location for `navigator.geolocation`:

```bash
adb shell appops set com.android.shell android:mock_location allow
for p in gps fused; do
  adb shell cmd location providers add-test-provider $p
  adb shell cmd location providers set-test-provider-enabled $p true
  adb shell cmd location providers set-test-provider-location $p --location 37.4438,-122.1650
done
```

## Sideloading

Open the `.pbw` on the phone; the Pebble app registers for it and adds it to the locker as sideloaded.

## Limits

- The standard `pebble install --emulator` emulator is already attached to the CLI's PKJS runtime; use the PebbleOS emulator for mobile-app testing.
