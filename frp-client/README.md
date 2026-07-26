# FRP Client

The `frpc` FRP Client exposes the actual back-end service to the front-end FRP Server `frps`.

## Backend Service

Run a service at the backend, such as from a server at home.

## Install FRP

Download the [FRP release](https://github.com/fatedier/frp/releases). The client binary is `frpc`.

Place `frpc` on the backend server.

## FRP Client config

The following illustrates frpc configurations for several possible back-end service types.

### Option: TCP backend service

E.g. [knots bitcoind](https://bitcoinknots.org/)

frpc.toml
```conf
serverAddr = "FRP_SERVER_PUBLIC_HOST"
serverPort = 7000

[[proxies]]
name = "knots"
type = "tcp"
localIP = "127.0.0.1" # IP of the back-end service
localPort = 8333 # listening port of the back-end service
remotePort = 38333 # listening port at the front-end frps proxy
```

### Option: Plain HTTP backend service

Can be any web service. The following example command starts a basic web server:
```sh
python3 -m http.server 8000
```

frpc.http.toml
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

Scenario: backend HTTP server is plain text, and frpc is to proxy the service as encrypted HTTPS.

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

frpc.https.toml
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
* Curl, e.g. https: `curl https://$FRP_SERVER_PUBLIC_HOST:7000`
* if TCP, netcat: `nc -vz $FRP_SERVER_PUBLIC_HOST $PORT`
