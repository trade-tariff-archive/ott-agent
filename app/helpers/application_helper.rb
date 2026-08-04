module ApplicationHelper
  include GOVUKDesignSystemFormBuilder::BuilderHelper

  MARKDOWN_RENDERER = Redcarpet::Render::HTML.new(hard_wrap: true, safe_links_only: true)
  MARKDOWN = Redcarpet::Markdown.new(MARKDOWN_RENDERER, tables: true, fenced_code_blocks: true, autolink: true, strikethrough: true)

  MARKDOWN_ALLOWED_TAGS = %w[p br strong em code pre h1 h2 h3 h4 ul ol li blockquote table thead tbody tr th td a hr].freeze

  COMMODITY_CODE_PATTERN = /\b(\d{4} \d{2} \d{2} \d{2}|\d{10})\b/
  TARIFF_BASE_URL = "https://www.trade-tariff.service.gov.uk/commodities/".freeze

  MERMAID_BLOCK_PATTERN = /<pre><code class="language-mermaid">(.*?)<\/code><\/pre>/m

  def render_markdown(text)
    html = MARKDOWN.render(text.to_s)
    html = extract_mermaid_blocks(html)
    html = link_commodity_codes(html)
    sanitize(html, tags: MARKDOWN_ALLOWED_TAGS, attributes: %w[href class target rel])
  end

private

  def extract_mermaid_blocks(html)
    html.gsub(MERMAID_BLOCK_PATTERN) do
      diagram_source = CGI.unescapeHTML(Regexp.last_match(1))
      %(<pre class="mermaid">#{diagram_source}</pre>)
    end
  end

  def link_commodity_codes(html)
    html.gsub(COMMODITY_CODE_PATTERN) do |code|
      bare = code.delete(" ")
      %(<a href="#{TARIFF_BASE_URL}#{bare}" class="govuk-link" target="_blank" rel="noopener noreferrer">#{code}</a>)
    end
  end
end
