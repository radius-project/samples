using Amazon.S3;
using Amazon.S3.Model;
using Microsoft.AspNetCore.Mvc;

namespace aws.Controllers;

[ApiController]
[Route("[controller]")]
public class S3Controller : ControllerBase
{
    private readonly ILogger<S3Controller> _logger;

    public S3Controller(ILogger<S3Controller> logger, IConfiguration configuration)
    {
        _logger = logger;
    }

    [HttpPost("upload")]
    public async Task<IActionResult> UploadFileAsync(IFormFile file, string bucketName, string? prefix)
    {
        var client = new AmazonS3Client(Amazon.RegionEndpoint.USWest1);
        var request = new PutObjectRequest
        {
            BucketName = bucketName,
            Key = string.IsNullOrEmpty(prefix) ? file.FileName : $"{prefix?.TrimEnd('/')}/{file.FileName}",
            InputStream = file.OpenReadStream()
        };

        request.Metadata.Add("Content-Type", file.ContentType);

        var response = await client.PutObjectAsync(request);
        return Ok($"File {prefix}/{file.FileName} uploaded to S3 successfully!");
    }

    [HttpGet("get-all")]
    public async Task<IActionResult> GetAllFilesAsync(string bucketName, string? prefix)
    {
        var client = new AmazonS3Client(Amazon.RegionEndpoint.USWest1);
        var request = new ListObjectsV2Request()
        {
            BucketName = bucketName,
            Prefix = prefix
        };
        var result = await client.ListObjectsV2Async(request);
        var s3Objects = result.S3Objects.Select(s =>
        {
            var urlRequest = new GetPreSignedUrlRequest()
            {
                BucketName = bucketName,
                Key = s.Key,
                Expires = DateTime.UtcNow.AddMinutes(1)
            };
            return new aws.Models.S3Object()
            {
                Name = s.Key.ToString(),
                PresignedUrl = client.GetPreSignedURL(urlRequest),
            };
        });
        return Ok(s3Objects);
    }
}


