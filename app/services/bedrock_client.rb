class BedrockClient
  def self.converse(params)
    client.converse(**params)
  end

  def self.client
    @client ||= Aws::BedrockRuntime::Client.new(
      region: ENV.fetch("AWS_REGION", "eu-west-2")
    )
  end
  private_class_method :client
end
