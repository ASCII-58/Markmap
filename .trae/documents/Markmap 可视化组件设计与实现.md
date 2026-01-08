## 组件设计方案

### 1. 组件概述
设计一个 `MarkmapTree` 组件，用于将 `MarkdownParser` 返回的树形结构可视化展示，并集成到现有的 `InertiaCanvas` 组件中，支持自定义样式和交互操作。

### 2. 核心功能
- 递归渲染 MarkmapNode 树形结构
- 支持节点展开/折叠
- 自定义样式（颜色、字体、线条等）
- 集成现有 InertiaCanvas 组件（支持拖拽缩放）
- 交互事件处理

### 3. 技术实现
- 使用 ArkUI 框架开发
- 基于 Column/Row 布局实现树结构
- 递归组件设计
- @State 管理节点展开状态
- @Prop 支持自定义样式

### 4. 组件结构

```typescript
// 自定义样式接口
export interface MarkmapCustomStyles {
  nodeColors?: string[];     // 节点颜色数组
  fontSize?: number[];       // 字体大小数组
  lineColor?: string;        // 连接线颜色
  lineWidth?: number;        // 连接线宽度
  expandAll?: boolean;       // 是否默认展开所有节点
}

/**
 * Markdown 树形可视化组件
 * @param data MarkdownParser 返回的对象
 * @param customStyles 自定义样式配置
 */
@Component
export struct MarkmapTree {
  @Prop data: MarkmapNode;
  @Prop customStyles?: MarkmapCustomStyles;
  @State expandedNodes: Set<string> = new Set();

  // 默认样式
  private readonly defaultStyles: MarkmapCustomStyles = {
    nodeColors: ['#333333', '#555555', '#777777', '#999999'],
    fontSize: [24, 20, 18, 16],
    lineColor: '#DDDDDD',
    lineWidth: 1,
    expandAll: false
  };

  // 合并后的样式
  private get styles(): MarkmapCustomStyles {
    return { ...this.defaultStyles, ...this.customStyles };
  }

  aboutToAppear() {
    // 初始化展开状态
    if (this.styles.expandAll) {
      this.expandAllNodes(this.data);
    }
  }

  build() {
    Column({ space: 12 }) {
      // 递归渲染根节点
      this.renderTreeNode(this.data, 0);
    }
    .width('100%')
    .height('100%')
    .padding(20);
  }

  /**
   * 递归渲染树节点
   * @param node 当前节点
   * @param level 节点级别
   */
  @Builder
  renderTreeNode(node: MarkmapNode, level: number) {
    const isExpanded = this.expandedNodes.has(this.getNodeId(node));
    const hasChildren = node.children.length > 0;
    const currentStyle = this.getNodeStyle(level);

    Column({ space: 8 }) {
      // 节点内容行
      Row({ space: 8 }) {
        // 展开/折叠图标
        if (hasChildren) {
          Image(this.getExpandIcon(isExpanded))
            .width(16)
            .height(16)
            .onClick(() => this.toggleNode(node));
        } else {
          Blank().width(16); // 占位符
        }

        // 节点文本
        Text(node.content)
          .fontSize(currentStyle.fontSize)
          .fontColor(currentStyle.color)
          .maxLines(1)
          .ellipsis(true)
          .onClick(() => this.onNodeClick(node))
          .onHover((event) => {
            if (event.isHover) {
              // 悬停效果
              animateTo({ duration: 200 }, () => {
                // 可以添加悬停样式变化
              });
            }
          });
      }
      .padding({ left: level * 24 })
      .alignItems(VerticalAlign.Center);

      // 子节点区域
      if (hasChildren && isExpanded) {
        Column({ space: 12 }) {
          ForEach(node.children, (childNode) => {
            // 连接线
            if (level > 0) {
              Row() {
                Blank().width(level * 24 + 8);
                Line()
                  .width(this.styles.lineWidth || 1)
                  .height('100%')
                  .stroke(this.styles.lineColor || '#DDDDDD');
              }
              .height(16);
            }
            // 递归渲染子节点
            this.renderTreeNode(childNode, level + 1);
          });
        }
      }
    }
  }

  // 获取节点样式
  private getNodeStyle(level: number): { fontSize: number; color: string } {
    const colors = this.styles.nodeColors || this.defaultStyles.nodeColors!;
    const fontSize = this.styles.fontSize || this.defaultStyles.fontSize!;
    return {
      fontSize: fontSize[Math.min(level, fontSize.length - 1)],
      color: colors[Math.min(level, colors.length - 1)]
    };
  }

  // 获取展开/折叠图标
  private getExpandIcon(isExpanded: boolean): Resource {
    // 注意：需要添加对应的图标资源
    return isExpanded 
      ? $r('app.media.arrow_down') 
      : $r('app.media.arrow_right');
  }

  // 切换节点展开状态
  private toggleNode(node: MarkmapNode): void {
    const nodeId = this.getNodeId(node);
    if (this.expandedNodes.has(nodeId)) {
      this.expandedNodes.delete(nodeId);
    } else {
      this.expandedNodes.add(nodeId);
    }
  }

  // 展开所有节点
  private expandAllNodes(node: MarkmapNode): void {
    const nodeId = this.getNodeId(node);
    this.expandedNodes.add(nodeId);
    node.children.forEach(child => this.expandAllNodes(child));
  }

  // 生成节点唯一标识
  private getNodeId(node: MarkmapNode): string {
    return `${node.content}-${node.children.length}-${Math.random().toString(36).substr(2, 9)}`;
  }

  // 节点点击事件
  private onNodeClick(node: MarkmapNode): void {
    console.log(`Node clicked: ${node.content}`);
    // 可扩展自定义点击逻辑
  }
}

/**
 * Markdown 可视化容器组件
 * 集成 InertiaCanvas 支持拖拽缩放
 */
@Component
export struct MarkmapVisualizer {
  @Prop markdown: string;
  @Prop customStyles?: MarkmapCustomStyles;

  build() {
    // 创建解析器实例
    const parser = new MarkdownParser();
    // 解析 Markdown 内容
    const markmapData = parser.parse(this.markdown);

    // 使用 InertiaCanvas 包装，支持拖拽缩放
    InertiaCanvas({
      content: () => {
        MarkmapTree({
          data: markmapData,
          customStyles: this.customStyles
        });
      }
    });
  }
}
```

### 5. 使用示例

```typescript
// 在页面中使用
@Entry
@Component
struct MarkmapDemo {
  @State markdownContent: string = `# 主标题
- 一级列表项 1
- 一级列表项 2
  - 二级列表项 2.1
  - 二级列表项 2.2
    - 三级列表项 2.2.1
- 一级列表项 3

## 二级标题
1. 有序列表项 1
2. 有序列表项 2
`;

  // 自定义样式配置
  private customStyles: MarkmapCustomStyles = {
    nodeColors: ['#FF6B6B', '#4ECDC4', '#45B7D1', '#96CEB4'],
    fontSize: [28, 24, 20, 18],
    lineColor: '#E0E0E0',
    lineWidth: 2,
    expandAll: true
  };

  build() {
    Column() {
      // 使用 MarkmapVisualizer 组件
      MarkmapVisualizer({
        markdown: this.markdownContent,
        customStyles: this.customStyles
      })
      .width('100%')
      .height('100%');
    }
    .width('100%')
    .height('100%');
  }
}
```

### 6. 资源准备
- 添加箭头图标资源：
  - `arrow_down.png` - 展开状态图标
  - `arrow_right.png` - 折叠状态图标

### 7. 实现步骤

1. **创建组件文件**：在 `src/main/ets/components/` 目录下创建 `MarkmapTree.ets`
2. **实现 MarkmapTree 组件**：
   - 递归渲染逻辑
   - 节点展开/折叠功能
   - 样式自定义支持
3. **集成 InertiaCanvas**：创建 MarkmapVisualizer 组件
4. **添加资源文件**：准备箭头图标
5. **编写示例代码**：展示组件使用方法
6. **测试和优化**：确保组件性能和稳定性

### 8. 扩展功能

- 支持节点连线可视化
- 添加节点搜索和高亮
- 支持导出为图片
- 添加动画效果
- 支持自定义交互事件

### 9. 预期效果

- 清晰的树形结构展示
- 流畅的展开/折叠动画
- 支持拖拽和缩放
- 可自定义的样式
- 良好的交互体验

### 10. 集成到现有组件

修改 `MapNode.ets` 文件，将 `MarkmapTree` 和 `MarkmapVisualizer` 组件导出，方便外部使用：

```typescript
// 在 MapNode.ets 文件末尾添加导出
export { MarkmapTree, MarkmapVisualizer, type MarkmapCustomStyles } from './MarkmapTree';
```