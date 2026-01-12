import { Markdown } from '@luvi/lv-markdown-in';
import { MarkdownParser, MarkmapNodeData } from '../utils/MarkdownParse';

// 定义栈中元素的结构
interface StackItem {
  node: MarkmapNodeData;
  depth: number;
}

@Component
export struct Markmap {
  @Link @Watch('updateMarkNodeData') markdown: string;
  @State markNodeData: MarkmapNodeData = new MarkmapNodeData;
  @State NodeList: MarkmapNodeData[] = [];
  private markmapColors: string[] = [
    '#1f77b4', // 蓝色
    '#ff7f0e', // 橙色
    '#2ca02c', // 绿色
    '#d62728', // 红色
    '#9467bd', // 紫色
    '#8c564b', // 棕色
    '#e377c2', // 粉色
    '#7f7f7f', // 灰色
    '#bcbd22', // 橄榄色
    '#17becf'// 青色
  ];
  private lineWight: number = 75;

  syncNode(oldNode: MarkmapNodeData, newNode: MarkmapNodeData): void {
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
        this.syncNode(existingChild, newChild);

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

  updateNodeList(Data: MarkmapNodeData, startDepth: number) {
    const newNodeList: MarkmapNodeData[] = [];
    const stack: StackItem[] = [];

    if (Data.children && Data.children.length > 0) {
      for (let i = Data.children.length - 1; i >= 0; i--) {
        stack.push({ node: Data.children[i], depth: startDepth });
      }
    }

    while (stack.length > 0) {
      const currentItem = stack.pop();
      if (!currentItem) {
        continue;
      }

      const node = currentItem.node;
      const depth = currentItem.depth;

      node.depth = depth;

      newNodeList.push(node);

      if (node.children && node.children.length > 0) {
        const nextDepth = depth + 1;
        for (let i = node.children.length - 1; i >= 0; i--) {
          stack.push({ node: node.children[i], depth: nextDepth });
        }
      }
    }
    this.NodeList = newNodeList;
  }

  updateMarkNodeData() {
    let temp = MarkdownParser(this.markdown);
    this.syncNode(this.markNodeData, temp);
    this.updateNodeList(this.markNodeData, 0);
  }

  aboutToAppear() {
    this.updateMarkNodeData();
  }

  build() {
    Stack() {
      ForEach(this.NodeList, (item: MarkmapNodeData, index: number) => {
        // 将数据项传递给子组件
        MarkmapNode({
          node: item,
          color: this.markmapColors[index % this.markmapColors.length]
        })
      }, (item: MarkmapNodeData) => item.id) // 建议加上唯一的 key 生成函数
    }.align(Alignment.TopStart)
  }
}

@Component
struct MarkmapNode {
  // @ObjectLink 会监听 node 内部属性的变化
  @ObjectLink node: MarkmapNodeData;
  @Prop color: string; // 接收颜色

  build() {
    Row() {
      Markdown({ text: this.node.content })
        .border({
          width: { bottom: 3 },
          color: this.color
        })
      if (this.node.children.length) {
        Circle()
          .width(10)
          .height(10)
          .fill(this.color)
          .margin({ left: -5, bottom: -3 })
      }
    }
    .alignItems(VerticalAlign.Bottom)
    // 这里的 this.node.x 变化时，只有当前这个子组件会刷新
    .translate({ x: this.node.x, y: this.node.y })
    .onAreaChange((_, newSize: Area) => {
      // 修改属性，@ObjectLink 会捕获到变化并刷新 UI
      this.node.width = newSize.width as number;
      this.node.height = newSize.height as number;
      animateTo({ duration: 150 }, () => {
        this.node.x = newSize.width as number;
        this.node.y = newSize.height as number;
      })
    })
  }
}