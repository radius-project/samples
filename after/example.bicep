import aws as aws

resource stream 'AWS.Kinesis/Stream@default' = {
  name: 'example'
  properties: {
        ShardCount: 2
    }
}
