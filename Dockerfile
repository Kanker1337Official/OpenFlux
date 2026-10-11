FROM golang:1.26-alpine AS build
WORKDIR /src

COPY go.mod go.sum ./
RUN go mod download

COPY . .
RUN CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" -o /out/openflux .

FROM alpine:3.22
RUN apk add --no-cache ca-certificates iptables

COPY --from=build /out/openflux /usr/local/bin/openflux
COPY docker/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh /usr/local/bin/openflux

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
