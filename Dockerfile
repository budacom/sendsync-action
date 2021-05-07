# syntax=docker/dockerfile:1
FROM golang:1.16 as build

WORKDIR /go/src/github.com/budacom/sendsync

RUN git clone --depth=1 https://github.com/budacom/sendsync /go/src/github.com/budacom/sendsync

RUN go mod download
RUN go mod verify
RUN CGO_ENABLED=0 go build -o sendsync

FROM alpine:latest as gh

RUN apk --no-cache add wget tar
RUN wget https://github.com/cli/cli/releases/download/v1.9.2/gh_1.9.2_linux_amd64.tar.gz
RUN tar -zxvf gh_1.9.2_linux_amd64.tar.gz
RUN chmod a+x gh_1.9.2_linux_amd64/bin/gh

FROM alpine:latest

RUN apk --no-cache add ca-certificates git

WORKDIR /root/

RUN mkdir /lib64 && ln -s /lib/libc.musl-x86_64.so.1 /lib64/ld-linux-x86-64.so.2
COPY --from=gh gh_1.9.2_linux_amd64/bin/gh /usr/bin/gh

COPY --from=build /go/src/github.com/budacom/sendsync/sendsync /usr/local/bin
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT [ "/entrypoint.sh" ]
