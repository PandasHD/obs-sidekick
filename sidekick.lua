-- sidekick for obs
-- streams to kick at the same time as your main stream (twitch)
-- by PandasHD, MIT license

obs = obslua

local VERSION = "1.0.0"

-- default kick ingest, you can paste your own from the kick dashboard
local DEFAULT_SERVER = "rtmps://fa723fc1b171.global-contribute.live-video.net:443/app"

local CHECK_INTERVAL = 3000 -- ms
local CONNECT_TIMEOUT = 30 -- seconds
local MAX_RESTARTS = 10

local conf = { enabled = true, auto_restart = true, server = "", key = "" }

local output = nil
local service = nil
local should_run = false
local start_time = 0
local restarts = 0
local last_active = false
local last_reconnecting = false

local function log(msg, level)
    obs.script_log(level or obs.LOG_INFO, "[kick] " .. msg)
end

local function get_error()
    local err = output and obs.obs_output_get_last_error(output)
    if err == nil or err == "" then
        return "no details"
    end
    return err
end

local function cleanup()
    if output then
        if obs.obs_output_active(output) then
            obs.obs_output_force_stop(output)
        end
        obs.obs_output_release(output)
        output = nil
    end
    if service then
        obs.obs_service_release(service)
        service = nil
    end
    last_active = false
    last_reconnecting = false
end

local function start_kick()
    if conf.server == "" or conf.key == "" then
        log("server url or stream key is empty, set them in the script settings", obs.LOG_WARNING)
        return false
    end
    if output and obs.obs_output_active(output) then
        return true
    end
    if not obs.obs_frontend_streaming_active() then
        log("main stream isn't running, start streaming first", obs.LOG_WARNING)
        return false
    end

    local main = obs.obs_frontend_get_streaming_output()
    if not main then
        log("couldn't get the main stream output", obs.LOG_ERROR)
        return false
    end

    local venc = obs.obs_output_get_video_encoder(main)
    local aenc = obs.obs_output_get_audio_encoder(main, 0)
    if not venc or not aenc then
        obs.obs_output_release(main)
        log("main stream has no encoders", obs.LOG_ERROR)
        return false
    end

    local codec = obs.obs_encoder_get_codec(venc)
    if codec ~= "h264" then
        log("main stream is using " .. tostring(codec) .. ", kick wants h264. "
            .. "switch the encoder and turn off enhanced broadcasting", obs.LOG_WARNING)
    end

    cleanup()

    local data = obs.obs_data_create()
    obs.obs_data_set_string(data, "server", conf.server)
    obs.obs_data_set_string(data, "key", conf.key)
    service = obs.obs_service_create("rtmp_custom", "kick_service", data, nil)
    obs.obs_data_release(data)

    output = obs.obs_output_create("rtmp_output", "kick_output", nil, nil)
    if not output or not service then
        obs.obs_output_release(main)
        cleanup()
        log("failed to create the output", obs.LOG_ERROR)
        return false
    end

    -- reuse the encoders from the main stream so nothing gets encoded twice
    obs.obs_output_set_video_encoder(output, venc)
    obs.obs_output_set_audio_encoder(output, aenc, 0)
    obs.obs_output_set_service(output, service)
    obs.obs_output_set_reconnect_settings(output, 20, 5)
    obs.obs_output_release(main)

    start_time = os.time()
    if not obs.obs_output_start(output) then
        log("failed to start (" .. get_error() .. ")", obs.LOG_ERROR)
        return false
    end
    log("connecting...")
    return true
end

local function stop_kick()
    if not output then
        return
    end
    if obs.obs_output_active(output) then
        log("stopping")
    end
    -- stop it even if it's still connecting, otherwise it could go live after twitch already ended
    obs.obs_output_stop(output)
end

local function check()
    if not output then
        return
    end

    local active = obs.obs_output_active(output)
    local reconnecting = obs.obs_output_reconnecting(output)

    if reconnecting and not last_reconnecting then
        log("connection lost, reconnecting...", obs.LOG_WARNING)
    elseif last_reconnecting and not reconnecting and active then
        log("reconnected")
    end

    if active and not last_active then
        log("live")
        restarts = 0
    elseif last_active and not active and should_run then
        log("output stopped (" .. get_error() .. ")", obs.LOG_WARNING)
    end

    last_active = active
    last_reconnecting = reconnecting

    -- obs gave up reconnecting (or it never connected), try again with a fresh output
    if should_run and not active and os.time() - start_time >= CONNECT_TIMEOUT then
        if conf.auto_restart and restarts < MAX_RESTARTS and obs.obs_frontend_streaming_active() then
            restarts = restarts + 1
            log(("still not live (%s), restarting %d/%d"):format(get_error(), restarts, MAX_RESTARTS),
                obs.LOG_WARNING)
            start_kick()
        else
            log("still not live (" .. get_error() .. "), giving up. check the url and key, then hit Start Kick",
                obs.LOG_ERROR)
            should_run = false
        end
    end
end

local function on_event(event)
    if event == obs.OBS_FRONTEND_EVENT_STREAMING_STARTED then
        if conf.enabled then
            should_run = true
            restarts = 0
            start_kick()
        end
    elseif event == obs.OBS_FRONTEND_EVENT_STREAMING_STOPPING
        or event == obs.OBS_FRONTEND_EVENT_STREAMING_STOPPED then
        should_run = false
        stop_kick()
    elseif event == obs.OBS_FRONTEND_EVENT_EXIT then
        should_run = false
        cleanup()
    end
end

local function start_clicked()
    if not obs.obs_frontend_streaming_active() then
        log("start the main stream first", obs.LOG_WARNING)
        return false
    end
    should_run = true
    restarts = 0
    start_kick()
    return false
end

local function stop_clicked()
    should_run = false
    stop_kick()
    return false
end

local function status_clicked()
    if not output then
        log("not started yet")
        return false
    end

    local state = "stopped"
    if obs.obs_output_reconnecting(output) then
        state = "reconnecting"
    elseif obs.obs_output_active(output) then
        state = "live"
    end

    local frames = obs.obs_output_get_total_frames(output)
    local dropped = obs.obs_output_get_frames_dropped(output)
    local mb = obs.obs_output_get_total_bytes(output) / 1024 / 1024
    local pct = frames > 0 and dropped / frames * 100 or 0

    log(("status: %s, sent %.1f MB, dropped %d/%d frames (%.1f%%), last error: %s")
        :format(state, mb, dropped, frames, pct, get_error()))
    return false
end

function script_description()
    return "<b>SideKick</b> v" .. VERSION .. [[ by PandasHD<br>
Twitch + Kick multistream<br><br>
Streams to Kick at the same time as your main stream. Set Twitch in Settings &gt; Stream,
paste your Kick server url and stream key below and just start streaming.<br><br>
Kick uses the same encoder as the main stream, so go with H.264, CBR around 6000 kbps
and a 2s keyframe interval. Everything gets logged to the Script Log.]]
end

function script_properties()
    local props = obs.obs_properties_create()
    obs.obs_properties_add_bool(props, "enabled", "Stream to Kick when I start streaming")
    obs.obs_properties_add_text(props, "server", "Kick server URL", obs.OBS_TEXT_DEFAULT)
    obs.obs_properties_add_text(props, "key", "Kick stream key", obs.OBS_TEXT_PASSWORD)
    obs.obs_properties_add_bool(props, "auto_restart", "Auto restart if Kick disconnects")
    obs.obs_properties_add_button(props, "start_btn", "Start Kick", start_clicked)
    obs.obs_properties_add_button(props, "stop_btn", "Stop Kick", stop_clicked)
    obs.obs_properties_add_button(props, "status_btn", "Show status in log", status_clicked)
    return props
end

function script_defaults(settings)
    obs.obs_data_set_default_bool(settings, "enabled", true)
    obs.obs_data_set_default_bool(settings, "auto_restart", true)
    obs.obs_data_set_default_string(settings, "server", DEFAULT_SERVER)
end

function script_update(settings)
    conf.enabled = obs.obs_data_get_bool(settings, "enabled")
    conf.auto_restart = obs.obs_data_get_bool(settings, "auto_restart")
    -- people tend to paste the key with a space at the end
    conf.server = obs.obs_data_get_string(settings, "server"):match("^%s*(.-)%s*$")
    conf.key = obs.obs_data_get_string(settings, "key"):match("^%s*(.-)%s*$")
end

function script_load(settings)
    script_update(settings)
    obs.obs_frontend_add_event_callback(on_event)
    obs.timer_add(check, CHECK_INTERVAL)
    log("sidekick loaded (v" .. VERSION .. ")")
end

function script_unload()
    obs.timer_remove(check)
    should_run = false
    cleanup()
end
