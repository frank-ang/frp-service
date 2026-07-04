# FRP Client

The backend server is the FRP Client.

## Backend Service

Replace with your own service. E.g. Basic web server:
```sh
python3 -m http.server 8000
```

## FRP install

Download the [release](https://github.com/fatedier/frp/releases), the client binary is `frpc`.

## FRP config

### Option: Plain HTTP

frpc.plain.toml
```conf
serverAddr = "FRP_SERVER_PUBLIC_HOST"
serverPort = 7000

[[proxies]]
name = "web"
type = "http"
localPort = 8000 # Edit to the local backend service port
customDomains = ["FRP_SERVER_PUBLIC_HOST"]
```

### Option: Encrypted HTTPS/TLS

#### Obtain TLS Certificate using certbot

Install [Certbot](https://certbot.eff.org/) with DNS integration.

```sh
sudo python3 -m venv /opt/certbot/
sudo /opt/certbot/bin/pip install --upgrade pip
sudo /opt/certbot/bin/pip install certbot
sudo /opt/certbot/bin/pip install certbot-dns-route53
sudo ln -s /opt/certbot/bin/certbot /usr/local/bin/certbot
```

Obtain a TLS/SSL certificate.

```sh
sudo certbot certonly \
  --dns-route53 \
  -d a.domain.com \
  -d b.domain.com \
  --email you@example.com \
  --agree-tos \
  --non-interactive
```

This downloads Certificate/Key PEM files.

> The LetsEncrypt certificates are valid for 90 days.

#### FRP Client Config with HTTPS

frpc.tls.toml
```conf
serverAddr = "FRP_SERVER_PUBLIC_HOST"
serverPort = 7000

[[proxies]]
name = "web"
type = "https"
customDomains = ["FRP_SERVER_PUBLIC_HOST"]

[proxies.plugin]
type = "https2http"
localAddr = "127.0.0.1:8000" # Local HTTPS service address. Edit port number.

crtPath = "LOCATION_OF_PUBLIC_CERT.pem"
keyPath = "LOCATION_OF_PRIVATE_KEY.pem"
hostHeaderRewrite = "127.0.0.1"
requestHeaders.set.x-from-where = "frp"
```


## Start FRP

```sh
frpc -c ./frpc.toml
```

Verify by
* Browsing to the configured public port of the FRP Server.
* Curl, e.g. https: `curl https://$FRP_SERVER_PUBLIC_HOST:48443`
