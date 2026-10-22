var builder = WebApplication.CreateBuilder(args);
builder.Services.AddHealthChecks();

var app = builder.Build();
app.MapGet("/", () => Results.Ok(new
{
    name = "aks-delivery-bicep-azure-devops",
    version = typeof(Program).Assembly.GetName().Version!.ToString(3)
}));
app.MapHealthChecks("/health");
app.Run();

// Expose the entry point to the integration test host.
public partial class Program;
