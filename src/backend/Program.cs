using System.Text.Json.Serialization;
using MoraKnode.Endpoints;
using MoraKnode.Infrastructure;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddOpenApi();

builder.Services.ConfigureHttpJsonOptions(o =>
{
    o.SerializerOptions.Converters.Add(new JsonStringEnumConverter());
});

builder.Services.Configure<MongoOptions>(builder.Configuration.GetSection(MongoOptions.SectionName));
builder.Services.AddSingleton<MongoContext>();
builder.Services.AddSingleton<ProjectRepository>();
builder.Services.AddSingleton<TaskRepository>();
builder.Services.AddSingleton<ChangeLogRepository>();
builder.Services.AddSingleton<ResourceRepository>();
builder.Services.AddSingleton<AssignmentRepository>();
builder.Services.AddSingleton<MilestoneRepository>();

// Development-only open CORS so the Flutter web client (dart server) can call the API.
builder.Services.AddCors(options =>
{
    options.AddDefaultPolicy(p => p
        .SetIsOriginAllowed(_ => true)
        .AllowAnyHeader()
        .AllowAnyMethod()
        .AllowCredentials());
});

var app = builder.Build();

if (app.Environment.IsDevelopment())
{
    app.MapOpenApi();
    app.UseCors();
}

app.MapGet("/health", () => Results.Ok(new { status = "ok" }));

app.MapProjectEndpoints();
app.MapTaskEndpoints();
app.MapTaskHierarchyEndpoints();
app.MapChangeLogEndpoints();
app.MapResourceEndpoints();
app.MapAssignmentEndpoints();
app.MapMatrixEndpoints();
app.MapMilestoneEndpoints();

using (var scope = app.Services.CreateScope())
{
    var ctx = scope.ServiceProvider.GetRequiredService<MongoContext>();
    await ctx.EnsureIndexesAsync();
}

app.Run();
