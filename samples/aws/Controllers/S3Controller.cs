using System.Text;
using Amazon;
using Amazon.Runtime;
using Amazon.S3;
using Amazon.S3.Model;
using Microsoft.AspNetCore.Mvc;

namespace aws.Controllers;

[ApiController]
[Route("[controller]")]
public class S3Controller : ControllerBase
{
    private readonly ILogger<S3Controller> _logger;
    private readonly string _bucketName;
    private readonly AmazonS3Client _client;

    public S3Controller(ILogger<S3Controller> logger, IConfiguration configuration)
    {
        _logger = logger;
        _bucketName = configuration["BUCKET_NAME"];
        _client = GetAWSClient(configuration);
    }

    [HttpPost("upload")]
    public async Task<IActionResult> UploadFileAsync(IFormFile file)
    {
        var client = _client;
        var request = new PutObjectRequest
        {
            BucketName = _bucketName,
            Key = file.FileName,
            InputStream = file.OpenReadStream()
        };

        request.Metadata.Add("Content-Type", file.ContentType);

        var response = await client.PutObjectAsync(request);
        return Ok($"File {file.FileName} uploaded to S3 successfully!");
    }

    private AmazonS3Client GetAWSClient(IConfiguration configuration)
    {
        if (configuration["AWS_ACCESS_KEY_ID"] != null && configuration["AWS_SECRET_ACCESS_KEY"] != null && configuration["AWS_DEFAULT_REGION"] != null) {
            var accessKey = configuration["AWS_ACCESS_KEY_ID"];
            var secretKey = configuration["AWS_SECRET_ACCESS_KEY"];
            var region =  configuration["AWS_DEFAULT_REGION"];
            return new AmazonS3Client(new BasicAWSCredentials(accessKey, secretKey), RegionEndpoint.GetBySystemName(region));
        }
        else {
            return new AmazonS3Client(Amazon.RegionEndpoint.USWest1);
        }
    }

    [HttpGet("get-all")]
    public async Task<IActionResult> GetAllFilesAsync()
    {
        var client = _client;
        var request = new ListObjectsV2Request()
        {
            BucketName = _bucketName,
        };
        var result = await client.ListObjectsV2Async(request);
        var s3Objects = result.S3Objects.Select(s =>
        {
            var urlRequest = new GetPreSignedUrlRequest()
            {
                BucketName = _bucketName,
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


