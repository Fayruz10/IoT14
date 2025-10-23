#![no_std]
#![no_main]

extern crate alloc;
use alloc::string::String;
use core::ffi::c_void;

use esp_idf_sys as sys;
use esp_idf_svc::log::*;
use esp_idf_svc::mqtt::client::{MqttClient, MqttClientConfiguration, QoS, MqttEvent};
use esp_idf_svc::netif::*;
use esp_idf_svc::nvs::*;
use esp_idf_svc::wifi::*;
use esp_idf_svc::eventloop::*;
use esp_idf_svc::system::EspSystem;
use esp_idf_svc::sntp::EspSntp;

use serde_json::Value;
use log::{info, warn, error};

use embedded_svc::mqtt::client::ConnState;

// heap allocator
#[global_allocator]
static ALLOC: esp_idf_svc::alloc::EspHeap = esp_idf_svc::alloc::EspHeap::empty();

/// Wrapper untuk esp_https_ota()
fn esp_https_ota_via_url(url: &str) -> Result<(), String> {
    use core::ffi::CString;
    unsafe {
        let c_url = CString::new(url).map_err(|_| "Invalid URL".to_string())?;

        let mut http_cfg: sys::esp_http_client_config_t = core::mem::zeroed();
        http_cfg.url = c_url.as_ptr() as *const i8;

        let mut ota_cfg: sys::esp_https_ota_config_t = core::mem::zeroed();
        ota_cfg.http_config = http_cfg;

        let ret = sys::esp_https_ota(&ota_cfg as *const _ as *mut _);
        if ret == sys::esp_err_t::ESP_OK {
            Ok(())
        } else {
            Err(format!("esp_https_ota failed: {:?}", ret))
        }
    }
}

/// Jalankan OTA dan reboot jika berhasil
fn perform_ota_from_url(url: &str, client: &mut MqttClient) -> Result<(), String> {
    info!("Starting OTA from URL: {}", url);

    // publish status ke ThingsBoard
    let _ = client.publish(
        "v1/devices/me/attributes",
        QoS::AtMostOnce,
        false,
        r#"{"fw_state":"DOWNLOADING"}"#.as_bytes(),
    );

    match esp_https_ota_via_url(url) {
        Ok(()) => {
            info!("OTA finished successfully.");
            let _ = client.publish(
                "v1/devices/me/attributes",
                QoS::AtMostOnce,
                false,
                r#"{"fw_state":"UPDATED"}"#.as_bytes(),
            );
            unsafe { sys::esp_restart() };
            Ok(())
        }
        Err(e) => {
            error!("OTA failed: {}", e);
            let msg = format!(r#"{{"fw_state":"FAILED","fw_message":"{}"}}"#, e);
            let _ = client.publish("v1/devices/me/attributes", QoS::AtMostOnce, false, msg.as_bytes());
            Err(e)
        }
    }
}

#[no_mangle]
pub extern "C" fn app_main() {
    esp_idf_svc::log::EspLogger::initialize_default();
    info!("Starting ThingsBoard OTA client (ESP32-S3, Rust).");

    unsafe { ALLOC.init() };

    let default_nvs = EspDefaultNvs::new().expect("NVS init failed");
    let sys_loop = EspSystemEventLoop::take().expect("event loop failed");

    // === WiFi ===
    let ssid = option_env!("WIFI_SSID").unwrap_or("YOUR_SSID");
    let pass = option_env!("WIFI_PASS").unwrap_or("YOUR_PASS");

    let mut wifi = EspWifi::new(EspNetif::new().unwrap(), sys_loop.clone(), None).unwrap();
    let wifi_cfg = embedded_svc::wifi::ClientConfiguration {
        ssid: ssid.into(),
        password: pass.into(),
        ..Default::default()
    };

    wifi.set_configuration(&wifi_cfg).unwrap();
    wifi.start().unwrap();
    wifi.connect().unwrap();

    let mut tries = 0;
    while !wifi.is_connected() && tries < 30 {
        info!("Waiting for WiFi...");
        std::thread::sleep(std::time::Duration::from_secs(1));
        tries += 1;
    }
    if !wifi.is_connected() {
        error!("WiFi connect failed, aborting.");
        return;
    }
    info!("WiFi connected.");

    // SNTP (buat TLS valid)
    let _sntp = EspSntp::new_default();

    // === MQTT ThingsBoard ===
    let tb_host = option_env!("TB_HOST").unwrap_or("mqtt.thingsboard.cloud");
    let tb_port = 8883;
    let token = option_env!("TB_TOKEN").unwrap_or("YOUR_TB_TOKEN");
    let broker = format!("ssl://{}:{}", tb_host, tb_port);

    let mut mqtt_cfg = MqttClientConfiguration::default();
    mqtt_cfg.set_client_id("tb-rust-esp32s3");
    mqtt_cfg.set_username(Some(token.into()));
    mqtt_cfg.set_keep_alive(30);

    let (mut client, mut event_loop) =
        MqttClient::new(&broker, &mqtt_cfg).expect("MQTT client create failed");

    // subscribe shared attributes
    client.subscribe("v1/devices/me/attributes", QoS::AtMostOnce).unwrap();

    info!("MQTT connected, waiting for OTA attributes...");

    // === Loop ===
    loop {
        match event_loop.poll(std::time::Duration::from_millis(1000)) {
            Ok(evt) => match evt {
                MqttEvent::Received { topic, payload, .. } => {

