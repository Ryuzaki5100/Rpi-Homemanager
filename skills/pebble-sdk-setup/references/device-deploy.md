# Deploying to a real Pebble

## Login

```bash
pebble login
pebble login --status
```

Use the same Pebble account as the Pebble mobile app.

## CloudPebble (recommended, any network)

In the mobile app: **Devices → three-dot menu → enable Dev Connection**.

```bash
pebble install --cloudpebble
pebble logs --cloudpebble
```

## LAN connection

Enable the LAN connection in the mobile app and use the shown IP:

```bash
pebble install --phone 192.168.1.42
pebble logs --phone 192.168.1.42
```

Only one of `PEBBLE_CLOUDPEBBLE` and `PEBBLE_PHONE` should be set.

## USB/serial

```bash
pebble install --serial /dev/cu.PebbleTimeXXXX-SerialPo
```

## Sideloading a PBW

- Android: open the `.pbw` file; the Pebble app registers for `.pbw`.
- iOS: open from Files/Mail/AirDrop; it appears in the locker as sideloaded.

## Notes

- `pebble publish` requires `pebble login`; it is not a deployment command.
- For the emulator, use `pebble install --emulator emery` instead.
