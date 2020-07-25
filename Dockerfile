FROM registry.gitlab.com/snapcoreinc/snapcore-monitor:latest as kickstart
FROM golang:1.14-alpine3.12 as builder

ENV TINI_VERSION v0.19.0
ADD https://github.com/krallin/tini/releases/download/${TINI_VERSION}/tini-static /tini
RUN chmod +x /tini

# Required to enable Go modules
RUN apk add --no-cache git

# Allows you to add additional packages via build-arg
ARG ADDITIONAL_PACKAGE
ARG CGO_ENABLED=0
ARG GO111MODULE="off"
ARG GOPROXY=""
ARG GOFLAGS=""

ENV CGO_ENABLED=0

WORKDIR /go/src/handler
COPY . .

# Add user overrides to the root go.mod, which is the only place "replace" can be used
RUN cat module/GO_REPLACE.txt >> ./go.mod || exit 0

# Run a gofmt and exclude all vendored code.
RUN test -z "$(gofmt -l $(find . -type f -name '*.go' -not -path "./vendor/*" -not -path "./module/vendor/*"))" || { echo "Run \"gofmt -s -w\" on your Golang code"; exit 1; }

WORKDIR /go/src/handler/module

RUN CGO_ENABLED=${CGO_ENABLED} go test ./... -cover

WORKDIR /go/src/handler

RUN CGO_ENABLED=${CGO_ENABLED} GOOS=linux \
    go build --ldflags "-s -w" -a -installsuffix cgo -o handler .

RUN addgroup -S app \
    && adduser -S -g app app \
    && apk add --no-cache ca-certificates \
    && mkdir /scratch-tmp

FROM scratch
# RUN apk --no-cache add ca-certificates \
#     && addgroup -S app && adduser -S -g app app \
#     && mkdir -p /home/app \
#     && chown app /home/app

WORKDIR /home/app

COPY --from=builder /tini .
COPY --from=builder /go/src/handler/handler  .
COPY --from=kickstart /dih-monitor /dih-monitor
COPY --from=builder /etc/passwd /etc/group /etc/
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/
COPY --from=builder --chown=app:app /scratch-tmp /tmp

# RUN chown -R app /home/app

USER app

ENV startup_process="/home/app/handler" \
    mode="streaming" \
    http_proxy="" \
    https_proxy=""

EXPOSE 8080

HEALTHCHECK --interval=3s CMD [ -e /tmp/.lock ] || exit 1

ENTRYPOINT ["/tini", "--"]
CMD ["/dih-monitor"]
