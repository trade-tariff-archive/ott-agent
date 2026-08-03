class BedrockClient
  def self.converse(params)
    client = Aws::BedrockRuntime::Client.new(
      region: ENV.fetch("AWS_REGION", "eu-west-2")
    )
    client.converse(**params)
  end
end
