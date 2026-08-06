module ApplicationHelper
  include GOVUKDesignSystemFormBuilder::BuilderHelper

  def render_markdown(text)
    MarkdownRenderer.render(text).html_safe
  end
end
