FROM golang:1.27.1 AS build
WORKDIR /src
COPY go.mod go.sum ./
RUN go mod download
COPY main.go ./
RUN CGO_ENABLED=0 go build -o /rates .

FROM gcr.io/distroless/static-debian12
COPY --from=build /rates /rates
ENTRYPOINT ["/rates"]
