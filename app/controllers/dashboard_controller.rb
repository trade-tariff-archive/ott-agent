class DashboardController < ApplicationController
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

    @recent_conversations = Conversation.order(created_at: :desc).limit(10).includes(:messages)

    @daily_counts = Conversation
      .where(created_at: 7.days.ago..)
      .group("DATE(created_at)")
      .order("DATE(created_at) DESC")
      .count
  end

  private

  def latency_percentiles(scope)
    return [nil, nil, nil] if scope.none?

    scope.pick(
      Arel.sql("ROUND(AVG(latency_seconds)::numeric, 1)"),
      Arel.sql("ROUND(percentile_cont(0.5) WITHIN GROUP (ORDER BY latency_seconds)::numeric, 1)"),
      Arel.sql("ROUND(percentile_cont(0.95) WITHIN GROUP (ORDER BY latency_seconds)::numeric, 1)")
    )
  end
end
