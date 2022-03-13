using SecretTest;

var builder = WebApplication.CreateBuilder(args);
// Add services to the container.
builder.Services.Configure<RabbitMqConfig>(
        builder.Configuration.GetSection(nameof(RabbitMqConfig))
    );
builder.Services.AddControllers();
// Learn more about configuring Swagger/OpenAPI at https://aka.ms/aspnetcore/swashbuckle
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();

var app = builder.Build();

app.UseSwagger();
app.UseSwaggerUI();
app.UseHttpsRedirection();
app.UseAuthorization();
app.MapControllers();
app.Run();