ARG ESHOP_COMMIT=9b4f9434f46fdc5c1a6e9e936af2868340cdbc48

FROM --platform=$BUILDPLATFORM mcr.microsoft.com/dotnet/sdk:10.0 AS build
ARG ESHOP_COMMIT
ARG PROJECT
WORKDIR /workspace
RUN apt-get update \
    && apt-get install -y --no-install-recommends git ca-certificates \
    && rm -rf /var/lib/apt/lists/*
RUN git clone https://github.com/dotnet/eShop.git . \
    && git checkout "${ESHOP_COMMIT}"
RUN dotnet restore "${PROJECT}"
RUN dotnet publish "${PROJECT}" -c Release -o /app --no-restore

FROM mcr.microsoft.com/dotnet/aspnet:10.0 AS runtime
ARG ENTRY_DLL
ENV ENTRY_DLL=$ENTRY_DLL
WORKDIR /app
RUN groupadd --system eshop && useradd --system --gid eshop eshop
COPY --from=build --chown=eshop:eshop /app /app
USER eshop
EXPOSE 8080
ENTRYPOINT ["sh", "-c", "exec dotnet \"$ENTRY_DLL\""]
