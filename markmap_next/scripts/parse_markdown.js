const fs = require('fs');
const path = require('path');

class MarkdownParser {
  static REGEX_HEADING = /^#+\s+/;
  static REGEX_UNORDERED_LIST = /^-\s+/;
  static REGEX_TASK_LIST = /^-\s+\[[ xX]\]/;
  static REGEX_ORDERED_LIST = /^\d+\.\s+/;
  static REGEX_CODE_BLOCK = /^```/;
  static REGEX_FORMULA_BLOCK = /^\$\$/;
  static REGEX_LIST_ITEM_PREFIX = /^(-|\d+\.)\s+/;

  parse(markdown) {
    if (typeof markdown !== 'string') {
      throw new Error('Invalid input: markdown must be a string');
    }

    if (markdown.trim() === '') {
      return { content: 'root', children: [] };
    }

    const lines = markdown.split('\n');
    const root = { content: 'root', children: [] };
    const levelStack = [{ level: 0, node: root }];

    let i = 0;
    while (i < lines.length) {
      const line = lines[i];
      if (line.trim() === '') { i++; continue; }

      // code block
      if (this.isCodeBlockMarker(line)) {
        let codeContent = line + '\n';
        i++;
        while (i < lines.length && !this.isCodeBlockMarker(lines[i])) {
          codeContent += lines[i] + '\n';
          i++;
        }
        if (i < lines.length) { codeContent += lines[i]; i++; }
        const codeNode = { content: codeContent.trim(), children: [] };
        levelStack[levelStack.length - 1].node.children.push(codeNode);
        continue;
      }

      // block formula
      if (this.isBlockFormulaMarker(line)) {
        let formulaContent = line + '\n';
        i++;
        while (i < lines.length && !this.isBlockFormulaEnd(lines[i])) {
          formulaContent += lines[i] + '\n';
          i++;
        }
        if (i < lines.length) { formulaContent += lines[i]; i++; }
        const formulaNode = { content: formulaContent.trim(), children: [] };
        levelStack[levelStack.length - 1].node.children.push(formulaNode);
        continue;
      }

      // heading
      if (this.isHeading(line)) {
        const level = this.countLeadingHashes(line);
        const content = this.preprocessContent(line);
        const newNode = { content, children: [] };
        while (levelStack.length > 1 && levelStack[levelStack.length - 1].level >= level) {
          levelStack.pop();
        }
        levelStack[levelStack.length - 1].node.children.push(newNode);
        levelStack.push({ level, node: newNode });
        i++;
        continue;
      }

      // list
      if (this.isListItem(line)) {
        const baseIndent = this.countLeadingSpaces(line);
        const listResult = this.parseListItems(lines, i, baseIndent);
        const parent = levelStack[levelStack.length - 1].node;
        parent.children.push(...listResult.nodes);
        i = listResult.endIndex;
        continue;
      }

      // plain text
      const textNode = { content: this.preprocessContent(line), children: [] };
      levelStack[levelStack.length - 1].node.children.push(textNode);
      i++;
    }

    return root;
  }

  countLeadingHashes(str) {
    if (!str || typeof str !== 'string') return 0;
    let count = 0;
    for (let i = 0; i < str.length; i++) {
      if (str[i] === '#') count++; else break;
    }
    return count;
  }

  countLeadingSpaces(str) {
    if (!str || typeof str !== 'string') return 0;
    let count = 0;
    for (let i = 0; i < str.length; i++) {
      if (str[i] === ' ') count++; else break;
    }
    return count;
  }

  preprocessContent(content) {
    if (!content || typeof content !== 'string') return '';
    let result = content;
    result = result.replace(MarkdownParser.REGEX_HEADING, '');
    result = result.trimStart();
    result = result.replace(MarkdownParser.REGEX_LIST_ITEM_PREFIX, '');
    return result;
  }

  isUnorderedListItem(line) {
    const trimmed = line.trimStart();
    return MarkdownParser.REGEX_UNORDERED_LIST.test(trimmed) && !MarkdownParser.REGEX_TASK_LIST.test(trimmed);
  }

  isOrderedListItem(line) {
    const trimmed = line.trimStart();
    return MarkdownParser.REGEX_ORDERED_LIST.test(trimmed);
  }

  isListItem(line) {
    return this.isUnorderedListItem(line) || this.isOrderedListItem(line);
  }

  isHeading(line) {
    return MarkdownParser.REGEX_HEADING.test(line);
  }

  isCodeBlockMarker(line) {
    return MarkdownParser.REGEX_CODE_BLOCK.test(line.trim());
  }

  isBlockFormulaMarker(line) {
    const trimmed = line.trim();
    return MarkdownParser.REGEX_FORMULA_BLOCK.test(trimmed) || /^-\s+\$\$/.test(trimmed);
  }

  isBlockFormulaEnd(line) {
    return MarkdownParser.REGEX_FORMULA_BLOCK.test(line.trim());
  }

  parseListItems(lines, startIndex, baseIndent) {
    const nodes = [];
    let i = startIndex;
    while (i < lines.length) {
      const line = lines[i];
      if (!this.isListItem(line)) break;
      const currentIndent = this.countLeadingSpaces(line);
      if (currentIndent < baseIndent) break;
      if (currentIndent === baseIndent) {
        const node = { content: this.preprocessContent(line), children: [] };
        i++;
        // child list
        if (i < lines.length && this.isListItem(lines[i])) {
          const nextIndent = this.countLeadingSpaces(lines[i]);
          if (nextIndent > currentIndent) {
            const childResult = this.parseListItems(lines, i, nextIndent);
            node.children = childResult.nodes;
            i = childResult.endIndex;
          }
        }
        nodes.push(node);
      } else {
        break;
      }
    }
    return { nodes, endIndex: i };
  }
}

// Runner
(function main() {
  const inputPath = path.resolve(__dirname, '..', 'md.md');
  const outputPath = path.resolve(__dirname, '..', 'build', 'parsed_markmap.json');

  if (!fs.existsSync(inputPath)) {
    console.error('Input file not found:', inputPath);
    process.exit(1);
  }

  const md = fs.readFileSync(inputPath, 'utf8');
  const parser = new MarkdownParser();
  let root;
  try {
    root = parser.parse(md);
  } catch (err) {
    console.error('Parse error:', err.message);
    process.exit(2);
  }

  fs.mkdirSync(path.dirname(outputPath), { recursive: true });
  fs.writeFileSync(outputPath, JSON.stringify(root, null, 2), 'utf8');
  console.log('Wrote parsed JSON to', outputPath);
})();
