import { Markdown } from '@luvi/lv-markdown-in';
import { MarkdownParser, MarkmapNodeData, syncNode } from '../utils/MarkdownParse';

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
    '#1f77b4',
    '#ff7f0e',
    '#2ca02c',
    '#d62728',
    '#9467bd',
    '#8c564b',
    '#e377c2',
    '#7f7f7f',
    '#bcbd22',
    '#17becf'
  ];
  private lineWight: number = 75;

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
    syncNode(this.markNodeData, temp);
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