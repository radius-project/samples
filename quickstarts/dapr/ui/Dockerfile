FROM mcr.microsoft.com/dotnet/runtime-deps:6.0-alpine AS base
WORKDIR /app

FROM mcr.microsoft.com/dotnet/sdk:6.0-alpine AS build
WORKDIR /src
COPY ["ui.csproj", "."]
RUN dotnet restore "ui.csproj" -r linux-musl-x64 /p:PublishReadyToRun=false
COPY . .
RUN dotnet publish "ui.csproj" -c Release -o /app/publish -r linux-musl-x64 --self-contained true --no-restore /p:PublishReadyToRun=false /p:PublishSingleFile=true

FROM base AS final
WORKDIR /app
# Enabling globalization
ENV \
     DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=false \
     LC_ALL=en_US.UTF-8 \
     LANG=en_US.UTF-8
RUN apk add --no-cache icu-libs
COPY --from=build /app/publish .
ENTRYPOINT ["/app/ui"]
