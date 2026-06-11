var builder = WebApplication.CreateBuilder(args);
var app = builder.Build();

// The RAG index version this build serves. Baked in via env var at deploy
// time so Blue (V1) and Green (V2) revisions answer differently.
var ragIndexVersion = Environment.GetEnvironmentVariable("RAG_INDEX_VERSION") ?? "V1";

// Azure Container Apps injects the revision name automatically — handy proof
// of which slot actually served the request.
var revisionName = Environment.GetEnvironmentVariable("CONTAINER_APP_REVISION") ?? "local";

// Simulates the GenAI Copilot answering a user question from the RAG index.
app.MapGet("/query", (string? q) => Results.Ok(new
{
    answer = $"Responding from RAG Index {ragIndexVersion}",
    question = q ?? "(none)",
    servedBy = revisionName,
    timestampUtc = DateTime.UtcNow
}));

// Liveness/readiness probe target for Azure Container Apps and the CI/CD
// pipeline's pre-cutover verification step.
app.MapGet("/health", () => Results.Ok(new
{
    status = "Healthy",
    ragIndexVersion,
    servedBy = revisionName
}));

app.MapGet("/", () => Results.Ok(new
{
    service = "GenAI Copilot API",
    endpoints = new[] { "/query?q=...", "/health" }
}));

app.Run();
