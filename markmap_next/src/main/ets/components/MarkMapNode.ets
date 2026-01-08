import { Markdown } from '@luvi/lv-markdown-in';
import { MarkmapNodeData } from '../utils/MarkdownParse';

/**
 * MarkmapNode 组件
 * 参考 markmap (https://github.com/markmap/markmap) 的实现：
 * - 使用 linkHorizontal 风格的贝塞尔曲线连接父子节点
 * - 曲线起点：父节点下划线右端（圆点位置）
 * - 曲线终点：子节点下划线左端
 * - 使用 d3.linkHorizontal 相同的路径算法
 */
@Component
export struct MarkmapNode {
  @Prop index: number = 0
  @Prop content: MarkmapNodeData
  @Prop MaxWidth: Length = 150
  @Prop BorderWidth: Length = 2
  @Prop BorderColor: Color | number | string | Resource
  // 曲线绘制区域的尺寸
  @State PathSize: SizeOptions = { width: 50, height: 0 }
  // 存储每条曲线的 SVG 路径命令
  @State PathList: string[] = []
  // 父节点内容的底部 Y 坐标（相对于外层 Row）
  @State contentBottomY: number = 0
  // 子节点容器 Column 的顶部 Y 坐标（相对于外层 Row）
  @State columnTopY: number = 0
  // 存储每个子节点在 Column 中的 Y 位置
  @State childNodeY: number[] = []
  // 存储每个子节点报告的内部下划线偏移（相对于子节点自身）
  @State childInnerOffset: number[] = []
  // markmap 配色方案
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
  // 回调函数：向父节点报告本节点下划线的 Y 位置（相对于本节点顶部）
  onUnderlineY: (y: number) => void = () => {
  }

  build() {
    Row() {
      // ========== 内容区域 ==========
      // 包含 Markdown 文本和连接圆点
      Row() {
        Markdown({ text: this.content.content })
          .constraintSize({
            maxWidth: (typeof this.MaxWidth === 'number') ? (this.MaxWidth as number) - 20 : this.MaxWidth
          })
          .border({
            width: { bottom: this.BorderWidth },
            color: this.BorderColor ? this.BorderColor : this.markmapColors[this.index % this.markmapColors.length]
          })
        // 如果有子节点，显示连接圆点（参考 markmap 的 circle 元素）
        if (this.content.children.length) {
          Circle()
            .width(10)
            .height(10)
            .fill(this.BorderColor ? this.BorderColor : this.markmapColors[this.index % this.markmapColors.length])
            .margin({ left: -5, bottom: -3 })
        }
      }
      .alignItems(VerticalAlign.Bottom)
      .onAreaChange((_, newV) => {
        // 记录内容区域底部的 Y 坐标（曲线起点的 Y）
        this.contentBottomY = (newV.position.y as number) + (newV.height as number)
        // 向父节点报告本节点下划线的位置（相对于本节点外层 Row）
        // 下划线在内容底部，但要减去下划线宽度的一半使曲线对准下划线中心
        this.onUnderlineY(this.contentBottomY - (this.BorderWidth as number) / 2)
        this.updateAllPaths()

      })

      // ========== 子节点区域 ==========
      if (this.content.children.length) {
        // 曲线绘制层（使用 Stack 叠加多条曲线）
        Stack() {
          ForEach(this.PathList, (path: string, pathIndex) => {
            Path()
              .commands(path)
              .clip(false)
              .width(this.PathSize.width)
              .height(this.PathSize.height)
              .fill(Color.Transparent)
              .stroke(this.markmapColors[(this.index + pathIndex + 1) % this.markmapColors.length])
              .strokeWidth(this.BorderWidth)

          })
        }.clip(false)
        .width(this.PathSize.width)
        .height(this.PathSize.height)

        // 子节点容器
        Column() {
          ForEach(this.content.children, (childContent: MarkmapNodeData, childIndex) => {
            MarkmapNode({
              content: childContent,
              MaxWidth: this.MaxWidth,
              index: this.index + childIndex + 1,
              // 子节点通过回调报告其内部下划线的偏移位置
              onUnderlineY: (innerOffset: number) => {
                // 分开存储，避免重复累加
                this.childInnerOffset[childIndex] = innerOffset
                this.updateAllPaths()
              }
            })
              .onAreaChange((_, newV) => {
                // 分开存储子节点在 Column 中的 Y 位置
                this.childNodeY[childIndex] = newV.position.y as number
                // 如果子节点还没报告内部偏移，用节点高度作为默认值
                if (!this.childInnerOffset[childIndex]) {
                  this.childInnerOffset[childIndex] = (newV.height as number) - (this.BorderWidth as number) / 2
                }
                this.updateAllPaths()
              })
              .onDisAppear(() => {
                this.childNodeY[childIndex] = 0
                this.childInnerOffset[childIndex] = 0
                this.PathList[childIndex] = ''
              })
          })
        }
        .justifyContent(FlexAlign.Start)
        .alignItems(HorizontalAlign.Start)
        .onAreaChange((_, newV) => {
          // 记录 Column 的位置和尺寸
          this.columnTopY = newV.position.y as number
          this.PathSize = {
            width: 50,
            height: newV.height
          }
          this.updateAllPaths()
        })
      }
    }
    .alignItems(VerticalAlign.Center) // 外层 Row 垂直居中
  }

  /**
   * vp 转 px（Path 命令需要像素值）
   */
  private vp2px = (value: number): number => {
    return this.getUIContext().vp2px(value)
  }

  /**
   * 创建贝塞尔曲线路径
   * 参考 d3.linkHorizontal 的实现：
   * - 使用三次贝塞尔曲线
   * - 控制点的 X 在起点和终点的中间
   * - 控制点的 Y 分别与起点和终点相同
   */
  private createLinkPath(sx: number, sy: number, ex: number, ey: number): string {
    const cx = (sx + ex) / 2
    // M: 移动到起点
    // C: 三次贝塞尔曲线 (控制点1, 控制点2, 终点)
    return `M ${this.vp2px(sx)} ${this.vp2px(sy)} C ${this.vp2px(cx)} ${this.vp2px(sy)} ${this.vp2px(cx)} ${this.vp2px(ey)} ${this.vp2px(ex)} ${this.vp2px(ey)}`
  }

  /**
   * 重新计算所有曲线路径
   * 参考 markmap 的 renderData 方法中的曲线计算逻辑
   */
  private updateAllPaths(): void {
    const pathWidth = this.PathSize.width as number || 50
    const borderHalf = (this.BorderWidth as number) / 2

    // 曲线起点 Y 坐标（相对于 Column/Stack 的坐标系）
    // = 内容底部位置 - Column 顶部位置 - 下划线宽度的一半（对准下划线中心）
    const startY = this.contentBottomY - this.columnTopY - borderHalf

    // 使用分离的数组计算曲线终点：子节点在Column中的Y位置 + 子节点内部下划线偏移
    const childCount = Math.max(this.childNodeY.length, this.childInnerOffset.length)
    for (let i = 0; i < childCount; i++) {
      const nodeY = this.childNodeY[i] || 0
      const innerOffset = this.childInnerOffset[i] || 0
      const endY = nodeY + innerOffset
      if (endY > 0) {
        this.PathList[i] = this.createLinkPath(0, startY, pathWidth, endY)
      }
    }
  }
}