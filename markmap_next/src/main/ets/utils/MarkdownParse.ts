export interface NodeSize {
  width: number;
  height: number;
}
export interface MarkmapNodeData {
  id?: string;
  content: string;
  children: MarkmapNodeData[];
  size?:NodeSize
}

/**
 * Markdown 解析器类，用于将 Markdown 内容解析为 MarkmapNode 树结构
 * 
 * @example
 * ```typescript
 * const parser = new MarkdownParser();
 * const markdown = `# 标题
 * - 列表项 1
 * - 列表项 2
 *   - 子列表项`;
 * const root = parser.parse(markdown);
 * ```
 */
export class MarkdownParser {
  // 预编译正则表达式，提高性能
  private static readonly REGEX_HEADING = /^#+\s+/;
  private static readonly REGEX_UNORDERED_LIST = /^-\s+/;
  private static readonly REGEX_TASK_LIST = /^-\s+\[[ x]]/;
  private static readonly REGEX_ORDERED_LIST = /^\d+\.\s+/;
  private static readonly REGEX_CODE_BLOCK = /^```/;
  private static readonly REGEX_FORMULA_BLOCK = /^\$\$/;
  private static readonly REGEX_LIST_ITEM_PREFIX = /^(-|\d+\.)\s+/;

  /**
   * 解析 Markdown 内容为 MarkmapNode 树
   * @param {string} markdown - Markdown 内容
   * @returns {MarkmapNodeData} 根节点
   * @throws {Error} 当输入无效时抛出错误
   */
  public parse(markdown: string): MarkmapNodeData {
    // 输入验证
    if (typeof markdown !== 'string') {
      throw new Error('Invalid input: markdown must be a string');
    }

    if (markdown.trim() === '') {
      return { content: 'root', children: []};
    }

    const lines = markdown.split('\n');
    const root: MarkmapNodeData = { content: 'root', children: [] };

    // 存储每个层级的当前节点
    const levelStack: { level: number, node: MarkmapNodeData }[] = [{ level: 0, node: root }];

    let i = 0;
    while (i < lines.length) {
      const line = lines[i];

      // 跳过空行
      if (line.trim() === '') {
        i++;
        continue;
      }

      try {
        // 处理代码块
        if (this.isCodeBlockMarker(line)) {
          let codeContent = line + '\n';
          i++;
          while (i < lines.length && !this.isCodeBlockMarker(lines[i])) {
            codeContent += lines[i] + '\n';
            i++;
          }
          if (i < lines.length) {
            codeContent += lines[i]; // 添加结束标记
            i++;
          }

          const codeNode: MarkmapNodeData = { content: codeContent.trim(), children: [] };
          const parent = levelStack[levelStack.length - 1].node;
          parent.children.push(codeNode);
          continue;
        }

        if (this.isBlockFormulaMarker(line)) {
          let formulaContent = line + '\n';
          i++;
          while (i < lines.length && !this.isBlockFormulaEnd(lines[i])) {
            formulaContent += lines[i] + '\n';
            i++;
          }
          if (i < lines.length) {
            formulaContent += lines[i];
            i++;
          }

          const formulaNode: MarkmapNodeData = { content: formulaContent.trim(), children: [] };
          const parent = levelStack[levelStack.length - 1].node;
          parent.children.push(formulaNode);
          continue;
        }

        if (this.isHeading(line)) {
          const level = this.countLeadingHashes(line);
          const content = this.preprocessContent(line);
          const newNode: MarkmapNodeData = { content, children: [] };

          while (levelStack.length > 1 && levelStack[levelStack.length - 1].level >= level) {
            levelStack.pop();
          }

          const parent = levelStack[levelStack.length - 1].node;
          parent.children.push(newNode);
          levelStack.push({ level, node: newNode });
          i++;
          continue;
        }

        if (this.isListItem(line)) {
          const baseIndent = this.countLeadingSpaces(line);
          const listResult = this.parseListItems(lines, i, baseIndent);

          const parent = levelStack[levelStack.length - 1].node;
          parent.children.push(...listResult.nodes);
          i = listResult.endIndex;
          continue;
        }

        const textNode: MarkmapNodeData = { content: this.preprocessContent(line), children: [] };
        const parent = levelStack[levelStack.length - 1].node;
        parent.children.push(textNode);
        i++;
      } catch (error) {
        throw new Error(`Parse error at line ${i + 1}: ${(error as Error).message}`);
      }
    }

    return root;
  }

  /**
   * 统计字符串开头连续 '#' 的数量
   * @private
   * @param {string} str - 要检测的字符串
   * @returns {number} 开头连续 '#' 的数量
   */
  private countLeadingHashes(str: string): number {
    if (!str || typeof str !== 'string') {
      return 0;
    }

    let count = 0;
    for (let i = 0; i < str.length; i++) {
      if (str[i] === '#') {
        count++;
      } else {
        break;
      }
    }
    return count;
  }

  /**
   * 统计字符串开头的空格数量
   * @private
   * @param {string} str - 要检测的字符串
   * @returns {number} 开头空格的数量
   */
  private countLeadingSpaces(str: string): number {
    if (!str || typeof str !== 'string') {
      return 0;
    }

    let count = 0;
    for (let i = 0; i < str.length; i++) {
      if (str[i] === ' ') {
        count++;
      } else {
        break;
      }
    }
    return count;
  }

  /**
   * 预处理文本内容：移除开头的 '#'、空白字符和列表前缀
   * @private
   * @param {string} content - 原始内容
   * @returns {string} 处理后的内容
   */
  private preprocessContent(content: string): string {
    if (!content || typeof content !== 'string') {
      return '';
    }

    let result = content;

    // 移除开头的 '#' 符号
    result = result.replace(MarkdownParser.REGEX_HEADING, '');

    // 移除开头的空白字符
    result = result.trimStart();

    // 移除列表前缀
    result = result.replace(MarkdownParser.REGEX_LIST_ITEM_PREFIX, '');

    return result;
  }

  /**
   * 检查是否是无序列表项（排除任务列表）
   * @param {string} line - 行内容
   * @returns {boolean} 是否是无序列表项
   */
  private isUnorderedListItem(line: string): boolean {
    const trimmed = line.trimStart();
    // 匹配 "- " 但排除任务列表 "- [ ]" 和 "- [x]"
    return MarkdownParser.REGEX_UNORDERED_LIST.test(trimmed) &&
      !MarkdownParser.REGEX_TASK_LIST.test(trimmed);
  }

  /**
   * 检查是否是有序列表项
   * @param {string} line - 行内容
   * @returns {boolean} 是否是有序列表项
   */
  private isOrderedListItem(line: string): boolean {
    const trimmed = line.trimStart();
    return MarkdownParser.REGEX_ORDERED_LIST.test(trimmed);
  }

  /**
   * 检查是否是列表项（有序或无序，排除任务列表）
   * @param {string} line - 行内容
   * @returns {boolean} 是否是列表项
   */
  private isListItem(line: string): boolean {
    return this.isUnorderedListItem(line) || this.isOrderedListItem(line);
  }

  /**
   * 检查是否是标题行
   * @param {string} line - 行内容
   * @returns {boolean} 是否是标题行
   */
  private isHeading(line: string): boolean {
    return MarkdownParser.REGEX_HEADING.test(line);
  }

  /**
   * 检查是否是代码块开始/结束标记
   * @param {string} line - 行内容
   * @returns {boolean} 是否是代码块标记
   */
  private isCodeBlockMarker(line: string): boolean {
    return MarkdownParser.REGEX_CODE_BLOCK.test(line.trim());
  }

  /**
   * 检查是否是块级公式开始/结束标记
   * @param {string} line - 行内容
   * @returns {boolean} 是否是块级公式标记
   */
  private isBlockFormulaMarker(line: string): boolean {
    const trimmed = line.trim();
    // 匹配单独的 $$ 或者列表项后的 $$
    return MarkdownParser.REGEX_FORMULA_BLOCK.test(trimmed) || /^-\s+\$\$$/.test(trimmed);
  }

  /**
   * 检查行是否只包含块级公式结束标记
   * @param {string} line - 行内容
   * @returns {boolean} 是否是块级公式结束标记
   */
  private isBlockFormulaEnd(line: string): boolean {
    return MarkdownParser.REGEX_FORMULA_BLOCK.test(line.trim());
  }

  /**
   * 解析列表项及其子列表
   * @param {string[]} lines - 所有行
   * @param {number} startIndex - 起始索引
   * @param {number} baseIndent - 基础缩进
   * @returns {{ nodes: MarkmapNodeData[], endIndex: number }} 解析结果
   */
  private parseListItems(lines: string[], startIndex: number,
    baseIndent: number): { nodes: MarkmapNodeData[], endIndex: number } {
    const nodes: MarkmapNodeData[] = [];
    let i = startIndex;

    while (i < lines.length) {
      const line = lines[i];

      // 如果不是列表项，结束解析
      if (!this.isListItem(line)) {
        break;
      }

      const currentIndent = this.countLeadingSpaces(line);

      // 如果缩进小于基础缩进，说明列表结束
      if (currentIndent < baseIndent) {
        break;
      }

      // 如果缩进等于基础缩进，这是同级列表项
      if (currentIndent === baseIndent) {
        const node: MarkmapNodeData = {
          content: this.preprocessContent(line),
          children: []
        };
        i++;

        // 检查是否有子列表（缩进增加2个空格）
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
        // 缩进大于基础缩进，跳过（这种情况不应该发生在这个层级）
        break;
      }
    }

    return { nodes, endIndex: i };
  }
}

