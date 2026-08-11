class DashboardController < ApplicationController
  NOVA_PRO_INPUT_PRICE_PER_M  = 0.80
  NOVA_PRO_OUTPUT_PRICE_PER_M = 3.20
  HAIKU_INPUT_PRICE_PER_M     = 1.0
  HAIKU_OUTPUT_PRICE_PER_M    = 5.0

  def index
    assistant_messages = Message.where(role: "assistant")
    timed_messages     = assistant_messages.where("latency_seconds > 0")

    @total_conversations = Conversation.count
    @total_messages      = Message.count
    @total_tokens        = Message.sum(:input_tokens) + Message.sum(:output_tokens)
    @total_intents       = StandingIntent.active.count

    @avg_latency, @p50_latency, @p95_latency = latency_percentiles(timed_messages)

    @avg_input_tokens  = assistant_messages.average(:input_tokens)&.round(0).to_i
    @avg_output_tokens = assistant_messages.average(:output_tokens)&.round(0).to_i

    @estimated_cost_usd = estimated_cost
    @recent_conversations = Conversation.order(created_at: :desc).includes(:messages)

    @daily_counts = Conversation
      .where(created_at: 7.days.ago..)
      .group("DATE(created_at)")
      .order("DATE(created_at) DESC")
      .count
  end

private

  def estimated_cost
    alert_conv_ids = Conversation.where("title LIKE 'Alert:%'").pluck(:id)

    haiku_msgs    = Message.where(role: "assistant", conversation_id: alert_conv_ids)
    nova_pro_msgs = Message.where(role: "assistant").where.not(conversation_id: alert_conv_ids)

    haiku_cost    = token_cost(haiku_msgs,    HAIKU_INPUT_PRICE_PER_M,    HAIKU_OUTPUT_PRICE_PER_M)
    nova_pro_cost = token_cost(nova_pro_msgs, NOVA_PRO_INPUT_PRICE_PER_M, NOVA_PRO_OUTPUT_PRICE_PER_M)

    haiku_cost + nova_pro_cost
  end

  def token_cost(scope, input_price, output_price)
    totals = scope.pick(
      Arel.sql("COALESCE(SUM(input_tokens), 0)"),
      Arel.sql("COALESCE(SUM(output_tokens), 0)"),
    )
    input_tokens, output_tokens = totals
    (input_tokens * input_price + output_tokens * output_price) / 1_000_000.0
  end

  def latency_percentiles(scope)
    return [nil, nil, nil] if scope.none?

    scope.pick(
      Arel.sql("ROUND(AVG(latency_seconds)::numeric, 1)"),
      Arel.sql("ROUND(percentile_cont(0.5) WITHIN GROUP (ORDER BY latency_seconds)::numeric, 1)"),
      Arel.sql("ROUND(percentile_cont(0.95) WITHIN GROUP (ORDER BY latency_seconds)::numeric, 1)"),
    )
  end
end
