@Observed
export class MarkmapNodeData {
  public id: string = '';
  public content: string = '';
  public children: MarkmapNodeData[] = [];

  // 渲染布局属性
  public width: number = 0;
  public height: number = 0;
  public x: number = 0;
  public y: number = 0;
  public depth: number = 0; // 核心：用于控制线条颜色或层级样式
  public display: boolean = true;
  public parent: MarkmapNodeData | null = null;

  constructor(id: string = '', content: string = '', children: MarkmapNodeData[] = []) {
    this.id = id;
    this.content = content;
    this.children = children;
  }
}

/**
 * 内部状态接口：只在解析时使用，不暴露给外部
 * 用于记录栈中节点的元数据，以便处理层级关系
 */
interface StackItem {
  node: MarkmapNodeData;
  level: number; // 标题级别 (1-6)，非标题为 -1
  indent: number; // 列表缩进字符数
  nodeType: 'root' | 'heading' | 'list'; // 仅在解析过程中区分类型
}

export function MarkdownParser(markdown: string): MarkmapNodeData {
  // 1. 预处理：移除BOM，统一换行，将Tab转换为空格(避免缩进混乱)
  const normalizedMarkdown = markdown
    .replace(/^\uFEFF/, '')
    .replace(/\r\n/g, '\n')
    .replace(/\t/g, '    ');

  const lines = normalizedMarkdown.split('\n');

  let idCounter = 0;
  const generateId = (): string => `node_${idCounter++}`;

  // 创建虚拟根节点
  const root = new MarkmapNodeData(generateId(), 'MindMap', []);
  root.depth = 0;

  // 栈初始化
  const stack: StackItem[] = [{
    node: root,
    level: 0,
    indent: -1,
    nodeType: 'root'
  }];

  let inCodeBlock = false;
  let lastLineWasText = false; // 用于合并多行文本段落

  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    const trimmed = line.trim();

    // --- 1. 边界情况过滤 ---
    if (trimmed.startsWith('```')) {
      inCodeBlock = !inCodeBlock;
    }
    if (inCodeBlock || !trimmed) {
      lastLineWasText = false;
      continue;
    }
    if (/^[-*_]{3,}$/.test(trimmed)) {
      lastLineWasText = false;
      continue;
    }

    // --- 2. 正则匹配 ---
    // 匹配标题: # 标题
    const headingMatch = line.match(/^(\s*)(#+)\s+(.+)$/);
    // 匹配列表: - 列表 / 1. 列表
    const listMatch = line.match(/^(\s*)([-*+]|\d+\.)\s+(.+)$/);

    if (headingMatch) {
      // === 处理标题 ===
      const levelStr = headingMatch[2];
      const content = headingMatch[3].trim();
      const newLevel = levelStr.length;

      const newNode = new MarkmapNodeData(generateId(), content, []);

      // 逻辑：弹出栈中层级 >= 当前标题层级的标题，以及所有列表
      while (
        stack.length > 1 &&
          (stack[stack.length - 1].nodeType === 'list' ||
            (stack[stack.length - 1].nodeType === 'heading' && stack[stack.length - 1].level >= newLevel))
      ) {
        stack.pop();
      }

      // 挂载
      const parentItem = stack[stack.length - 1];
      newNode.parent = parentItem.node;
      newNode.depth = parentItem.node.depth + 1; // 计算深度
      parentItem.node.children.push(newNode);

      // 入栈
      stack.push({
        node: newNode,
        level: newLevel,
        indent: -1,
        nodeType: 'heading'
      });

      lastLineWasText = false;

    } else if (listMatch) {
      // === 处理列表 ===
      const indentStr = listMatch[1];
      const content = listMatch[3].trim();
      const newIndent = indentStr.length;

      const newNode = new MarkmapNodeData(generateId(), content, []);

      // 逻辑：如果栈顶也是列表，且当前缩进 <= 栈顶缩进，说明层级结束，弹出
      while (
        stack.length > 1 &&
          stack[stack.length - 1].nodeType === 'list' &&
          stack[stack.length - 1].indent >= newIndent
      ) {
        stack.pop();
      }

      // 挂载
      const parentItem = stack[stack.length - 1];
      newNode.parent = parentItem.node;
      newNode.depth = parentItem.node.depth + 1; // 计算深度
      parentItem.node.children.push(newNode);

      // 入栈
      stack.push({
        node: newNode,
        level: -1,
        indent: newIndent,
        nodeType: 'list'
      });

      lastLineWasText = false;

    } else {
      // === 处理普通文本段落 ===
      const parentNode = stack[stack.length - 1].node;

      if (lastLineWasText && parentNode.children.length > 0) {
        // 如果上一行也是纯文本，则合并到同一个节点（实现多行段落）
        const lastChild = parentNode.children[parentNode.children.length - 1];
        lastChild.content += '\n' + trimmed;
      } else {
        // 否则创建新节点
        const pNode = new MarkmapNodeData(generateId(), trimmed, []);
        pNode.parent = parentNode;
        pNode.depth = parentNode.depth + 1; // 计算深度
        parentNode.children.push(pNode);
      }

      lastLineWasText = true;
    }
  }

  // 3. 根节点优化：如果Root只有一个Heading子节点，将其提升为根，使图表更美观
  if (root.children.length === 1 && root.children[0].children.length > 0) {
    const realRoot = root.children[0];
    realRoot.parent = null;
    // 递归修正深度 (因为根节点变了，所有子节点深度-1)
    adjustDepth(realRoot, 0);
    return realRoot;
  }

  return root;
}

// 辅助函数：递归修正深度
function adjustDepth(node: MarkmapNodeData, depth: number) {
  node.depth = depth;
  for (const child of node.children) {
    adjustDepth(child, depth + 1);
  }
}
export function syncNode(oldNode: MarkmapNodeData, newNode: MarkmapNodeData): void {
  // --- 1. 同步基础属性 ---
  // 只有值不相等时才赋值，减少系统开销
  if (oldNode.content !== newNode.content) {
  oldNode.content = newNode.content;
}

// 注意：不要同步 x, y, width, height, depth 等布局属性
// 1. 这些属性通常由 UI 布局过程计算得出，或者由 updateNodeList 递归计算
// 2. parser 生成的新节点通常包含默认值(0)，强制同步会导致节点位置重置/闪烁

// 注意：id 通常不需要同步，因为我们是基于 id 匹配的

// --- 2. 同步子节点 (核心 Diff 逻辑) ---
const nextChildren: MarkmapNodeData[] = [];

// 为了优化查找速度，将旧子节点建立 Map 索引 (空间换时间)
// 如果子节点数量很少(比如 < 10)，直接用 find 也行，这里用 Map 适应性更好
const oldChildrenMap = new Map<string, MarkmapNodeData>();
for (const child of oldNode.children) {
  oldChildrenMap.set(child.id, child);
}

// 遍历新树的子节点
for (const newChild of newNode.children) {
  // 尝试在旧子节点中查找是否存在同 ID 节点
  const existingChild = oldChildrenMap.get(newChild.id);

  if (existingChild) {
    // 【关键】：找到了！不要替换它，而是递归更新它
    // 这样 existingChild 的内存引用保持不变，持有它的组件不会销毁
    syncNode(existingChild, newChild);

    // 将复用的旧节点加入新列表
    nextChildren.push(existingChild);

    // 从 Map 中移除，剩下的就是需要被删除的节点（如果需要处理 cleanup 逻辑）
    oldChildrenMap.delete(newChild.id);
  } else {
    // 没找到：说明是新增节点，直接加入
    nextChildren.push(newChild);
  }
}

// --- 3. 应用子节点变更 ---
// 这一步会触发 ArkUI 监听 children 数组的变化
// 因为数组里的大部分元素对象引用没变，所以 List/ForEach 只会处理新增/删除的项
oldNode.children = nextChildren;
}