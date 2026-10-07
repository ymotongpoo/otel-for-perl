FROM perl:5.44.0@sha256:0ea4a4de1034d374754e596f439f126ce29194f7735a5200c2842df70bde06bd
RUN cpanm -nq Carton@1.0.35
WORKDIR /app
COPY cpanfile cpanfile.snapshot ./
RUN carton install --deployment
COPY lib lib
COPY *.psgi ./
ENV PERL5LIB=/app/local/lib/perl5:/app/lib PATH=/app/local/bin:$PATH
EXPOSE 5000
CMD ["plackup", "-E", "deployment", "-s", "HTTP::Server::PSGI", "-p", "5000", "app_otel.psgi"]
