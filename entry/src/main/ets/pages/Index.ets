import { Markmap } from 'markmap_next';

@Entry
@Component
struct Index {
  @State markdownContent: string = `# Root
- Child 1
- Child 2
  - Grandchild 2.1
  - Grandchild 2.2
`;

  build() {
    Column() {
      TextArea({ text: $$this.markdownContent })
        .width('100%')
        .height('30%')
        // .onChange((value: string) => {
        //   this.markdownContent = value;
        // })
        .margin({ bottom: 10 })

      Divider().strokeWidth(1).color(Color.Gray).margin({ bottom: 10 })

      Markmap({ markdown: $markdownContent })
        .width('100%')
        .height('50%')
    }
    .width('100%')
    .height('100%')
    .padding(10)
  }
}
