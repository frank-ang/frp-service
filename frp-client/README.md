# FRP Client

Back-end service configuration.

## Simple Web Server

Start a basic web server, e.g.

```sh
python3 -m http.server 8000
```

## FRP install

Download the [release](https://github.com/fatedier/frp/releases), the client binary is `frpc`.

## FRP config

frp client config file.

```sh
FRP_SERVER=SET_THIS_VALUE_TO_FRP_SERVER_PUBLIC_HOSTNAME_OR_IP

cat > "frpc.toml" <<EOF
serverAddr = "$FRP_SERVER"
serverPort = 7000

[[proxies]]
name = "web"
type = "http"
localPort = 8000
EOF
```

## Start FRP

```sh
frpc -c ./frpc.toml
```

## Browse to the configured public port of the FRP Server.

E.g. `curl http://$FRP_SERVER:48080`
