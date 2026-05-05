# Multi-stage backend image for the coordination layer.
# Build stage uses the full SDK; runtime stage is the slim ASP.NET image.
# Configuration is injected via env vars at runtime — appsettings.Local.json
# is intentionally not copied (the gitignored override is for host dev only).

FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build
WORKDIR /src
COPY src/backend/backend.csproj ./
RUN dotnet restore
COPY src/backend/. ./
RUN dotnet publish -c Release -o /app /p:UseAppHost=false

FROM mcr.microsoft.com/dotnet/aspnet:10.0
WORKDIR /app
COPY --from=build /app .

# Bind to all interfaces so the host (or other compose services) can reach it.
ENV ASPNETCORE_URLS=http://+:5163
EXPOSE 5163

ENTRYPOINT ["dotnet", "backend.dll"]
