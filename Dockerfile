FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build
WORKDIR /src
COPY app/Delivery.Api/Delivery.Api.csproj app/Delivery.Api/
RUN dotnet restore app/Delivery.Api/Delivery.Api.csproj
COPY app/Delivery.Api/ app/Delivery.Api/
RUN dotnet publish app/Delivery.Api/Delivery.Api.csproj -c Release -o /out --no-restore /p:UseAppHost=false

FROM mcr.microsoft.com/dotnet/aspnet:10.0 AS runtime
WORKDIR /app
COPY --from=build /out/ ./
ENV ASPNETCORE_HTTP_PORTS=8080
EXPOSE 8080
USER $APP_UID
ENTRYPOINT ["dotnet", "Delivery.Api.dll"]
