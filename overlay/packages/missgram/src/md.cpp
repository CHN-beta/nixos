# include <missgram.hpp>
# include <maddy/parser.h>

namespace missgram
{
  std::string parse(std::string text)
  {
    biu::Logger::Guard log(text);
    auto parser_config = std::make_shared<maddy::ParserConfig>();
    parser_config->enabledParsers =
      // 代码块（不包括行内代码），稍后需要手动再修改 class
      maddy::types::CODE_BLOCK_PARSER
      // 斜体
      | maddy::types::EMPHASIZED_PARSER | maddy::types::ITALIC_PARSER
      // 行内代码
      | maddy::types::INLINE_CODE_PARSER
      // 链接
      | maddy::types::LINK_PARSER
      // 引用
      | maddy::types::QUOTE_PARSER
      // 删除线
      | maddy::types::STRIKETHROUGH_PARSER
      // 粗体
      | maddy::types::STRONG_PARSER;
    parser_config->isHeadlineInlineParsingEnabled = false;
    auto parser = std::make_shared<maddy::Parser>(parser_config);

    // maddy默认认为以下算是换行：连续两个换行，或者上一行结尾多两个空格
    // 我们在适当的行结尾添加两个空格，来让maddy识别换行
    {
      std::string new_text;
      bool in_code_block = false;
      for (auto [line, it] : biu::string::find(text, "\\n"_re))
      {
        // 在大部分情况下，都在行尾加两个换行，只有以下例外：
        // 1. 在代码块里，或者在代码块开始处
        // 2. 本行为引用，且下一行仍然为引用
        if (line.starts_with("```"))
          in_code_block = !in_code_block;
        if (in_code_block)
          new_text.append(line).append("\n");
        else
        {
          // TODO: 检查是否是多行引用
          new_text.append(line).append("\n\n");
        }
      }
      text = new_text;
    }
    log.debug(text);

    std::stringstream text_stream(text);
    std::string text_html = parser->Parse(text_stream);
    log.debug(text_html);

    // convert <pre class="cpp"><code>xxx</code></pre> to <pre><code class="language-cpp">xxx</code></pre>
    text_html = std::regex_replace
    (
      text_html,
      std::regex(R"r(<pre class="([^"]+)"><code>(.*?)</code></pre>)r"),
      R"(<pre><code class="language-$1">$2</code></pre>)"
    );
    // convert <br> and <br/> to \n
    // there may be one space behind br
    text_html = std::regex_replace(text_html, std::regex("<br/?> ?"), "\n");
    return log.rtn(text_html);
  }
}
