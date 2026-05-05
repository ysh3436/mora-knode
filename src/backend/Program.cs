using System.Text.Json.Serialization;
using MoraKnode.Auth;
using MoraKnode.Endpoints;
using MoraKnode.Infrastructure;
using MoraKnode.Seeders;

var builder = WebApplication.CreateBuilder(args);

// Local-only override layer. Loaded after appsettings.{Env}.json so values
// here win, but before env vars / command-line so CI / launch scripts can
// still override Local. Gitignored — used for per-worktree port + Mongo
// database overrides when running parallel dev instances on one machine.
// Copy appsettings.Local.example.json to appsettings.Local.json to start.
builder.Configuration.AddJsonFile("appsettings.Local.json", optional: true, reloadOnChange: true);

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
builder.Services.AddSingleton<WorkCalendarRepository>();
builder.Services.AddSingleton<HolidaySourceRepository>();
builder.Services.AddSingleton<AppMetaRepository>();
builder.Services.AddSingleton<AgentTokenRepository>();
builder.Services.AddSingleton<DepartmentRepository>();
builder.Services.AddHttpClient("ics");
builder.Services.AddSingleton<IcsFetcherService>();
builder.Services.AddSingleton<Seeder>();

// Per-request user context (populated by UserContextMiddleware) and scope
// service that resolves what the caller is allowed to see.
builder.Services.AddScoped<UserContext>();
builder.Services.AddScoped<ScopeService>();

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

app.UseMiddleware<UserContextMiddleware>();

app.MapGet("/health", () => Results.Ok(new { status = "ok" }));

app.MapProjectEndpoints();
app.MapTaskEndpoints();
app.MapTaskHierarchyEndpoints();
app.MapChangeLogEndpoints();
app.MapResourceEndpoints();
app.MapAgentEndpoints();
app.MapDepartmentEndpoints();
app.MapAssignmentEndpoints();
app.MapMatrixEndpoints();
app.MapMilestoneEndpoints();
app.MapWorkCalendarEndpoints();
app.MapHolidaySourceEndpoints();
app.MapHolidayEndpoints();

if (app.Environment.IsDevelopment())
{
    app.MapDevEndpoints();
}

using (var scope = app.Services.CreateScope())
{
    var ctx = scope.ServiceProvider.GetRequiredService<MongoContext>();
    await ctx.EnsureIndexesAsync();
}

app.Run();
