# SideKick

**Twitch + Kick multistream for OBS.** Stream to **Twitch and Kick at the same time** from a single OBS Studio instance, with no extra encoding load and no third-party relay service.

![OBS Studio 30+](https://img.shields.io/badge/OBS%20Studio-30%2B-302E31?logo=obsstudio&logoColor=white)
![Lua](https://img.shields.io/badge/Lua-script-2C2D72?logo=lua&logoColor=white)
![Platforms](https://img.shields.io/badge/platform-Windows%20%7C%20macOS%20%7C%20Linux-lightgrey)
![License: MIT](https://img.shields.io/badge/license-MIT-green)

## Features

- **One click, two platforms.** Start streaming in OBS as usual and Kick goes live alongside Twitch.
- **No extra CPU/GPU load.** Kick reuses the encoders of your main stream, so both platforms get identical quality.
- **Starts and stops with your stream.** No separate buttons to remember.
- **Self-healing connection.** If Kick drops, OBS reconnects automatically. If that fails, the script restarts only the Kick output and your Twitch stream keeps running.
- **Manual controls.** Start, stop and check the status of Kick from the script settings.
- **Zero setup.** A single Lua file: nothing to compile, no dependencies, works on Windows, macOS and Linux.

## How it works

```
                          ┌──▶  Main stream output  ──▶  Twitch
 Scenes ──▶ OBS encoder ──┤
                          └──▶  Script output (RTMPS) ──▶  Kick
```

Your main OBS stream goes to Twitch as usual. When it starts, the script creates a second RTMPS output that is attached to the same video and audio encoders and sends it to Kick. Encoding happens once; only the upload is doubled.

## Requirements

- OBS Studio 30 or newer
- A Kick account and your Kick **Server URL** and **Stream Key**
- Enough upload bandwidth for two streams (roughly 2× your bitrate, e.g. 12–15 Mbps for a 6000 kbps stream)

## Installation

1. **Download** [`sidekick.lua`](sidekick.lua) and save it in a permanent folder (OBS loads it from that path every time it starts).
2. **Set up Twitch** in OBS: **Settings → Stream**, choose **Twitch** and connect your account or paste your stream key.
3. **Add the script:** **Tools → Scripts**, click **+** and select `sidekick.lua`.
4. **Paste your Kick credentials:** on [dashboard.kick.com](https://dashboard.kick.com), go to **Channel → Stream URL and Key**, then copy the Server URL and Stream Key into the script settings.
5. **Go live:** click **Start Streaming**. Kick connects a few seconds after Twitch.

To confirm Kick is live, open **Tools → Scripts → Script Log** and look for `[kick] live`.

## Settings

| Option | Description |
| --- | --- |
| Stream to Kick when I start streaming | Starts Kick automatically together with your main stream. |
| Kick server URL | The RTMPS ingest URL from your Kick dashboard. |
| Kick stream key | Your Kick stream key. It is stored in your OBS settings, never in the script file. |
| Auto restart if Kick disconnects | After OBS's own reconnect attempts fail, restarts the Kick output (up to 10 times in a row). |
| Start Kick / Stop Kick | Control Kick manually while your main stream is running. |
| Show status in log | Writes the current state, data sent and dropped frames to the Script Log. |

## Recommended output settings

Both platforms receive the same encoded stream, so pick settings that work for both:

| Setting | Value |
| --- | --- |
| Encoder | H.264 (x264, NVENC H.264, AMD AMF H.264 or QuickSync H.264) |
| Rate control | CBR |
| Bitrate | 6000 kbps |
| Keyframe interval | 2 s |
| Resolution / FPS | Up to 1080p60 |
| Audio | AAC, 160 kbps |

Disable **Enhanced Broadcasting** in **Settings → Stream** (Twitch). It can switch the main stream to other codecs or several encoders, which Kick does not expect.

## Troubleshooting

All messages from the script appear in **Tools → Scripts → Script Log**.

| Message | What to do |
| --- | --- |
| `server url or stream key is empty` | Fill in both fields in the script settings. |
| `restarting X/10` or `giving up` | Copy the server URL and stream key from the Kick dashboard again (reset the key if needed), then click **Start Kick**. Make sure the URL starts with `rtmps://`. |
| `main stream is using hevc` (or `av1`) | Switch your stream encoder to H.264 and disable Enhanced Broadcasting. |
| Dropped frames in `Show status in log` | Your upload can't keep up with two streams. Lower the bitrate. |

## Known limitations

- **Same quality on both platforms.** Kick uses the main stream's bitrate and resolution; per-platform settings are not supported.
- **Stream Delay is not applied to Kick.** If you use OBS's Stream Delay (Settings → Advanced), only the main stream is delayed.
- **One extra destination.** The script adds Kick only. For more destinations, see [Multiple RTMP Output](https://github.com/sorayuki/obs-multi-rtmp).

## Platform rules

Twitch allows simulcasting to other platforms unless you have an exclusivity agreement with Twitch. Its guidelines also ask that your Twitch stream is not lower quality than your other streams (guaranteed here, since both use the same encoder) and that you don't send Twitch viewers to your streams elsewhere. Rules change, so check the current Twitch and Kick guidelines before going live.

## License

[MIT](LICENSE)

This project is not affiliated with or endorsed by Twitch, Kick or the OBS Project.
