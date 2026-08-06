require "rails_helper"

RSpec.describe MarkdownRenderer do
  describe ".render" do
    it "renders basic markdown to HTML" do
      html = described_class.render("**bold** and _italic_")
      expect(html).to include("<strong>bold</strong>")
      expect(html).to include("<em>italic</em>")
    end

    it "sanitizes disallowed tags" do
      html = described_class.render("<script>alert('xss')</script>")
      expect(html).not_to include("<script>")
    end

    it "links 10-digit commodity codes" do
      html = described_class.render("Look up 0101210000 for horses.")
      expect(html).to include('href="https://www.trade-tariff.service.gov.uk/commodities/0101210000"')
    end

    it "links spaced commodity codes" do
      html = described_class.render("Code 0101 21 00 00 applies.")
      expect(html).to include('href="https://www.trade-tariff.service.gov.uk/commodities/0101210000"')
    end

    it "extracts mermaid fenced blocks into pre.mermaid elements" do
      markdown = "```mermaid\ngraph TD\nA --> B\n```"
      html = described_class.render(markdown)
      expect(html).to include('<pre class="mermaid">')
      expect(html).not_to include('<code class="language-mermaid">')
    end

    it "handles partial markdown without raising" do
      expect { described_class.render("**incomplete") }.not_to raise_error
    end

    it "returns an empty string for blank input" do
      expect(described_class.render("")).to eq("")
      expect(described_class.render(nil)).to eq("")
    end
  end
end
