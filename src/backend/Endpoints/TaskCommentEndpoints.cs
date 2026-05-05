using MoraKnode.Auth;
using MoraKnode.Domain;
using MoraKnode.Infrastructure;

namespace MoraKnode.Endpoints;

public static class TaskCommentEndpoints
{
    public record CreateCommentRequest(string Body, string? Kind);
    public record UpdateCommentRequest(string Body, string? Kind);

    public static IEndpointRouteBuilder MapTaskCommentEndpoints(this IEndpointRouteBuilder app)
    {
        // Comments live under /api/tasks/{id}/comments for list+create so the
        // shape mirrors how the inspector reads them, and at /api/comments/{id}
        // for edit/delete because those don't need the parent task in the path.
        app.MapGet("/api/tasks/{taskId}/comments", async (
            string taskId,
            TaskCommentRepository repo,
            CancellationToken ct) =>
        {
            var rows = await repo.ListByTaskAsync(taskId, ct);
            return Results.Ok(rows);
        }).WithTags("TaskComments");

        app.MapPost("/api/tasks/{taskId}/comments", async (
            string taskId,
            CreateCommentRequest req,
            UserContext userCtx,
            TaskRepository tasks,
            TaskCommentRepository repo,
            CancellationToken ct) =>
        {
            if (userCtx.CurrentUser is null)
                return Results.Json(
                    new { error = "Authentication required to comment." },
                    statusCode: StatusCodes.Status401Unauthorized);

            if (string.IsNullOrWhiteSpace(req.Body))
                return Results.BadRequest(new { error = "Body is required" });

            var task = await tasks.GetAsync(taskId, ct);
            if (task is null) return Results.NotFound(new { error = "Task not found" });

            var comment = await repo.InsertAsync(new TaskComment
            {
                TaskId = taskId,
                AuthorResourceId = userCtx.CurrentUser.Id,
                Body = req.Body,
                Kind = string.IsNullOrWhiteSpace(req.Kind) ? null : req.Kind.Trim(),
            }, ct);

            return Results.Created($"/api/comments/{comment.Id}", comment);
        }).WithTags("TaskComments");

        app.MapPut("/api/comments/{id}", async (
            string id,
            UpdateCommentRequest req,
            UserContext userCtx,
            TaskCommentRepository repo,
            CancellationToken ct) =>
        {
            if (userCtx.CurrentUser is null)
                return Results.Json(
                    new { error = "Authentication required." },
                    statusCode: StatusCodes.Status401Unauthorized);

            var existing = await repo.GetAsync(id, ct);
            if (existing is null) return Results.NotFound();

            // Only the author can edit. Admins (Manager / Reviewer / Human) can
            // also edit so a moderator can fix a typo or strip a wrong screenshot.
            var isAuthor = existing.AuthorResourceId == userCtx.CurrentUser.Id;
            if (!isAuthor && !userCtx.IsAdmin)
                return Results.Json(
                    new { error = "Only the author or an admin can edit a comment." },
                    statusCode: StatusCodes.Status403Forbidden);

            if (string.IsNullOrWhiteSpace(req.Body))
                return Results.BadRequest(new { error = "Body is required" });

            existing.Body = req.Body;
            existing.Kind = string.IsNullOrWhiteSpace(req.Kind) ? null : req.Kind.Trim();
            var updated = await repo.ReplaceAsync(id, existing, ct);
            return updated is null ? Results.NotFound() : Results.Ok(updated);
        }).WithTags("TaskComments");

        app.MapDelete("/api/comments/{id}", async (
            string id,
            UserContext userCtx,
            TaskCommentRepository repo,
            CancellationToken ct) =>
        {
            if (userCtx.CurrentUser is null)
                return Results.Json(
                    new { error = "Authentication required." },
                    statusCode: StatusCodes.Status401Unauthorized);

            var existing = await repo.GetAsync(id, ct);
            if (existing is null) return Results.NotFound();

            var isAuthor = existing.AuthorResourceId == userCtx.CurrentUser.Id;
            if (!isAuthor && !userCtx.IsAdmin)
                return Results.Json(
                    new { error = "Only the author or an admin can delete a comment." },
                    statusCode: StatusCodes.Status403Forbidden);

            var ok = await repo.DeleteAsync(id, ct);
            return ok ? Results.NoContent() : Results.NotFound();
        }).WithTags("TaskComments");

        return app;
    }
}
