# Simulates the AWS SDK event-stream handler passed to BedrockClient.converse_stream.
# Stores registered callbacks when on_* methods are called, then lets tests fire
# individual events by calling emit_* methods in any order.
class FakeConverseStream
  def initialize
    @handlers = {}
  end

  def on_content_block_start_event(&block)
    @handlers[:content_block_start] = block
  end

  def on_content_block_delta_event(&block)
    @handlers[:content_block_delta] = block
  end

  def on_content_block_stop_event(&block)
    @handlers[:content_block_stop] = block
  end

  def on_message_stop_event(&block)
    @handlers[:message_stop] = block
  end

  def on_metadata_event(&block)
    @handlers[:metadata] = block
  end

  def emit_text_delta(text, index: 0)
    @handlers[:content_block_delta]&.call(
      double(
        content_block_index: index,
        delta: double(text: text, tool_use: nil),
      ),
    )
  end

  def emit_tool_start(tool_use_id:, name:, index:)
    @handlers[:content_block_start]&.call(
      double(
        content_block_index: index,
        start: double(tool_use: double(tool_use_id: tool_use_id, name: name)),
      ),
    )
  end

  def emit_tool_input_delta(json:, index:)
    @handlers[:content_block_delta]&.call(
      double(
        content_block_index: index,
        delta: double(text: nil, tool_use: double(input: json)),
      ),
    )
  end

  def emit_metadata(input_tokens:, output_tokens:)
    @handlers[:metadata]&.call(
      double(usage: double(input_tokens: input_tokens, output_tokens: output_tokens)),
    )
  end

  def emit_message_stop(stop_reason:)
    @handlers[:message_stop]&.call(double(stop_reason: stop_reason))
  end
end
