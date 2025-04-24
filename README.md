# TeslaMate

[![CI](https://github.com/teslamate-org/teslamate/actions/workflows/devops.yml/badge.svg)](https://github.com/teslamate-org/teslamate/actions/workflows/devops.yml)
[![Publish Docker images](https://github.com/teslamate-org/teslamate/actions/workflows/buildx.yml/badge.svg)](https://github.com/teslamate-org/teslamate/actions/workflows/buildx.yml)
[![Coverage](https://coveralls.io/repos/github/teslamate-org/teslamate/badge.svg?branch=master)](https://coveralls.io/github/teslamate-org/teslamate?branch=master)
[![current version](https://img.shields.io/docker/v/teslamate/teslamate/latest)](https://hub.docker.com/r/teslamate/teslamate)
[![docker image size](https://img.shields.io/docker/image-size/teslamate/teslamate/latest)](https://hub.docker.com/r/teslamate/teslamate)
[![docker pulls](https://img.shields.io/docker/pulls/teslamate/teslamate?color=%23099cec)](https://hub.docker.com/r/teslamate/teslamate)

A powerful, self-hosted data logger for your Tesla.

- Written in **[Elixir](https://elixir-lang.org/)**
- Data is stored in a **Postgres** database
- Visualization and data analysis with **Grafana**
- Vehicle data is published to a local **MQTT** Broker

# 本项目属于中国区DIY版本
更适合中国宝宝的配方！定期rebase官方新版本。  
通过开放自定义地址反查接口和grafana地图配置文件，解决国内用户需要到处挂梯子才能显示地图、显示行程地址的痛点。

## 项目特性
 - 自定义地址反向查询URL（Docker env: NOMINATIM_API_HOST）  
   **服务可以通过nominatim容器自建，仅使用反向查询接口消耗的资源很少**
 - 自定义grafana地图组件使用的默认地图源  
   **服务当然也可以自建，但是比较耗费系统资源，我更推荐免费的API[Thunderforest，一个月15万次免费调用，非常充足](https://www.thunderforest.com/)**
 - 最新版本增加了行程中的速度颜色区分，清晰地展示了一段行程中在哪个位置堵车、在哪个位置放飞自我~

## 供参考的配置文件
1. docker-compose.yml
```yml
services:
  nominatim:
    image: mediagis/nominatim:4.4
    restart: always
    environment:
      # see https://github.com/mediagis/nominatim-docker/tree/master/4.4#configuration for more options
      PBF_URL: https://download.geofabrik.de/asia/china-latest.osm.pbf
      REPLICATION_URL: https://download.geofabrik.de/asia/china-updates/
      REVERSE_ONLY: "true" #只做地址反查，性价比极高
      NOMINATIM_PASSWORD: password #insert your secure database password!
      TZ: Asia/Shanghai
    volumes:
        - nominatim-data:/var/lib/postgresql/14/main

  teslamate:
    image: ghcr.io/senmizu/teslamate_cn:1.32.0.14
    restart: always
    environment:
      - ENCRYPTION_KEY=secretkey #replace with a secure key to encrypt your Tesla API tokens
      - DATABASE_USER=teslamate
      - DATABASE_PASS=password #insert your secure database password!
      - DATABASE_NAME=teslamate
      - DATABASE_HOST=database
      - MQTT_HOST=mosquitto
      - NOMINATIM_API_HOST=http://nominatim:8080  #就这样就行了
      - TZ=Asia/Shanghai
    ports:
      - 4000:4000
    volumes:
      - ./import:/opt/app/import
    cap_drop:
      - all
    depends_on:
      - nominatim

  database:
    image: postgres:15
    restart: always
    environment:
      - POSTGRES_USER=teslamate
      - POSTGRES_PASSWORD=password #insert your secure database password!
      - POSTGRES_DB=teslamate
      - TZ=Asia/Shanghai
    volumes:
      - teslamate-db:/var/lib/postgresql/data

  grafana:
    image: ghcr.io/senmizu/teslamate_cn/grafana:1.32.0.14
    restart: always
    environment:
      - DATABASE_USER=teslamate
      - DATABASE_PASS=password #insert your secure database password!
      - DATABASE_NAME=teslamate
      - DATABASE_HOST=database
      - TZ=Asia/Shanghai
    ports:
      - 3000:3000
    volumes:
      - teslamate-grafana-data:/var/lib/grafana
      - /your_path_to_container_config_files/grafana-config/grafana.ini:/etc/grafana/grafana.ini:ro #具体配置内容参照后面内容
      
  mosquitto:
    image: eclipse-mosquitto:2
    restart: always
    command: mosquitto -c /mosquitto-no-auth.conf
    ports:
      - 1883:1883 #不需要可以参照官方文档不使用，我用homeassistant集成需要这个端口
    volumes:
      - mosquitto-conf:/mosquitto/config
      - mosquitto-data:/mosquitto/data
    environment:
      - TZ=Asia/Shanghai

volumes:
  teslamate-db:
  teslamate-grafana-data:
  mosquitto-conf:
  mosquitto-data:
  nominatim-data:
```   

2. grafana.ini
```ini
[geomap]
# Set the JSON configuration for the default basemap
default_baselayer_config = `{
  "type": "xyz",
  "config": {
    "attribution": "Thunderforest",
    "url": "https://tile.thunderforest.com/atlas/{z}/{x}/{y}.png?apikey=your_api_key"
  }
}`
```

## Documentation

The documentation is available at [https://docs.teslamate.org](https://docs.teslamate.org/)

## Features

### General

- High precision drive data recording
- No additional vampire drain: the car will fall asleep as soon as possible
- Automatic address lookup
- Easy integration into Home Assistant (via MQTT)
- Easy integration into Node-Red & Telegram (via MQTT)
- Geo-fencing feature to create custom locations
- Supports multiple vehicles per Tesla Account
- Charge cost tracking
- Import from TeslaFi and tesla-apiscraper

### Dashboards

Sample screenshots of bundled dashboards can be seen by clicking the links below.

- [Battery Health](https://docs.teslamate.org/docs/screenshots/#battery-health)
- [Charge Level](https://docs.teslamate.org/docs/screenshots/#charge-level)
- [Charges (Energy added / used)](https://docs.teslamate.org/docs/screenshots#charges)
- [Charge Details](https://docs.teslamate.org/docs/screenshots#charge-details)
- [Charging Stats](https://docs.teslamate.org/docs/screenshots#charging-stats)
- [Database Information](https://docs.teslamate.org/docs/screenshots/#database-information)
- [Drive Stats](https://docs.teslamate.org/docs/screenshots#drive-stats)
- [Drives (Distance / Energy consumed (net))](https://docs.teslamate.org/docs/screenshots/#drives)
- [Drive Details](https://docs.teslamate.org/docs/screenshots/#drive-details)
- [Efficiency (Consumption (net / gross))](https://docs.teslamate.org/docs/screenshots#efficiency)
- [Locations (addresses)](https://docs.teslamate.org/docs/screenshots/#location-addresses)
- [Mileage](https://docs.teslamate.org/docs/screenshots/#mileage)
- [Overview](https://docs.teslamate.org/docs/screenshots/#overview)
- [Projected Range (battery degradation)](https://docs.teslamate.org/docs/screenshots#projected-range)
- [States (see when your car was online or asleep)](https://docs.teslamate.org/docs/screenshots#states)
- [Statistics](https://docs.teslamate.org/docs/screenshots/#statistics)
- [Timeline](https://docs.teslamate.org/docs/screenshots/#timeline)
- [Trip](https://docs.teslamate.org/docs/screenshots/#trip)
- [Updates (History of installed updates)](https://docs.teslamate.org/docs/screenshots#updates)
- [Vampire Drain](https://docs.teslamate.org/docs/screenshots#vampire-drain)
- [Visited (Lifetime driving map)](https://docs.teslamate.org/docs/screenshots/#visited-lifetime-driving-map)

## Screenshots

Sneak peak into TeslaMate interface and bundled dashboards. See [the docs](https://docs.teslamate.org/docs/screenshots) for additional screenshots.

![Web Interface](/website/static/screenshots/web_interface.png)

![Drive Details](/website/static/screenshots/drive.png)

![Battery Health](/website/static/screenshots/battery-health.png)

## Credits

- Initial Author: Adrian Kumpf
- List of Contributors:
- [![TeslaMate Contributors](https://contrib.rocks/image?repo=teslamate-org/teslamate)](https://github.com/teslamate-org/teslamate/graphs/contributors)
- Distributed under MIT License
