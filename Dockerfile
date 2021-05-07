# syntax=docker/dockerfile:1
FROM golang:1.16 as build

WORKDIR /go/src/github.com/budacom/sendsync

RUN git clone --depth=1 https://github.com/budacom/sendsync /go/src/github.com/budacom/sendsync

RUN go mod download
RUN go mod verify
RUN CGO_ENABLED=0 go build -o sendsync

FROM alpine:latest

RUN apk --no-cache add ca-certificates

WORKDIR /root/

COPY --from=build /go/src/github.com/budacom/sendsync/sendsync /usr/local/bin

ENTRYPOINT [ "sendsync" ]
