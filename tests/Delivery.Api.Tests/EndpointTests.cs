using System.Net;
using System.Text.Json;
using Microsoft.AspNetCore.Mvc.Testing;

namespace Delivery.Api.Tests;

public class EndpointTests(WebApplicationFactory<Program> factory)
    : IClassFixture<WebApplicationFactory<Program>>
{
    [Fact]
    public async Task Root_returns_application_identity_as_json()
    {
        using var client = factory.CreateClient();
        using var response = await client.GetAsync("/");
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        Assert.Equal("application/json", response.Content.Headers.ContentType?.MediaType);
        using var json = JsonDocument.Parse(await response.Content.ReadAsStringAsync());
        Assert.Equal("aks-delivery-bicep-azure-devops", json.RootElement.GetProperty("name").GetString());
        Assert.Equal("1.0.0", json.RootElement.GetProperty("version").GetString());
    }

    [Fact]
    public async Task Health_returns_healthy_status()
    {
        using var client = factory.CreateClient();
        using var response = await client.GetAsync("/health");
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        Assert.Equal("text/plain", response.Content.Headers.ContentType?.MediaType);
        Assert.Equal("Healthy", await response.Content.ReadAsStringAsync());
        Assert.Contains("no-store", response.Headers.CacheControl?.ToString() ?? "");
    }
}
