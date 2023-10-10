FROM mcr.microsoft.com/dotnet/aspnet:6.0 AS base
WORKDIR /app
EXPOSE 5234

ENV ASPNETCORE_URLS=http://+:5234

# Creates a non-root user with an explicit UID and adds permission to access the /app folder
# For more info, please refer to https://aka.ms/vscode-docker-dotnet-configure-containers
RUN adduser -u 5678 --disabled-password --gecos "" appuser && chown -R appuser /app
USER appuser

FROM mcr.microsoft.com/dotnet/sdk:6.0 AS build
WORKDIR /src
COPY ["aws.csproj", "./"]
RUN dotnet restore "aws.csproj"
COPY . .
WORKDIR "/src/."
RUN dotnet build "aws.csproj" -c Release -o /app/build

FROM build AS publish
RUN dotnet publish "aws.csproj" -c Release -o /app/publish /p:UseAppHost=false

FROM base AS final
WORKDIR /app
COPY --from=publish /app/publish .
ENTRYPOINT ["dotnet", "aws.dll"]
