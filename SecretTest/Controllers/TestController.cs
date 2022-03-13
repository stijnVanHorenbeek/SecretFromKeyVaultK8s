using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Options;

namespace SecretTest.Controllers;

[ApiController]
[Route("[controller]")]
public class TestController : ControllerBase
{
    private readonly RabbitMqConfig _rabbitMqConfig;

    public TestController(IOptions<RabbitMqConfig> rabbitMqConfig)
    {
        _rabbitMqConfig = rabbitMqConfig.Value;
    }
    
    [HttpGet]
    public IActionResult GetRabbitMQConfig()
    {
        return Ok(_rabbitMqConfig);
    }
}