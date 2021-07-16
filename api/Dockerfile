FROM mcr.microsoft.com/dotnet/core/sdk:3.1 AS backend-build

WORKDIR /backend

COPY . ./

WORKDIR /backend/Spawn.Demo.WebApi

RUN dotnet restore

RUN dotnet publish -c Release -o out

# build final image
FROM mcr.microsoft.com/dotnet/core/aspnet:3.1 AS runtime

# Install dependencies
RUN apt-get update && apt-get install -y wget jq

# Install spawnctl
RUN curl https://run.spawn.cc/install | sh && ln -s $HOME/.spawnctl/bin/spawnctl /usr/local/bin

# Install Flyway
RUN wget -qO- https://repo1.maven.org/maven2/org/flywaydb/flyway-commandline/7.0.2/flyway-commandline-7.0.2-linux-x64.tar.gz | \
 tar xz && ln -s `pwd`/flyway-7.0.2/flyway /usr/local/bin

ENV DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=false

WORKDIR /app

COPY --from=backend-build /backend/Spawn.Demo.WebApi/out ./
COPY --from=backend-build /backend/database ./database/
COPY --from=backend-build /backend/*.sh ./
COPY --from=backend-build /backend/.env ./

EXPOSE 8080
ENV ASPNETCORE_URLS=http://*:8080

ENTRYPOINT ["./entrypoint.sh"]