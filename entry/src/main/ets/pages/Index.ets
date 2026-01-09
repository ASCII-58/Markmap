import { ContentMode, MarkdownParser, MarkmapNode, MarkmapNodeData } from 'markmap_next';

@Entry
@Component
struct Index {
  @State markdownContent: string = `# Root
- Child 1
- Child 2
  - Grandchild 2.1
  - Grandchild 2.2
`;
  @State markmapData: MarkmapNodeData | null = null;

  aboutToAppear() {
    this.updateMarkmap(this.markdownContent);
  }

  updateMarkmap(content: string) {
    this.markmapData = MarkdownParser(content, ContentMode.AsChildren);
    console.log(JSON.stringify(this.markmapData), 'markmapjson')
  }

  build() {
    Column() {
      TextArea({ text: this.markdownContent })
        .width('100%')
        .height('30%')
        .onChange((value: string) => {
          this.markdownContent = value;this.updateMarkmap(value);

        })
        .margin({ bottom: 10 })

      Divider().strokeWidth(1).color(Color.Gray).margin({ bottom: 10 })

      if (this.markmapData?.children[0]) {
        Scroll() {
          Scroll() {
            MarkmapNode({ content: this.markmapData!.children[0] })
              .margin(20)
          }
          .scrollable(ScrollDirection.Horizontal)
            .align(Alignment.TopStart)
        }
        .width('100%')
        .layoutWeight(1)
        .align(Alignment.TopStart)
          .scrollable(ScrollDirection.Vertical)
      }
    }
    .width('100%')
    .height('100%')
    .padding(10)
  }
}
