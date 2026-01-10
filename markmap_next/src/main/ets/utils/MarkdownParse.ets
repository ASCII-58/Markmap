
@Observed
export class MarkmapNodeData {
  id: string = '';
  content: string = '';
  children: MarkmapNodeData[] = [];
  size?: NodeSize;

  constructor(id: string = '', content: string = '', children: MarkmapNodeData[] = []) {
    this.id = id;
    this.content = content;
    this.children = children;
  }
}

export interface NodeSize {
  width: number;
  height: number;
}

/**
 * Markdown解析器，处理markdown为MarkmapNodeData树形结构
 * 支持标题级别作为树的层级
 * @param markdown markdown文本内容
 * @returns MarkmapNodeData树形结构
 */
export function MarkdownParser(markdown: string): MarkmapNodeData {

  // 移除BOM和规范化行尾
  const normalizedMarkdown = markdown.replace(/^\uFEFF/, '').replace(/\r\n/g, '\n');

  // 按行分割
  const lines = normalizedMarkdown.split('\n');

  // ID生成器上下文
  let idCounter = 0;
  const generateId = (): string => {
    return `node_${idCounter++}`;
  };

  // 根节点
  const root: MarkmapNodeData = new MarkmapNodeData('root', 'root', []);

  interface StackItem {
    node: MarkmapNodeData;
    level: number; // 标题级别 (1-6)，非标题为-1
    type: 'root' | 'heading' | 'list';
    indent: number; // 缩进层级
  }

  // 用栈来维护树的结构
  const stack: StackItem[] = [{ node: root, level: 0, type: 'root', indent: -1 }];

  // 状态跟踪
  let lastWasEmpty = true;
  let lastAddedNodeWasContent = false;
  let inCodeBlock = false;

  for (const line of lines) {
    const trimmed = line.trim();

    if (trimmed.startsWith('```')) {
      inCodeBlock = !inCodeBlock;
    }

    if (!inCodeBlock && !trimmed) {
      lastWasEmpty = true;
      continue;
    }

    // 忽略分割线
    if (!inCodeBlock && /^[-]{3,}$/.test(trimmed)) {
      lastWasEmpty = true;
      continue;
    }

    // 检测标题 (#, ##, ###等)
    const headingMatch = !inCodeBlock && trimmed.match(/^(#+)\s+(.+)$/);

    // 检测列表项 (-, *, +, 1. 等)
    // 捕获组: 1=缩进, 2=标记, 3=内容
    const listMatch = !inCodeBlock && line.match(/^(\s*)([-*+]|\d+\.)\s+(.+)$/);

    if (headingMatch) {
      const level = headingMatch[1].length;
      const content = headingMatch[2].trim();

      const newNode = new MarkmapNodeData(generateId(), content, []);

      // 从栈中弹出:
      // 1. 所有列表项 (标题会打断列表)
      // 2. 级别大于等于当前标题的已有标题
      while (
        stack.length > 1 &&
        (stack[stack.length - 1].type === 'list' ||
          (stack[stack.length - 1].type === 'heading' && stack[stack.length - 1].level >= level))
      ) {
        stack.pop();
      }

      // 将新节点添加到当前栈顶节点的children中
      stack[stack.length - 1].node.children.push(newNode);

      // 新节点入栈
      stack.push({ node: newNode, level: level, type: 'heading', indent: -1 });

      // 重置状态
      lastWasEmpty = true;
      lastAddedNodeWasContent = false;

    } else if (listMatch) {
      const indent = listMatch[1].length;
      const content = listMatch[3].trim();

      const newNode = new MarkmapNodeData(generateId(), content, []);

      // 列表处理逻辑：
      // 从栈顶开始，如果栈顶是列表项且缩进 >= 当前缩进，则弹出 (视为同级或上级结束)
      // 如果遇到标题或root则停止 (列表是在标题下的)
      while (
        stack.length > 1 &&
        stack[stack.length - 1].type === 'list' &&
        stack[stack.length - 1].indent >= indent
      ) {
        stack.pop();
      }

      // 添加为子节点
      stack[stack.length - 1].node.children.push(newNode);

      // 入栈
      stack.push({ node: newNode, level: -1, type: 'list', indent: indent });

      lastWasEmpty = true; // 列表项后视为新块
      lastAddedNodeWasContent = false;

    } else {
      // 非标题且非列表行 (普通文本/段落)
      const currentNode = stack[stack.length - 1].node;

      // 如果是根节点，总是添加为独立子节点（避免根节点有内容）
      // 或者普通节点上下文 (Header 或 List Item) 也作为子节点
      if (lastWasEmpty || !lastAddedNodeWasContent) {
        const contentNode = new MarkmapNodeData(generateId(), trimmed, []);
        currentNode.children.push(contentNode);
        lastAddedNodeWasContent = true;
      } else {
        // 追加到上一个内容节点
        const lastChild = currentNode.children[currentNode.children.length - 1];
        lastChild.content += '\n' + trimmed;
      }

      lastWasEmpty = false;
    }
  }

  return root;
}
